import SwiftUI

struct FitnessView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FitnessViewModel

    private let onChange: () -> Void

    init(
        fitnessRepository: any FitnessRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: FitnessViewModel(fitnessRepository: fitnessRepository)
        )
    }

    var body: some View {
        NavigationStack {
            FitnessTrackerView(viewModel: viewModel, onChange: onChange)
            .navigationTitle("Fitness")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

}

struct FitnessTrackerView: View {
    @ObservedObject var viewModel: FitnessViewModel
    let onChange: () -> Void

    @State private var selectedTemplate: WorkoutTemplate?
    @State private var selectedExercise: FitnessExercise?
    @State private var presentedSheet: FitnessSheet?

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section("Workout Days") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(110))], spacing: 12) {
                        Button {
                            presentedSheet = .template(nil)
                        } label: {
                            AddWorkoutDayCard()
                        }
                        .buttonStyle(.plain)

                        ForEach(viewModel.workoutTemplates) { template in
                            Button {
                                selectedTemplate = template
                            } label: {
                                WorkoutDayCard(template: template)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit") {
                                    presentedSheet = .template(template)
                                }
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteWorkoutTemplate(withID: template.id)
                                    onChange()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 130)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Exercise Library") {
                if viewModel.sortedExercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Create your first exercise to start logging sessions.")
                    )
                } else {
                    ForEach(viewModel.sortedExercises) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            ExerciseLibraryRow(
                                exercise: exercise,
                                latestSession: viewModel.latestSession(for: exercise.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button {
                                presentedSheet = .session(exercise, viewModel.draftSession(for: exercise), true)
                            } label: {
                                Label("Log", systemImage: "plus.circle")
                            }
                            .tint(.accentColor)

                            Button {
                                presentedSheet = .exercise(exercise)
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }
                        }
                    }
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentedSheet = .exercise(nil)
                } label: {
                    Label("Exercise", systemImage: "plus")
                }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .exercise(let exercise):
                    FitnessExerciseFormView(initialExercise: exercise) { savedExercise in
                        viewModel.saveExercise(savedExercise, replacingExerciseWithID: exercise?.id)
                        onChange()
                        presentedSheet = nil
                    }
                case .template(let template):
                    WorkoutTemplateFormView(
                        initialTemplate: template,
                        exercises: viewModel.exercises
                    ) { savedTemplate in
                        viewModel.saveWorkoutTemplate(
                            savedTemplate,
                            replacingWorkoutTemplateWithID: template?.id
                        )
                        onChange()
                        presentedSheet = nil
                    } onDelete: {
                        guard let template else { return }
                        viewModel.deleteWorkoutTemplate(withID: template.id)
                        onChange()
                        presentedSheet = nil
                    }
                case .session(let exercise, let session, let isDraft):
                    ExerciseSessionFormView(
                        exercise: exercise,
                        initialSession: session,
                        lastSession: viewModel.latestSession(for: exercise.id),
                        isDraft: isDraft
                    ) { savedSession in
                        viewModel.saveExerciseSession(
                            savedSession,
                            replacingExerciseSessionWithID: isDraft ? nil : session?.id
                        )
                        onChange()
                        presentedSheet = nil
                    }
                }
            }
        }
        .navigationDestination(item: $selectedTemplate) { template in
            WorkoutTemplateDetailView(
                summary: viewModel.templateRows(for: template),
                onEdit: {
                    presentedSheet = .template(template)
                },
                onSelectExercise: { exercise in
                    selectedExercise = exercise
                },
                onLogExercise: { exercise in
                    presentedSheet = .session(exercise, viewModel.draftSession(for: exercise), true)
                }
            )
        }
        .navigationDestination(item: $selectedExercise) { exercise in
            ExerciseDetailView(
                exercise: exercise,
                sessions: viewModel.recentSessions(for: exercise.id, limit: 20),
                loggedToday: viewModel.loggedToday(for: exercise.id),
                onEditExercise: {
                    presentedSheet = .exercise(exercise)
                },
                onLogSession: {
                    presentedSheet = .session(exercise, viewModel.draftSession(for: exercise), true)
                },
                onEditSession: { session in
                    presentedSheet = .session(exercise, session, false)
                },
                onDeleteSession: { session in
                    viewModel.deleteExerciseSession(withID: session.id)
                    onChange()
                }
            )
        }
    }
}

private enum FitnessSheet: Identifiable {
    case exercise(FitnessExercise?)
    case template(WorkoutTemplate?)
    case session(FitnessExercise, ExerciseSession?, Bool)

    var id: String {
        switch self {
        case .exercise(let exercise):
            return "exercise-\(exercise?.id.uuidString ?? "new")"
        case .template(let template):
            return "template-\(template?.id.uuidString ?? "new")"
        case .session(let exercise, let session, let isDraft):
            return "session-\(exercise.id.uuidString)-\(session?.id.uuidString ?? "new")-\(isDraft)"
        }
    }
}

private struct AddWorkoutDayCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Workout Day")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
            }
            .frame(width: 140, height: 110)
    }
}

private struct WorkoutDayCard: View {
    let template: WorkoutTemplate

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.accentColor.opacity(0.12))
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(template.exerciseIDs.count) exercise\(template.exerciseIDs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(width: 160, height: 110)
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: FitnessExercise
    let latestSession: ExerciseSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(exercise.tag.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(exercise.trackingStyle.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(latestSession.map { "Latest: \($0.summaryText)" } ?? "No sessions yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct WorkoutTemplateDetailView: View {
    let summary: FitnessTemplateRowSummary
    let onEdit: () -> Void
    let onSelectExercise: (FitnessExercise) -> Void
    let onLogExercise: (FitnessExercise) -> Void

    var body: some View {
        List {
            ForEach(summary.rows) { row in
                WorkoutTemplateExerciseRowView(
                    row: row,
                    onSelectExercise: onSelectExercise,
                    onLogExercise: onLogExercise
                )
            }
        }
        .navigationTitle(summary.template.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
            }
        }
    }
}

private struct WorkoutTemplateExerciseRowView: View {
    let row: FitnessTemplateExerciseRow
    let onSelectExercise: (FitnessExercise) -> Void
    let onLogExercise: (FitnessExercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onSelectExercise(row.exercise)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.exercise.name)
                            .font(.body.weight(.semibold))
                        Spacer()
                        if row.loggedToday {
                            Text("Logged today")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("\(row.exercise.tag.displayName) · \(row.exercise.trackingStyle.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.latestSession.map { "Last: \($0.summaryText)" } ?? "No sessions yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(row.priorSessions) { session in
                        Text(session.summaryText)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button {
                onLogExercise(row.exercise)
            } label: {
                Label("Log", systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 4)
    }
}

private struct ExerciseDetailView: View {
    let exercise: FitnessExercise
    let sessions: [ExerciseSession]
    let loggedToday: Bool
    let onEditExercise: () -> Void
    let onLogSession: () -> Void
    let onEditSession: (ExerciseSession) -> Void
    let onDeleteSession: (ExerciseSession) -> Void

    var body: some View {
        List {
            Section("Exercise") {
                LabeledContent("Tag", value: exercise.tag.displayName)
                LabeledContent("Tracking", value: exercise.trackingStyle.displayName)
                if let weightUnit = exercise.weightUnit {
                    LabeledContent("Weight Unit", value: weightUnit.displayName)
                }
                if let distanceUnit = exercise.distanceUnit {
                    LabeledContent("Distance Unit", value: distanceUnit.displayName)
                }
                if exercise.selectableMetricFields.isEmpty == false {
                    LabeledContent(
                        "Fields",
                        value: exercise.selectableMetricFields.map(\.displayName).joined(separator: ", ")
                    )
                }
                if loggedToday {
                    Text("Logged today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Recent History") {
                if let latestSession = sessions.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last logged \(latestSession.performedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline.weight(.semibold))
                        Text(latestSession.summaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if sessions.isEmpty {
                    Text("No sessions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.body.weight(.semibold))
                            Text(session.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button {
                                onEditSession(session)
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }

                            Button(role: .destructive) {
                                onDeleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Log", action: onLogSession)
                Button("Edit", action: onEditExercise)
            }
        }
    }
}

private struct FitnessExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialExercise: FitnessExercise?
    let onSave: (FitnessExercise) -> Void

    @State private var name: String
    @State private var tag: FitnessTag
    @State private var trackingStyle: ExerciseTrackingStyle
    @State private var metricFields: Set<SelectableMetricField>
    @State private var weightUnit: WeightUnit
    @State private var distanceUnit: DistanceUnit

    init(
        initialExercise: FitnessExercise?,
        onSave: @escaping (FitnessExercise) -> Void
    ) {
        self.initialExercise = initialExercise
        self.onSave = onSave
        _name = State(initialValue: initialExercise?.name ?? "")
        _tag = State(initialValue: initialExercise?.tag ?? .push)
        _trackingStyle = State(initialValue: initialExercise?.trackingStyle ?? .strengthSets)
        _metricFields = State(initialValue: Set(initialExercise?.selectableMetricFields ?? [.durationMinutes]))
        _weightUnit = State(initialValue: initialExercise?.weightUnit ?? .pounds)
        _distanceUnit = State(initialValue: initialExercise?.distanceUnit ?? .miles)
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)
                Picker("Tag", selection: $tag) {
                    ForEach(FitnessTag.allCases, id: \.self) { tag in
                        Text(tag.displayName).tag(tag)
                    }
                }
                Picker("Tracking", selection: $trackingStyle) {
                    ForEach(ExerciseTrackingStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            }

            if trackingStyle == .strengthSets {
                Section("Strength") {
                    Picker("Weight Unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            } else {
                Section("Metrics") {
                    ForEach(SelectableMetricField.allCases, id: \.self) { field in
                        Toggle(
                            field.displayName,
                            isOn: Binding(
                                get: { metricFields.contains(field) },
                                set: { isEnabled in
                                    if isEnabled {
                                        metricFields.insert(field)
                                    } else {
                                        metricFields.remove(field)
                                    }
                                }
                            )
                        )
                    }

                    if metricFields.contains(.distance) {
                        Picker("Distance Unit", selection: $distanceUnit) {
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(initialExercise == nil ? "New Exercise" : "Edit Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let exercise = makeExercise() else {
                        return
                    }
                    onSave(exercise)
                }
            }
        }
    }

    private func makeExercise() -> FitnessExercise? {
        let fields = Array(metricFields)
        guard let cleanedName = FitnessExercise.cleanedName(from: name),
              FitnessExercise.isConfigurationValid(
                trackingStyle: trackingStyle,
                selectableMetricFields: fields,
                weightUnit: trackingStyle == .strengthSets ? weightUnit : nil,
                distanceUnit: trackingStyle == .metricSummary && metricFields.contains(.distance) ? distanceUnit : nil
              ) else {
            return nil
        }

        return FitnessExercise(
            id: initialExercise?.id ?? UUID(),
            name: cleanedName,
            tag: tag,
            trackingStyle: trackingStyle,
            selectableMetricFields: fields,
            weightUnit: trackingStyle == .strengthSets ? weightUnit : nil,
            distanceUnit: trackingStyle == .metricSummary && metricFields.contains(.distance) ? distanceUnit : nil,
            createdAt: initialExercise?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private struct WorkoutTemplateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialTemplate: WorkoutTemplate?
    let exercises: [FitnessExercise]
    let onSave: (WorkoutTemplate) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var exerciseIDs: [UUID]

    init(
        initialTemplate: WorkoutTemplate?,
        exercises: [FitnessExercise],
        onSave: @escaping (WorkoutTemplate) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.initialTemplate = initialTemplate
        self.exercises = exercises
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialTemplate?.name ?? "")
        _exerciseIDs = State(initialValue: initialTemplate?.exerciseIDs ?? [])
    }

    var body: some View {
        Form {
            Section("Workout Day") {
                TextField("Name", text: $name)
            }

            Section("Exercises") {
                if exerciseIDs.isEmpty {
                    Text("Add at least one exercise.")
                        .foregroundStyle(.secondary)
                }

                ForEach(selectedExercises) { exercise in
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        Button(role: .destructive) {
                            exerciseIDs.removeAll { $0 == exercise.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { source, destination in
                    exerciseIDs.move(fromOffsets: source, toOffset: destination)
                }
            }

            Section("Add Existing") {
                ForEach(availableExercises) { exercise in
                    Button(exercise.name) {
                        exerciseIDs.append(exercise.id)
                    }
                }
            }
        }
        .navigationTitle(initialTemplate == nil ? "New Workout Day" : "Edit Workout Day")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let template = makeTemplate() else {
                        return
                    }
                    onSave(template)
                }
            }
            if initialTemplate != nil {
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
        }
    }

    private var selectedExercises: [FitnessExercise] {
        exerciseIDs.compactMap { id in
            exercises.first { $0.id == id }
        }
    }

    private var availableExercises: [FitnessExercise] {
        exercises.filter { exerciseIDs.contains($0.id) == false }
    }

    private func makeTemplate() -> WorkoutTemplate? {
        guard let cleanedName = WorkoutTemplate.cleanedName(from: name) else {
            return nil
        }

        let cleanedExerciseIDs = WorkoutTemplate.cleanedExerciseIDs(exerciseIDs)
        guard cleanedExerciseIDs.isEmpty == false else {
            return nil
        }

        return WorkoutTemplate(
            id: initialTemplate?.id ?? UUID(),
            name: cleanedName,
            exerciseIDs: cleanedExerciseIDs,
            createdAt: initialTemplate?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private struct ExerciseSessionFormView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: FitnessExercise
    let initialSession: ExerciseSession?
    let lastSession: ExerciseSession?
    let isDraft: Bool
    let onSave: (ExerciseSession) -> Void

    @State private var strengthSets: [StrengthSet]
    @State private var durationMinutes: Int
    @State private var difficultyLevel: Int
    @State private var averageRPM: Int
    @State private var distance: Double

    init(
        exercise: FitnessExercise,
        initialSession: ExerciseSession?,
        lastSession: ExerciseSession?,
        isDraft: Bool,
        onSave: @escaping (ExerciseSession) -> Void
    ) {
        self.exercise = exercise
        self.initialSession = initialSession
        self.lastSession = lastSession
        self.isDraft = isDraft
        self.onSave = onSave
        _strengthSets = State(initialValue: initialSession?.strengthSets ?? [StrengthSet(reps: 0)])
        _durationMinutes = State(initialValue: initialSession?.durationMinutes ?? 0)
        _difficultyLevel = State(initialValue: initialSession?.difficultyLevel ?? 5)
        _averageRPM = State(initialValue: initialSession?.averageRPM ?? 0)
        _distance = State(initialValue: initialSession?.distance ?? 0)
    }

    var body: some View {
        Form {
            draftSeedNoticeSection
            lastSessionSection
            sessionFieldsSection
        }
        .navigationTitle(isDraft ? "Quick Log" : "Edit Session")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let session = makeSession()
                    guard session.isValid(for: exercise) else {
                        return
                    }
                    onSave(session)
                }
            }
        }
    }

    @ViewBuilder
    private var draftSeedNoticeSection: some View {
        if isDraft, let lastSession {
            SessionDraftNoticeView(lastSession: lastSession)
                .listRowBackground(Color.secondary.opacity(0.08))
        }
    }

    @ViewBuilder
    private var lastSessionSection: some View {
        if let lastSession {
            SessionSummarySection(lastSession: lastSession)
        }
    }

    @ViewBuilder
    private var sessionFieldsSection: some View {
        if exercise.trackingStyle == .strengthSets {
            StrengthSessionSection(
                strengthSets: $strengthSets,
                weightLabel: exercise.weightUnit?.displayName ?? "Weight",
                isDraft: isDraft
            )
        } else {
            MetricSessionSection(
                selectableMetricFields: exercise.selectableMetricFields,
                distanceLabel: exercise.distanceUnit?.displayName ?? "",
                isDraft: isDraft,
                durationMinutes: $durationMinutes,
                difficultyLevel: $difficultyLevel,
                averageRPM: $averageRPM,
                distance: $distance
            )
        }
    }

    private func makeSession() -> ExerciseSession {
        ExerciseSession(
            id: initialSession?.id ?? UUID(),
            exerciseID: exercise.id,
            performedAt: initialSession?.performedAt ?? .now,
            strengthSets: exercise.trackingStyle == .strengthSets ? strengthSets : [],
            durationMinutes: exercise.selectableMetricFields.contains(.durationMinutes) ? durationMinutes : nil,
            difficultyLevel: exercise.selectableMetricFields.contains(.difficultyLevel) ? difficultyLevel : nil,
            averageRPM: exercise.selectableMetricFields.contains(.averageRPM) ? averageRPM : nil,
            distance: exercise.selectableMetricFields.contains(.distance) ? distance : nil,
            createdAt: initialSession?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private struct SessionDraftNoticeView: View {
    let lastSession: ExerciseSession

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("Draft from last session", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                Text(lastSession.performedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Values are prefilled from the most recent log for this exercise. Adjust anything before saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }
}

private struct SessionSummarySection: View {
    let lastSession: ExerciseSession

    var body: some View {
        Section("Last Session") {
            Text(lastSession.performedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(lastSession.summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StrengthSessionSection: View {
    @Binding var strengthSets: [StrengthSet]

    let weightLabel: String
    let isDraft: Bool

    var body: some View {
        Section("Sets") {
            ForEach(strengthSets.indices, id: \.self) { index in
                StrengthSetRow(
                    reps: Binding(
                        get: { strengthSets[index].reps },
                        set: { strengthSets[index].reps = $0 }
                    ),
                    weight: Binding(
                        get: { strengthSets[index].weight ?? 0 },
                        set: { strengthSets[index].weight = $0 == 0 ? nil : $0 }
                    ),
                    weightLabel: weightLabel,
                    isDraft: isDraft
                )
            }
            .onDelete { offsets in
                strengthSets.remove(atOffsets: offsets)
            }

            Button("Add Set") {
                strengthSets.append(StrengthSet(reps: 0))
            }
        }
    }
}

private struct StrengthSetRow: View {
    @Binding var reps: Int
    @Binding var weight: Double

    let weightLabel: String
    let isDraft: Bool

    var body: some View {
        HStack {
            Stepper(value: $reps, in: 0...100) {
                Text("Reps \(reps)")
                    .foregroundStyle(isDraft ? .secondary : .primary)
            }
            TextField(weightLabel, value: $weight, format: .number)
                .foregroundStyle(isDraft ? .secondary : .primary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct MetricSessionSection: View {
    let selectableMetricFields: [SelectableMetricField]
    let distanceLabel: String
    let isDraft: Bool

    @Binding var durationMinutes: Int
    @Binding var difficultyLevel: Int
    @Binding var averageRPM: Int
    @Binding var distance: Double

    var body: some View {
        Section("Metrics") {
            if selectableMetricFields.contains(.durationMinutes) {
                MetricStepperRow(
                    title: "Duration \(durationMinutes)m",
                    value: $durationMinutes,
                    range: 0...600,
                    isDraft: isDraft
                )
            }
            if selectableMetricFields.contains(.difficultyLevel) {
                MetricStepperRow(
                    title: "Difficulty \(difficultyLevel)",
                    value: $difficultyLevel,
                    range: 1...10,
                    isDraft: isDraft
                )
            }
            if selectableMetricFields.contains(.averageRPM) {
                MetricStepperRow(
                    title: "Average RPM \(averageRPM)",
                    value: $averageRPM,
                    range: 0...300,
                    isDraft: isDraft
                )
            }
            if selectableMetricFields.contains(.distance) {
                TextField("Distance (\(distanceLabel))", value: $distance, format: .number)
                    .foregroundStyle(isDraft ? .secondary : .primary)
                    .keyboardType(.decimalPad)
            }
        }
    }
}

private struct MetricStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let isDraft: Bool

    var body: some View {
        Stepper(value: $value, in: range) {
            Text(title)
                .foregroundStyle(isDraft ? .secondary : .primary)
        }
    }
}
