import Combine
import SwiftUI

struct VicesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VicesViewModel
    @State private var draftName = ""
    @State private var draftUnitLabel = ""
    @State private var isShowingAddSheet = false
    @State private var editingVice: Vice?
    @State private var editingGoal: ViceGoalEditorState?
    @State private var draftGoalMaxOccurrences = 1
    @State private var draftGoalDeadline = Date.now
    @State private var draftGoalDeadlineMode: ViceGoalDeadlineMode = .custom
    @State private var draftGoalEndOfDayDate = Date.now
    @State private var linkingRoutineVice: Vice?
    @State private var editingRoutineState: ViceRoutineEditorState?
    @State private var presentedRoutineSession: ViceRoutineSessionState?

    @ObservedObject private var homeViewModel: HomeExecutionViewModel
    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let scheduledBlockRepository: any ScheduledBlockRepository
    private let settingsRepository: any SettingsRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private let calendarReader: any CalendarReading
    private let calendarWriter: any CalendarWriting
    private let calendarReconciler: any CalendarReconciling
    private let calendarChangeObserver: any CalendarChangeObserving
    private let promiseRepository: any PromiseRepository
    private let shoppingRepository: any ShoppingRepository
    private let healthRepository: any HealthRepository
    private let musicPracticeRepository: any MusicPracticeRepository
    private let fitnessRepository: any FitnessRepository
    private let peopleMemoryRepository: any PeopleMemoryRepository
    private let viceRepository: any ViceRepository
    private let calendarBlockFocusRepository: any CalendarBlockFocusRepository
    private let debriefRepository: any DebriefRepository
    private let financeRepository: any FinanceRepository
    private let onChange: () -> Void

    init(
        homeViewModel: HomeExecutionViewModel,
        routineRepository: any RoutineRepository,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        scheduledBlockRepository: any ScheduledBlockRepository,
        settingsRepository: any SettingsRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendarWriter: any CalendarWriting,
        calendarReconciler: any CalendarReconciling,
        calendarChangeObserver: any CalendarChangeObserving,
        promiseRepository: any PromiseRepository,
        shoppingRepository: any ShoppingRepository,
        healthRepository: any HealthRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        fitnessRepository: any FitnessRepository,
        peopleMemoryRepository: any PeopleMemoryRepository,
        viceRepository: any ViceRepository,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        debriefRepository: any DebriefRepository,
        financeRepository: any FinanceRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.homeViewModel = homeViewModel
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.scheduledBlockRepository = scheduledBlockRepository
        self.settingsRepository = settingsRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.calendarReader = calendarReader
        self.calendarWriter = calendarWriter
        self.calendarReconciler = calendarReconciler
        self.calendarChangeObserver = calendarChangeObserver
        self.promiseRepository = promiseRepository
        self.shoppingRepository = shoppingRepository
        self.healthRepository = healthRepository
        self.musicPracticeRepository = musicPracticeRepository
        self.fitnessRepository = fitnessRepository
        self.peopleMemoryRepository = peopleMemoryRepository
        self.viceRepository = viceRepository
        self.calendarBlockFocusRepository = calendarBlockFocusRepository
        self.debriefRepository = debriefRepository
        self.financeRepository = financeRepository
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: VicesViewModel(
                viceRepository: viceRepository,
                routineRepository: routineRepository,
                debriefRepository: debriefRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let now = timeline.date
                    if viewModel.activeVices.isEmpty {
                        ContentUnavailableView(
                            "No Vices Yet",
                            systemImage: "flame",
                            description: Text("Add a vice to start logging each occurrence with one tap.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.summaries) { summary in
                                    ViceCard(
                                        summary: summary,
                                        now: now,
                                        onTap: {
                                            handleViceTap(summary)
                                        },
                                        onEdit: {
                                            editingVice = summary.vice
                                            draftName = summary.vice.name
                                            draftUnitLabel = summary.vice.unitLabel
                                        },
                                        onArchive: {
                                            viewModel.archiveVice(withID: summary.vice.id)
                                            onChange()
                                        },
                                        onEditGoal: {
                                            let currentGoal = summary.goalProgress?.goal
                                            editingGoal = ViceGoalEditorState(
                                                vice: summary.vice,
                                                goal: currentGoal
                                            )
                                            draftGoalMaxOccurrences = currentGoal?.maxOccurrences ?? max(1, summary.todayCount + 1)
                                            draftGoalDeadline = currentGoal?.deadline ?? Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
                                            draftGoalDeadlineMode = currentGoal?.deadline.isEndOfDay(in: Calendar.current) == true ? .endOfDay : .custom
                                            draftGoalEndOfDayDate = currentGoal?.deadline ?? now
                                        },
                                        onCreateRoutine: {
                                            editingRoutineState = ViceRoutineEditorState(
                                                vice: summary.vice,
                                                routine: summary.linkedRoutine ?? Routine(
                                                    name: summary.vice.name,
                                                    kind: .viceLinked,
                                                    viceID: summary.vice.id,
                                                    items: [RoutineItem(title: "", position: 0)]
                                                )
                                            )
                                        },
                                        onLinkRoutine: {
                                            linkingRoutineVice = summary.vice
                                        },
                                        onOpenRoutine: {
                                            guard let routine = summary.linkedRoutine else {
                                                return
                                            }
                                            presentedRoutineSession = ViceRoutineSessionState(
                                                viceID: summary.vice.id,
                                                routineID: routine.id
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                if let viceName = viewModel.pendingUndoViceName {
                    HStack(spacing: 12) {
                        Text("Logged \(viceName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button("Undo") {
                            viewModel.undoLastLog()
                            onChange()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Vices")
            .task {
                viewModel.loadIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingVice = nil
                        draftName = ""
                        draftUnitLabel = ""
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Vice", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationStack {
                    viceForm(title: "New Vice") {
                        if viewModel.saveVice(name: draftName, unitLabel: draftUnitLabel) {
                            isShowingAddSheet = false
                            onChange()
                        }
                    }
                }
            }
            .sheet(item: $editingVice) { vice in
                NavigationStack {
                    viceForm(title: "Edit Vice") {
                        if viewModel.saveVice(
                            name: draftName,
                            unitLabel: draftUnitLabel,
                            replacingViceWithID: vice.id
                        ) {
                            editingVice = nil
                            onChange()
                        }
                    }
                }
            }
            .sheet(item: $editingGoal) { state in
                NavigationStack {
                    goalForm(for: state)
                }
            }
            .sheet(item: $linkingRoutineVice) { vice in
                NavigationStack {
                    existingRoutinePicker(for: vice)
                }
            }
            .sheet(item: $editingRoutineState) { state in
                NavigationStack {
                    RoutineEditorView(routine: state.routine) { routine, originalID in
                        if viewModel.saveViceRoutine(routine, for: state.vice.id, replacingRoutineWithID: originalID) {
                            editingRoutineState = nil
                            homeViewModel.load()
                            onChange()
                        }
                    }
                }
            }
            .sheet(item: $presentedRoutineSession) { state in
                NavigationStack {
                    RoutineSessionView(
                        viewModel: homeViewModel,
                        registry: HomeWidgetRegistry.standard,
                        taskRepository: taskRepository,
                        projectRepository: projectRepository,
                        captureRepository: captureRepository,
                        projectItemRepository: projectItemRepository,
                        scheduledBlockRepository: scheduledBlockRepository,
                        settingsRepository: settingsRepository,
                        calendarPermissionProvider: calendarPermissionProvider,
                        calendarListingService: calendarListingService,
                        calendarReader: calendarReader,
                        calendarWriter: calendarWriter,
                        calendarReconciler: calendarReconciler,
                        calendarChangeObserver: calendarChangeObserver,
                        promiseRepository: promiseRepository,
                        shoppingRepository: shoppingRepository,
                        healthRepository: healthRepository,
                        musicPracticeRepository: musicPracticeRepository,
                        fitnessRepository: fitnessRepository,
                        peopleMemoryRepository: peopleMemoryRepository,
                        viceRepository: viceRepository,
                        calendarBlockFocusRepository: calendarBlockFocusRepository,
                        debriefRepository: debriefRepository,
                        financeRepository: financeRepository,
                        routineID: state.routineID,
                        sessionKind: .viceGate(viceID: state.viceID, onComplete: {
                            viewModel.load()
                            homeViewModel.load()
                            onChange()
                        })
                    )
                }
            }
        }
    }

    private func viceForm(
        title: String,
        onSave: @escaping () -> Void
    ) -> some View {
        Form {
            Section("Vice") {
                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)

                TextField("Unit label", text: $draftUnitLabel)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isShowingAddSheet = false
                    editingVice = nil
                }
            }
        }
    }

    private func goalForm(for state: ViceGoalEditorState) -> some View {
        Form {
            Section(state.goal == nil ? "Add Limit" : "Edit Limit") {
                Stepper(value: $draftGoalMaxOccurrences, in: 1 ... 10_000) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max occurrences")
                        Text("\(draftGoalMaxOccurrences) \(state.vice.unitLabel.lowercased())")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Deadline Mode", selection: $draftGoalDeadlineMode) {
                    Text("Custom").tag(ViceGoalDeadlineMode.custom)
                    Text("End of Day").tag(ViceGoalDeadlineMode.endOfDay)
                }
                .pickerStyle(.segmented)

                if draftGoalDeadlineMode == .custom {
                    DatePicker(
                        "Deadline",
                        selection: $draftGoalDeadline,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } else {
                    DatePicker(
                        "End of day",
                        selection: $draftGoalEndOfDayDate,
                        in: Date.now...,
                        displayedComponents: [.date]
                    )
                }
            }
        }
        .navigationTitle(state.vice.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let resolvedDeadline = resolvedGoalDeadline()
                    if viewModel.saveGoal(
                        viceID: state.vice.id,
                        maxOccurrences: draftGoalMaxOccurrences,
                        deadline: resolvedDeadline,
                        replacingGoalWithID: state.goal?.id
                    ) {
                        editingGoal = nil
                        onChange()
                    }
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    editingGoal = nil
                }
            }
        }
    }

    private func existingRoutinePicker(for vice: Vice) -> some View {
        let availableRoutines = viewModel.routines.filter { $0.kind == .standard && $0.isArchived == false }

        List {
            if availableRoutines.isEmpty {
                ContentUnavailableView(
                    "No Routines To Link",
                    systemImage: "checklist",
                    description: Text("Create a standard routine first, then link a copy here.")
                )
            } else {
                ForEach(availableRoutines) { routine in
                    Button {
                        if viewModel.linkExistingRoutine(routine.id, toViceID: vice.id) {
                            linkingRoutineVice = nil
                            homeViewModel.load()
                            onChange()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.name)
                            Text("\(routine.orderedItems.count) step\(routine.orderedItems.count == 1 ? "" : "s")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Link Routine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    linkingRoutineVice = nil
                }
            }
        }
    }

    private func resolvedGoalDeadline() -> Date {
        if draftGoalDeadlineMode == .endOfDay {
            return Calendar.current.endOfDay(for: draftGoalEndOfDayDate)
        }

        return draftGoalDeadline
    }

    private func handleViceTap(_ summary: ViceCardSummary) {
        guard let result = viewModel.attemptLogVice(viceID: summary.vice.id) else {
            return
        }

        switch result {
        case .logged:
            homeViewModel.load()
            onChange()
        case .needsRoutine(let viceID, let routineID):
            presentedRoutineSession = ViceRoutineSessionState(viceID: viceID, routineID: routineID)
        }
    }
}

private struct ViceCard: View {
    let summary: ViceCardSummary
    let now: Date
    let onTap: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onEditGoal: () -> Void
    let onCreateRoutine: () -> Void
    let onLinkRoutine: () -> Void
    let onOpenRoutine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.vice.name)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Edit", action: onEdit)
                    Button("Archive", role: .destructive, action: onArchive)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(summary.todayCount)")
                    .font(.title2.weight(.semibold))
                Text(summary.vice.unitLabel.lowercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onEditGoal) {
                    Image(systemName: summary.goalProgress == nil ? "target" : "slider.horizontal.below.square.and.square.filled")
                        .font(.footnote.weight(.semibold))
                        .padding(8)
                        .background(Color(.tertiarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(lastLogLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let recentGapSummary = summary.recentHistorySummaryText() {
                Text("Recent gaps: \(recentGapSummary)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let goalProgress = summary.goalProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goalProgress.summaryText())
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(goalColor(for: goalProgress.status))

                    ProgressView(value: goalProgress.clampedRatio, total: 1)
                        .tint(goalColor(for: goalProgress.status))
                }
            }

            if let unlockSummary = summary.unlockSummaryText(now: now) {
                Text(unlockSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if summary.linkedRoutine == nil {
                HStack(spacing: 10) {
                    Button("Make Routine", action: onCreateRoutine)
                        .buttonStyle(.borderedProminent)
                    Button("Link Routine", action: onLinkRoutine)
                        .buttonStyle(.bordered)
                }
            } else {
                Button("Open Routine", action: onOpenRoutine)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private var lastLogLabel: String {
        guard let timeSinceLastLog = summary.timeSinceLastLogText(now: now) else {
            return "No logs yet"
        }

        return "Last hit \(timeSinceLastLog) ago"
    }

    private func goalColor(for status: ViceGoalStatus) -> Color {
        switch status {
        case .onTrack:
            return .green
        case .warning:
            return .yellow
        case .exceeded:
            return .red
        }
    }
}

private struct ViceGoalEditorState: Identifiable {
    let vice: Vice
    let goal: ViceGoal?

    var id: UUID {
        vice.id
    }
}

private struct ViceRoutineEditorState: Identifiable {
    let vice: Vice
    let routine: Routine

    var id: UUID {
        vice.id
    }
}

private struct ViceRoutineSessionState: Identifiable {
    let viceID: UUID
    let routineID: UUID

    var id: String {
        "\(viceID.uuidString)-\(routineID.uuidString)"
    }
}

private enum ViceGoalDeadlineMode {
    case custom
    case endOfDay
}
