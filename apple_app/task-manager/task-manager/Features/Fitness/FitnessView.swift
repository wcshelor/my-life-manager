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

    private let workoutColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section("Workouts") {
                LazyVGrid(columns: workoutColumns, spacing: 12) {
                    ForEach(viewModel.workoutTemplates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            WorkoutCard(template: template)
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

                    Button {
                        presentedSheet = .template(nil)
                    } label: {
                        AddWorkoutCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
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
                        exercises: viewModel.exercises,
                        latestSessionDatesByExerciseID: viewModel.latestSessionDatesByExerciseID
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
                        isDraft: isDraft,
                        routes: viewModel.routes(for: exercise.distanceUnit),
                        onSaveRoute: { route in
                            viewModel.saveRoute(route)
                            onChange()
                        }
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

private struct AddWorkoutCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add Workout")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.primary)
                .padding(8)
            }
            .frame(maxWidth: .infinity, minHeight: 108)
    }
}

private struct WorkoutCard: View {
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
                    Spacer(minLength: 0)
                    Text("\(template.exerciseIDs.count) exercise\(template.exerciseIDs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, minHeight: 108)
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
                if exercise.metricFields.isEmpty == false {
                    LabeledContent(
                        "Fields",
                        value: exercise.metricFields.map(\.displayName).joined(separator: ", ")
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
                        if let notes = latestSession.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if sessions.isEmpty {
                    Text("No sessions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Button("Edit") {
                                    onEditSession(session)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.borderless)
                            }
                            Text(session.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let notes = session.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
            } else if trackingStyle == .metricSummary {
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
            } else {
                Section("Preset") {
                    Text(presetDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            }
        }
        .navigationTitle(initialExercise == nil ? "New Exercise" : "Edit Exercise")
        .onChange(of: trackingStyle) { _, newStyle in
            if newStyle == .stationaryBike || newStyle == .normalBike || newStyle == .walk {
                tag = .cardio
            }
        }
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

    private var presetDescription: String {
        switch trackingStyle {
        case .stationaryBike:
            return "Fast path for duration, difficulty, average RPM, and distance."
        case .normalBike:
            return "Fast path for duration and distance."
        case .walk:
            return "Fast path for duration and distance."
        default:
            return ""
        }
    }

    private func makeExercise() -> FitnessExercise? {
        let fields = Array(metricFields)
        guard let cleanedName = FitnessExercise.cleanedName(from: name),
              FitnessExercise.isConfigurationValid(
                trackingStyle: trackingStyle,
                selectableMetricFields: fields,
                weightUnit: trackingStyle == .strengthSets ? weightUnit : nil,
                distanceUnit: usesDistance ? distanceUnit : nil
              ) else {
            return nil
        }

        return FitnessExercise(
            id: initialExercise?.id ?? UUID(),
            name: cleanedName,
            tag: tag,
            trackingStyle: trackingStyle,
            selectableMetricFields: trackingStyle == .metricSummary ? fields : [],
            weightUnit: trackingStyle == .strengthSets ? weightUnit : nil,
            distanceUnit: usesDistance ? distanceUnit : nil,
            createdAt: initialExercise?.createdAt ?? .now,
            updatedAt: .now
        )
    }

    private var usesDistance: Bool {
        if trackingStyle == .metricSummary {
            return metricFields.contains(.distance)
        }

        return trackingStyle.metricFields.contains(.distance)
    }
}

private struct WorkoutTemplateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialTemplate: WorkoutTemplate?
    let exercises: [FitnessExercise]
    let latestSessionDatesByExerciseID: [UUID: Date]
    let onSave: (WorkoutTemplate) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var exerciseIDs: [UUID]
    @State private var addExistingSortOption: ExerciseSortOption = .recent

    init(
        initialTemplate: WorkoutTemplate?,
        exercises: [FitnessExercise],
        latestSessionDatesByExerciseID: [UUID: Date],
        onSave: @escaping (WorkoutTemplate) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.initialTemplate = initialTemplate
        self.exercises = exercises
        self.latestSessionDatesByExerciseID = latestSessionDatesByExerciseID
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialTemplate?.name ?? "")
        _exerciseIDs = State(initialValue: initialTemplate?.exerciseIDs ?? [])
    }

    var body: some View {
        Form {
            Section("Workout") {
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

            Section {
                Picker("Add Existing Sort", selection: $addExistingSortOption) {
                    ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Add Existing") {
                ForEach(availableExercises) { exercise in
                    Button {
                        exerciseIDs.append(exercise.id)
                    } label: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Text(exercise.tag.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(initialTemplate == nil ? "New Workout" : "Edit Workout")
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
        let remainingExercises = exercises.filter { exerciseIDs.contains($0.id) == false }
        switch addExistingSortOption {
        case .alphabetical:
            return remainingExercises.sortedAlphabetically()
        case .tag:
            return remainingExercises.sorted { leftExercise, rightExercise in
                if leftExercise.tag != rightExercise.tag {
                    return leftExercise.tag.displayName < rightExercise.tag.displayName
                }

                let comparison = leftExercise.name.localizedCaseInsensitiveCompare(rightExercise.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }

                return leftExercise.id.uuidString < rightExercise.id.uuidString
            }
        case .recent:
            return remainingExercises.sorted { leftExercise, rightExercise in
                let leftDate = latestSessionDatesByExerciseID[leftExercise.id]
                let rightDate = latestSessionDatesByExerciseID[rightExercise.id]
                switch (leftDate, rightDate) {
                case let (leftDate?, rightDate?):
                    if leftDate != rightDate {
                        return leftDate > rightDate
                    }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }

                let comparison = leftExercise.name.localizedCaseInsensitiveCompare(rightExercise.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }

                return leftExercise.id.uuidString < rightExercise.id.uuidString
            }
        }
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
    let routes: [FitnessRoute]
    let onSaveRoute: (FitnessRoute) -> Void
    let onSave: (ExerciseSession) -> Void

    @State private var strengthSets: [StrengthSet]
    @State private var durationMinutes: Int
    @State private var difficultyLevel: Int
    @State private var averageRPM: Int
    @State private var distance: Double
    @State private var notes: String
    @State private var routeSheet: SessionRouteSheet?

    init(
        exercise: FitnessExercise,
        initialSession: ExerciseSession?,
        lastSession: ExerciseSession?,
        isDraft: Bool,
        routes: [FitnessRoute],
        onSaveRoute: @escaping (FitnessRoute) -> Void,
        onSave: @escaping (ExerciseSession) -> Void
    ) {
        self.exercise = exercise
        self.initialSession = initialSession
        self.lastSession = lastSession
        self.isDraft = isDraft
        self.routes = routes
        self.onSaveRoute = onSaveRoute
        self.onSave = onSave
        _strengthSets = State(initialValue: initialSession?.strengthSets ?? [StrengthSet(reps: 0)])
        _durationMinutes = State(initialValue: initialSession?.durationMinutes ?? 0)
        _difficultyLevel = State(initialValue: initialSession?.difficultyLevel ?? 5)
        _averageRPM = State(initialValue: initialSession?.averageRPM ?? 0)
        _distance = State(initialValue: initialSession?.distance ?? 0)
        _notes = State(initialValue: initialSession?.notes ?? "")
    }

    var body: some View {
        Form {
            draftSeedNoticeSection
            lastSessionSection
            sessionFieldsSection
            notesSection
        }
        .navigationTitle(isDraft ? "Quick Log" : "Edit Session")
        .sheet(item: $routeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .picker:
                    RoutePickerView(
                        routes: routes,
                        distanceUnit: exercise.distanceUnit ?? .miles,
                        onSelect: { route in
                            distance = route.distance
                            routeSheet = nil
                        },
                        onCreateNew: {
                            routeSheet = .newRoute
                        }
                    )
                case .newRoute:
                    NewRouteFormView(
                        distanceUnit: exercise.distanceUnit ?? .miles,
                        initialDistance: distance
                    ) { route in
                        onSaveRoute(route)
                        distance = route.distance
                        routeSheet = nil
                    }
                }
            }
            .presentationDetents(sheet == .newRoute ? [.medium] : [.fraction(0.55)])
        }
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
                trackingStyle: exercise.trackingStyle,
                metricFields: exercise.metricFields,
                distanceLabel: exercise.distanceUnit?.displayName ?? "",
                isDraft: isDraft,
                durationMinutes: $durationMinutes,
                difficultyLevel: $difficultyLevel,
                averageRPM: $averageRPM,
                distance: $distance,
                onOpenRoutes: exercise.metricFields.contains(.distance) ? {
                    routeSheet = .picker
                } : nil
            )
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional note", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func makeSession() -> ExerciseSession {
        ExerciseSession(
            id: initialSession?.id ?? UUID(),
            exerciseID: exercise.id,
            performedAt: initialSession?.performedAt ?? .now,
            strengthSets: exercise.trackingStyle == .strengthSets ? strengthSets : [],
            durationMinutes: exercise.metricFields.contains(.durationMinutes) ? durationMinutes : nil,
            difficultyLevel: exercise.metricFields.contains(.difficultyLevel) ? difficultyLevel : nil,
            averageRPM: exercise.metricFields.contains(.averageRPM) ? averageRPM : nil,
            distance: exercise.metricFields.contains(.distance) ? distance : nil,
            notes: notes,
            createdAt: initialSession?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private enum SessionRouteSheet: Identifiable, Equatable {
    case picker
    case newRoute

    var id: String {
        switch self {
        case .picker:
            return "picker"
        case .newRoute:
            return "new-route"
        }
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
            if let notes = lastSession.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                    setNumber: index + 1,
                    reps: Binding(
                        get: { strengthSets[index].reps },
                        set: { strengthSets[index].reps = max(0, $0) }
                    ),
                    weight: Binding(
                        get: { strengthSets[index].weight },
                        set: { strengthSets[index].weight = $0 }
                    ),
                    weightLabel: weightLabel,
                    isDraft: isDraft
                )
            }
            .onDelete { offsets in
                strengthSets.remove(atOffsets: offsets)
            }

            Button("Add Set") {
                strengthSets.append(StrengthSet(reps: 0, weight: strengthSets.last?.weight))
            }
        }
    }
}

private struct StrengthSetRow: View {
    let setNumber: Int
    @Binding var reps: Double
    @Binding var weight: Double?

    let weightLabel: String
    let isDraft: Bool

    @State private var showingWeightPicker = false

    var body: some View {
        HStack(spacing: 10) {
            Stepper(value: wholeRepsBinding, in: 0...100) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set \(setNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Reps \(repsText)")
                        .foregroundStyle(isDraft ? .secondary : .primary)
                }
            }

            Picker("Half Rep", selection: halfRepBinding) {
                Text("0").tag(false)
                Text(".5").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 74)

            Button {
                showingWeightPicker = true
            } label: {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(weightText)
                        .font(.subheadline.weight(.semibold))
                    Text(weightLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 68, alignment: .trailing)
                .foregroundStyle(isDraft ? .secondary : .primary)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingWeightPicker) {
            NavigationStack {
                WeightWheelPickerSheet(weight: $weight, unitLabel: weightLabel)
            }
            .presentationDetents([.height(280)])
        }
    }

    private var wholeRepsBinding: Binding<Int> {
        Binding(
            get: { Int(reps.rounded(.down)) },
            set: { newValue in
                reps = Double(max(0, newValue)) + (hasHalfRep ? 0.5 : 0)
            }
        )
    }

    private var halfRepBinding: Binding<Bool> {
        Binding(
            get: { hasHalfRep },
            set: { newValue in
                let wholePart = Int(reps.rounded(.down))
                reps = Double(wholePart) + (newValue ? 0.5 : 0)
            }
        )
    }

    private var hasHalfRep: Bool {
        abs(reps.truncatingRemainder(dividingBy: 1) - 0.5) < 0.1
    }

    private var repsText: String {
        if reps.rounded() == reps {
            return String(Int(reps))
        }

        return String(format: "%.1f", reps)
    }

    private var weightText: String {
        guard let weight else {
            return "Body"
        }

        if weight.rounded() == weight {
            return String(Int(weight))
        }

        return String(format: "%.1f", weight)
    }
}

private struct WeightWheelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weight: Double?

    let unitLabel: String

    @State private var wholePart: Int
    @State private var halfPart: Int

    init(weight: Binding<Double?>, unitLabel: String) {
        _weight = weight
        self.unitLabel = unitLabel

        let currentWeight = weight.wrappedValue ?? 0
        let wholePart = Int(currentWeight.rounded(.down))
        let fractionalPart = currentWeight - Double(wholePart)
        _wholePart = State(initialValue: wholePart)
        _halfPart = State(initialValue: fractionalPart >= 0.5 ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Clear") {
                    weight = nil
                    dismiss()
                }
                Spacer()
                Text("Weight")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    let selectedWeight = Double(wholePart) + (halfPart == 1 ? 0.5 : 0)
                    weight = selectedWeight == 0 ? nil : selectedWeight
                    dismiss()
                }
            }
            .padding()

            HStack(spacing: 0) {
                Picker("Whole", selection: $wholePart) {
                    ForEach(0...500, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Half", selection: $halfPart) {
                    Text(".0").tag(0)
                    Text(".5").tag(1)
                }
                .pickerStyle(.wheel)

                Text(unitLabel)
                    .font(.headline)
                    .frame(width: 42)
            }
        }
    }
}

private struct MetricSessionSection: View {
    let trackingStyle: ExerciseTrackingStyle
    let metricFields: [SelectableMetricField]
    let distanceLabel: String
    let isDraft: Bool

    @Binding var durationMinutes: Int
    @Binding var difficultyLevel: Int
    @Binding var averageRPM: Int
    @Binding var distance: Double

    let onOpenRoutes: (() -> Void)?

    var body: some View {
        Section(sectionTitle) {
            if metricFields.contains(.durationMinutes) {
                MetricStepperRow(
                    title: "Duration \(durationMinutes)m",
                    value: $durationMinutes,
                    range: 0...600,
                    isDraft: isDraft
                )
            }
            if metricFields.contains(.difficultyLevel) {
                MetricStepperRow(
                    title: "Difficulty \(difficultyLevel)",
                    value: $difficultyLevel,
                    range: 1...10,
                    isDraft: isDraft
                )
            }
            if metricFields.contains(.averageRPM) {
                MetricStepperRow(
                    title: "Average RPM \(averageRPM)",
                    value: $averageRPM,
                    range: 0...300,
                    isDraft: isDraft
                )
            }
            if metricFields.contains(.distance) {
                HStack {
                    TextField("Distance (\(distanceLabel))", value: $distance, format: .number)
                        .foregroundStyle(isDraft ? .secondary : .primary)
                        .keyboardType(.decimalPad)
                    if let onOpenRoutes {
                        Button("Routes", action: onOpenRoutes)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var sectionTitle: String {
        switch trackingStyle {
        case .stationaryBike, .normalBike, .walk:
            return trackingStyle.displayName
        default:
            return "Metrics"
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

private struct RoutePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let routes: [FitnessRoute]
    let distanceUnit: DistanceUnit
    let onSelect: (FitnessRoute) -> Void
    let onCreateNew: () -> Void

    var body: some View {
        List {
            Section("Routes") {
                if routes.isEmpty {
                    Text("No saved \(distanceUnit.displayName) routes yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routes) { route in
                        Button {
                            onSelect(route)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name)
                                    Text("\(distanceText(route.distance)) \(route.distanceUnit.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }

            Section {
                Button("+ New Route") {
                    onCreateNew()
                }
            }
        }
        .navigationTitle("Routes")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private func distanceText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }
}

private struct NewRouteFormView: View {
    @Environment(\.dismiss) private var dismiss

    let distanceUnit: DistanceUnit
    let onSave: (FitnessRoute) -> Void

    @State private var name: String = ""
    @State private var distance: Double

    init(
        distanceUnit: DistanceUnit,
        initialDistance: Double,
        onSave: @escaping (FitnessRoute) -> Void
    ) {
        self.distanceUnit = distanceUnit
        self.onSave = onSave
        _distance = State(initialValue: max(0, initialDistance))
    }

    var body: some View {
        Form {
            Section("Route") {
                TextField("Name", text: $name)
                TextField("Distance (\(distanceUnit.displayName))", value: $distance, format: .number)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("New Route")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let route = FitnessRoute(
                        newName: name,
                        distance: distance,
                        distanceUnit: distanceUnit
                    ) else {
                        return
                    }

                    onSave(route)
                }
            }
        }
    }
}
