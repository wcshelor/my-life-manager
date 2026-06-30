import SwiftUI

struct RoutineModuleView: View {
    @ObservedObject var viewModel: HomeExecutionViewModel
    let taskRepository: any TaskRepository
    let projectRepository: any ProjectRepository
    let captureRepository: any CaptureRepository
    let projectItemRepository: any ProjectItemRepository
    let scheduledBlockRepository: any ScheduledBlockRepository
    let settingsRepository: any SettingsRepository
    let calendarPermissionProvider: any CalendarPermissionProviding
    let calendarListingService: any CalendarListing
    let calendarReader: any CalendarReading
    let calendarWriter: any CalendarWriting
    let calendarReconciler: any CalendarReconciling
    let calendarChangeObserver: any CalendarChangeObserving
    let promiseRepository: any PromiseRepository
    let shoppingRepository: any ShoppingRepository
    let healthRepository: any HealthRepository
    let musicPracticeRepository: any MusicPracticeRepository
    let fitnessRepository: any FitnessRepository
    let peopleMemoryRepository: any PeopleMemoryRepository
    let viceRepository: any ViceRepository
    let calendarBlockFocusRepository: any CalendarBlockFocusRepository
    let debriefRepository: any DebriefRepository
    let financeRepository: any FinanceRepository

    @State private var presentedSheet: SheetDestination?

    private enum SheetDestination: Identifiable {
        case newRoutine
        case editRoutine(Routine)
        case openRoutine(UUID)

        var id: String {
            switch self {
            case .newRoutine:
                return "newRoutine"
            case .editRoutine(let routine):
                return "editRoutine-\(routine.id.uuidString)"
            case .openRoutine(let routineID):
                return "openRoutine-\(routineID.uuidString)"
            }
        }
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section("Today") {
                HomeRoutineListWidget(
                    execution: viewModel,
                    onNewRoutine: {
                        presentedSheet = .newRoutine
                    },
                    onOpenRoutine: { routineID in
                        presentedSheet = .openRoutine(routineID)
                    }
                )
            }

            Section("All Routines") {
                if viewModel.routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines Yet",
                        systemImage: "checklist.checked",
                        description: Text("Create a routine that is always available or tied to specific weekdays.")
                    )
                } else {
                    ForEach(viewModel.routines) { routine in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                presentedSheet = .openRoutine(routine.id)
                            } label: {
                                routineRowContent(routine)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                presentedSheet = .editRoutine(routine)
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Routines")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = .newRoutine
                } label: {
                    Label("New Routine", systemImage: "plus")
                }
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .newRoutine:
                NavigationStack {
                    RoutineEditorView(routine: nil) { routine, originalID in
                        viewModel.saveRoutine(routine, replacingRoutineWithID: originalID)
                        presentedSheet = nil
                    }
                }
            case .editRoutine(let routine):
                NavigationStack {
                    RoutineEditorView(routine: routine) { updatedRoutine, originalID in
                        viewModel.saveRoutine(updatedRoutine, replacingRoutineWithID: originalID)
                        presentedSheet = nil
                    }
                }
            case .openRoutine(let routineID):
                NavigationStack {
                    RoutineSessionView(
                        viewModel: viewModel,
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
                        routineID: routineID
                    )
                }
            }
        }
    }

    private func routineRowContent(_ routine: Routine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.body.weight(.semibold))

                Text(routineSummary(for: routine))
                    .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routineSummary(for routine: Routine) -> String {
        let stepCount = routine.orderedItems.count
        let scheduleText = routine.activeWeekdays.isEmpty
            ? "Not day-based"
            : routine.activeWeekdays.map(\.shortName).joined(separator: ", ")
        let linkCount = routine.stepLinks.count
        return "\(stepCount) step\(stepCount == 1 ? "" : "s") · \(linkCount) link\(linkCount == 1 ? "" : "s") · \(scheduleText)"
    }
}

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let routine: Routine?
    let onSave: (Routine, UUID?) -> Void

    @State private var name: String
    @State private var notes: String
    @State private var selectedWeekdays: Set<RoutineWeekday>
    @State private var items: [RoutineItem]
    @State private var stepLinks: [RoutineStepLink]
    @State private var createdAt: Date
    @State private var isArchived: Bool

    init(
        routine: Routine?,
        onSave: @escaping (Routine, UUID?) -> Void
    ) {
        self.routine = routine
        self.onSave = onSave
        _name = State(initialValue: routine?.name ?? "")
        _notes = State(initialValue: routine?.notes ?? "")
        _selectedWeekdays = State(initialValue: Set(routine?.activeWeekdays ?? []))
        _items = State(initialValue: routine?.orderedItems ?? [RoutineItem(title: "", position: 0)])
        _stepLinks = State(initialValue: routine?.stepLinks ?? [])
        _createdAt = State(initialValue: routine?.createdAt ?? .now)
        _isArchived = State(initialValue: routine?.isArchived ?? false)
    }

    var body: some View {
        List {
            Section("Routine") {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Schedule") {
                Toggle("Tie to specific weekdays", isOn: scheduledByWeekdayBinding)

                if selectedWeekdays.isEmpty == false {
                    ForEach(RoutineWeekday.allCases, id: \.self) { weekday in
                        Toggle(weekday.shortName, isOn: weekdayBinding(for: weekday))
                    }
                }
            }

            Section("Steps") {
                ForEach($items) { $item in
                    TextField("Step title", text: $item.title)
                }
                .onMove(perform: moveSteps)
                .onDelete(perform: deleteSteps)

                Button {
                    addStep()
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
            }
        }
        .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    saveRoutine()
                }
                .disabled(canSave == false)
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private var canSave: Bool {
        Routine.cleanedName(from: name) != nil && cleanedItems.isEmpty == false
    }

    private var cleanedItems: [RoutineItem] {
        items.compactMap { item in
            guard let cleanedTitle = RoutineItem.cleanedTitle(from: item.title) else {
                return nil
            }

            return RoutineItem(id: item.id, title: cleanedTitle, position: item.position)
        }
    }

    private var scheduledByWeekdayBinding: Binding<Bool> {
        Binding(
            get: { selectedWeekdays.isEmpty == false },
            set: { isScheduledByWeekday in
                selectedWeekdays = isScheduledByWeekday ? Set(RoutineWeekday.allCases) : []
            }
        )
    }

    private func weekdayBinding(for weekday: RoutineWeekday) -> Binding<Bool> {
        Binding(
            get: { selectedWeekdays.contains(weekday) },
            set: { isSelected in
                if isSelected {
                    selectedWeekdays.insert(weekday)
                } else {
                    selectedWeekdays.remove(weekday)
                }
            }
        )
    }

    private func addStep() {
        items.append(RoutineItem(title: "", position: items.count))
        normalizeStepOrder()
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        normalizeStepOrder()
    }

    private func deleteSteps(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        if items.isEmpty {
            items = [RoutineItem(title: "", position: 0)]
        }
        normalizeStepOrder()
    }

    private func normalizeStepOrder() {
        items = items.enumerated().map { index, item in
            RoutineItem(id: item.id, title: item.title, position: index)
        }
    }

    private func saveRoutine() {
        guard let cleanedName = Routine.cleanedName(from: name), cleanedItems.isEmpty == false else {
            return
        }

        let updatedRoutine = Routine(
            id: routine?.id ?? UUID(),
            name: cleanedName,
            notes: MyTask.cleanedOptionalText(from: notes),
            activeWeekdays: Array(selectedWeekdays),
            items: cleanedItems.enumerated().map { index, item in
                RoutineItem(id: item.id, title: item.title, position: index)
            },
            stepLinks: stepLinks,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: .now
        )

        onSave(updatedRoutine, routine?.id)
        dismiss()
    }
}

struct RoutineSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeExecutionViewModel
    @State private var currentIndex = 0
    @State private var presentedLinkSheet: RoutineStepLinkSheet?
    @State private var pendingLinkStepID: UUID?
    @State private var isShowingLinkPicker = false
    @State private var editingRoutine = false
    @State private var editingLink: RoutineStepLink?

    let registry: HomeWidgetRegistry
    let taskRepository: any TaskRepository
    let projectRepository: any ProjectRepository
    let captureRepository: any CaptureRepository
    let projectItemRepository: any ProjectItemRepository
    let scheduledBlockRepository: any ScheduledBlockRepository
    let settingsRepository: any SettingsRepository
    let calendarPermissionProvider: any CalendarPermissionProviding
    let calendarListingService: any CalendarListing
    let calendarReader: any CalendarReading
    let calendarWriter: any CalendarWriting
    let calendarReconciler: any CalendarReconciling
    let calendarChangeObserver: any CalendarChangeObserving
    let promiseRepository: any PromiseRepository
    let shoppingRepository: any ShoppingRepository
    let healthRepository: any HealthRepository
    let musicPracticeRepository: any MusicPracticeRepository
    let fitnessRepository: any FitnessRepository
    let peopleMemoryRepository: any PeopleMemoryRepository
    let viceRepository: any ViceRepository
    let calendarBlockFocusRepository: any CalendarBlockFocusRepository
    let debriefRepository: any DebriefRepository
    let financeRepository: any FinanceRepository
    let routineID: UUID

    var body: some View {
        routineSessionContent
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        editingRoutine = true
                    }
                    .disabled(progressForCurrentRoutine == nil)
                }
            }
            .background {
                hiddenRoutineEditorLink
            }
            .sheet(item: $presentedLinkSheet) { sheet in
                NavigationStack {
                    presentedLinkSheetContent(for: sheet)
                }
            }
            .sheet(item: $editingLink) { link in
                NavigationStack {
                    routineStepLinkEditor(for: link)
                }
            }
            .confirmationDialog(
                "Add Routine Link",
                isPresented: $isShowingLinkPicker,
                titleVisibility: .visible
            ) {
                if moduleLinkDescriptors.isEmpty {
                    Button("No Available Module Links") {}
                        .disabled(true)
                } else {
                    ForEach(moduleLinkDescriptors, id: \.kind) { descriptor in
                        Button(descriptor.displayName) {
                            addModuleLink(descriptor: descriptor)
                        }
                    }
                }
            }
            .onAppear {
                alignCurrentIndex(with: progressForCurrentRoutine)
            }
            .onChange(of: progressForCurrentRoutine?.completionLog) { _, _ in
                alignCurrentIndex(with: progressForCurrentRoutine)
            }
            .onChange(of: progressForCurrentRoutine?.routine.id) { _, _ in
                alignCurrentIndex(with: progressForCurrentRoutine)
            }
    }

    @ViewBuilder
    private var routineSessionContent: some View {
        if let progress = progressForCurrentRoutine {
            activeRoutineView(for: progress)
                .navigationTitle("Routine")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            unavailableRoutineView
                .navigationTitle("Routine")
        }
    }

    private var hiddenRoutineEditorLink: some View {
        Group {
            if let progress = progressForCurrentRoutine {
                NavigationLink(
                    destination: RoutineEditorView(routine: progress.routine) { routine, originalID in
                        viewModel.saveRoutine(routine, replacingRoutineWithID: originalID)
                    },
                    isActive: $editingRoutine
                ) {
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }

    private var progressForCurrentRoutine: HomeRoutineProgress? {
        viewModel.progress(for: routineID)
    }

    private func activeRoutineView(for progress: HomeRoutineProgress) -> some View {
        let steps = progress.routine.orderedItems
        let isFinished = steps.isEmpty || currentIndex >= steps.count

        return GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 24) {
                routineHeader(progress: progress, steps: steps, isFinished: isFinished)
                Spacer(minLength: 0)
                activeRoutineStateView(progress: progress, steps: steps, isFinished: isFinished)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer(minLength: 0)
                if steps.isEmpty == false {
                    routineActionBar(
                        progress: progress,
                        steps: steps,
                        height: max(180, geometry.size.height * 0.3)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
        }
    }

    private func routineHeader(
        progress: HomeRoutineProgress,
        steps: [RoutineItem],
        isFinished: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(progress.routine.name)
                .font(.title3.weight(.semibold))

            Text(progressText(totalCount: steps.count, isFinished: isFinished))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ProgressView(
                value: Double(progress.completedCount + progress.skippedCount),
                total: Double(max(progress.totalCount, 1))
            )
        }
    }

    @ViewBuilder
    private func activeRoutineStateView(
        progress: HomeRoutineProgress,
        steps: [RoutineItem],
        isFinished: Bool
    ) -> some View {
        if isFinished {
            completedRoutineView(progress: progress)
        } else if steps.indices.contains(currentIndex) {
            let item = steps[currentIndex]
            let state = progress.completionLog?.state(for: item.id) ?? .untouched
            currentRoutineStepView(
                progress: progress,
                item: item,
                state: state
            )
        }
    }

    private func completedRoutineView(progress: HomeRoutineProgress) -> some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Routine Complete")
                .font(.title2.weight(.semibold))

            Text("Completed \(progress.completedCount) · Skipped \(progress.skippedCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func currentRoutineStepView(
        progress: HomeRoutineProgress,
        item: RoutineItem,
        state: RoutineStepCompletionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.title)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if state != .untouched {
                    Text(stateLabel(for: state))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(state == .completed ? Color.green : Color.orange)
                }
            }
            .padding(18)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            routineStepLinksSection(progress: progress, item: item)
        }
    }

    private var unavailableRoutineView: some View {
        ContentUnavailableView(
            "Routine Not Available",
            systemImage: "exclamationmark.triangle",
            description: Text("This routine is not active for the current weekday.")
        )
    }

    private func presentedLinkSheetContent(for sheet: RoutineStepLinkSheet) -> AnyView {
        switch sheet {
        case .promiseCheckIn(let promise):
            return AnyView(PromiseCheckInView(
                promise: promise,
                onResolve: { outcome, reflection in
                    viewModel.resolvePromise(
                        withID: promise.id,
                        outcome: outcome,
                        reflection: reflection
                    )
                    presentedLinkSheet = nil
                },
                onReset: { title, checkInAt in
                    viewModel.makeResetPromise(
                        from: promise,
                        title: title,
                        checkInAt: checkInAt
                    )
                    presentedLinkSheet = nil
                }
            ))
        case .promiseForm:
            return AnyView(PromiseFormView { promise in
                viewModel.savePromise(promise)
                presentedLinkSheet = nil
            })
        case .routineBuilder:
            return AnyView(RoutineEditorView(routine: nil) { routine, originalID in
                viewModel.saveRoutine(routine, replacingRoutineWithID: originalID)
                presentedLinkSheet = nil
            })
        case .openRoutine(let routineID):
            return AnyView(RoutineSessionView(
                viewModel: viewModel,
                registry: registry,
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
                routineID: routineID
            ))
        case .routineModule:
            return AnyView(
                RoutineModuleView(
                    viewModel: viewModel,
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
                    financeRepository: financeRepository
                )
            )
        case .promiseModule:
            return AnyView(PromiseModuleView(viewModel: viewModel))
        case .tasks:
            return AnyView(TaskListView(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                scheduledBlockRepository: scheduledBlockRepository,
                calendarWriter: calendarWriter,
                promiseRepository: promiseRepository
            ))
        case .planner:
            return AnyView(PlannerView(
                taskRepository: taskRepository,
                scheduledBlockRepository: scheduledBlockRepository,
                settingsRepository: settingsRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarListingService: calendarListingService,
                calendarReader: calendarReader,
                calendarWriter: calendarWriter,
                calendarReconciler: calendarReconciler,
                calendarChangeObserver: calendarChangeObserver,
                promiseRepository: promiseRepository,
                navigationTitle: "Plan the Day"
            ))
        case .projects:
            return AnyView(ProjectsView(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader,
                calendarBlockFocusRepository: calendarBlockFocusRepository,
                debriefRepository: debriefRepository
            ))
        case .shoppingList:
            return AnyView(ShoppingListView(shoppingRepository: shoppingRepository) {
                viewModel.load()
            })
        case .shoppingQuickAdd:
            return AnyView(ShoppingQuickAddSheet(shoppingRepository: shoppingRepository) {
                viewModel.load()
                presentedLinkSheet = nil
            })
        case .health:
            return AnyView(HealthView(
                healthRepository: healthRepository,
                fitnessRepository: fitnessRepository
            ) {
                viewModel.load()
            })
        case .musicPractice:
            return AnyView(MusicPracticeView(musicPracticeRepository: musicPracticeRepository) {
                viewModel.load()
            })
        case .fitness:
            return AnyView(FitnessView(fitnessRepository: fitnessRepository) {
                viewModel.load()
            })
        case .peopleMemory:
            return AnyView(PeopleMemoryView(peopleMemoryRepository: peopleMemoryRepository) {
                viewModel.load()
            })
        case .vices:
            return AnyView(VicesView(
                viceRepository: viceRepository,
                debriefRepository: debriefRepository
            ) {
                viewModel.load()
            })
        case .finance:
            return AnyView(FinanceDashboardView(financeRepository: financeRepository) {
                viewModel.load()
            })
        case .pvtTest:
            return AnyView(PVTTestView { session in
                do {
                    try healthRepository.savePVTSession(session)
                    viewModel.load()
                    presentedLinkSheet = nil
                } catch {
                    viewModel.reportError("Unable to save PVT session: \(error.localizedDescription)")
                }
            })
        case .unavailable(let title, let message):
            return AnyView(RoutineLinkUnavailableView(title: title, message: message))
        }
    }

    @ViewBuilder
    private func routineStepLinksSection(
        progress: HomeRoutineProgress,
        item: RoutineItem
    ) -> some View {
        let links = progress.routine.orderedStepLinks(for: item.id)

        VStack(alignment: .leading, spacing: 10) {
            Text("Routine Links")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if links.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        pendingLinkStepID = item.id
                        isShowingLinkPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .padding(10)
                            .background(.quaternary.opacity(0.4), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(links) { link in
                        RoutineStepLinkCard(
                            link: link,
                            iconSystemName: descriptor(for: link)?.iconSystemName,
                            quickActions: quickActions(for: link),
                            onOpen: { open(link: link) },
                            onQuickActionTap: { action in
                                performQuickAction(action, for: link)
                            },
                            onEditQuickActions: link.kind == .moduleWidget ? {
                                editingLink = link
                            } : nil,
                            onRemove: { remove(linkID: link.id, from: progress.routine) }
                        )
                    }

                    Button {
                        pendingLinkStepID = item.id
                        isShowingLinkPicker = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var moduleLinkDescriptors: [HomeWidgetDescriptor] {
        registry.availableRoutineModuleLinkDescriptors
    }

    private func quickActions(for link: RoutineStepLink) -> [WidgetQuickAction] {
        guard let descriptor = descriptor(for: link) else {
            return []
        }

        return HomeWidgetQuickActionResolver.resolvedQuickActions(
            selectedQuickActionIDs: link.selectedQuickActionIDs,
            descriptor: descriptor,
            definition: registry.definition(for: descriptor.module)
        )
    }

    private func progressText(totalCount: Int, isFinished: Bool) -> String {
        guard totalCount > 0 else {
            return "0 / 0"
        }

        let position = isFinished ? totalCount : min(currentIndex + 1, totalCount)
        return "\(position) / \(totalCount)"
    }

    private func stateLabel(for state: RoutineStepCompletionState) -> String {
        switch state {
        case .untouched:
            return ""
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        }
    }

    private func isLastStep(totalCount: Int) -> Bool {
        currentIndex == totalCount - 1
    }

    private func routineActionBar(
        progress: HomeRoutineProgress,
        steps: [RoutineItem],
        height: CGFloat
    ) -> some View {
        let currentItem = steps.indices.contains(currentIndex) ? steps[currentIndex] : nil

        return VStack {
            Spacer(minLength: 0)
            HStack(spacing: 18) {
                Button {
                    viewModel.undoLastRoutineAction(routineID: routineID)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Undo")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 84)
                    .foregroundStyle(progress.lastTouchedItem == nil ? Color.secondary : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .disabled(progress.lastTouchedItem == nil)

                Button {
                    guard let currentItem else {
                        return
                    }
                    advance(stepID: currentItem.id, state: .skipped, totalCount: steps.count)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 84)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
                .disabled(currentItem == nil)

                Button {
                    guard let currentItem else {
                        return
                    }
                    advance(stepID: currentItem.id, state: .completed, totalCount: steps.count)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 84)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.green)
                        )
                }
                .buttonStyle(.plain)
                .disabled(currentItem == nil)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: height, alignment: .bottom)
    }

    private func advance(stepID: UUID, state: RoutineStepCompletionState, totalCount: Int) {
        let shouldDismiss = isLastStep(totalCount: totalCount)
        viewModel.setRoutineItem(routineID: routineID, itemID: stepID, state: state)
        if shouldDismiss {
            dismiss()
        } else {
            currentIndex = min(currentIndex + 1, totalCount)
        }
    }

    private func alignCurrentIndex(with progress: HomeRoutineProgress?) {
        guard let progress else {
            currentIndex = 0
            return
        }

        let steps = progress.routine.orderedItems
        guard steps.isEmpty == false else {
            currentIndex = 0
            return
        }

        if let firstUntouchedIndex = steps.firstIndex(where: {
            (progress.completionLog?.state(for: $0.id) ?? .untouched) == .untouched
        }) {
            currentIndex = firstUntouchedIndex
        } else {
            currentIndex = steps.count
        }
    }

    private func addModuleLink(descriptor: HomeWidgetDescriptor) {
        guard let progress = progressForCurrentRoutine,
              let stepID = pendingLinkStepID else {
            return
        }

        let nextOrder = progress.routine.orderedStepLinks(for: stepID).count
        var updatedRoutine = progress.routine
        updatedRoutine.stepLinks.append(
            RoutineStepLink(
                routineStepID: stepID,
                kind: .moduleWidget,
                moduleWidgetKind: descriptor.kind,
                displayTitle: descriptor.displayName,
                displayOrder: nextOrder
            )
        )
        viewModel.saveRoutine(updatedRoutine, replacingRoutineWithID: updatedRoutine.id)
    }

    private func remove(linkID: UUID, from routine: Routine) {
        var updatedRoutine = routine
        updatedRoutine.stepLinks.removeAll { $0.id == linkID }
        updatedRoutine.stepLinks = reindexedLinks(for: updatedRoutine)
        viewModel.saveRoutine(updatedRoutine, replacingRoutineWithID: updatedRoutine.id)
    }

    private func reindexedLinks(for routine: Routine) -> [RoutineStepLink] {
        routine.orderedItems.flatMap { item in
            routine.orderedStepLinks(for: item.id).enumerated().map { index, link in
                RoutineStepLink(
                    id: link.id,
                    routineStepID: link.routineStepID,
                    kind: link.kind,
                    moduleWidgetKind: link.moduleWidgetKind,
                    displayTitle: link.displayTitle,
                    displayOrder: index,
                    selectedQuickActionIDs: link.selectedQuickActionIDs
                )
            }
        }
    }

    private func open(link: RoutineStepLink) {
        switch link.kind {
        case .pvtTest:
            presentedLinkSheet = .pvtTest
        case .promiseCheckIn:
            if let promise = viewModel.duePromises.first ?? viewModel.activePromises.first {
                presentedLinkSheet = .promiseCheckIn(promise)
            } else {
                presentedLinkSheet = .unavailable(
                    title: "No Active Promises",
                    message: "Create or start a promise first, then reopen this link from the routine step."
                )
            }
        case .moduleWidget:
            guard let descriptor = descriptor(for: link),
                  descriptor.isAvailable,
                  descriptor.isModuleWidget,
                  let landingTarget = descriptor.module.landingTarget else {
                presentedLinkSheet = .unavailable(
                    title: "Module Link Unavailable",
                    message: "This module link is no longer available in this version of the app."
                )
                return
            }

            presentedLinkSheet = sheet(for: landingTarget)
        }
    }

    private func performQuickAction(_ action: WidgetQuickAction, for link: RoutineStepLink) {
        guard let descriptor = descriptor(for: link),
              let definition = registry.definition(for: descriptor.module) else {
            return
        }

        switch action.behavior {
        case .command(let command):
            performQuickActionCommand(command)
        case .navigation:
            switch action.id {
            case "addTask":
                presentedLinkSheet = .tasks
            case "today":
                presentedLinkSheet = .planner
            case "capture":
                presentedLinkSheet = .unavailable(
                    title: "Capture Not Available",
                    message: "Use the Home capture overlay for quick capture."
                )
            case "overdue":
                presentedLinkSheet = .tasks
            case "openProjects", "pinnedProjects", "projectFocus", "projectInbox":
                presentedLinkSheet = .projects
            case "newPromise":
                presentedLinkSheet = .promiseForm
            case "checkInDue":
                if let promise = viewModel.duePromises.first {
                    presentedLinkSheet = .promiseCheckIn(promise)
                } else {
                    presentedLinkSheet = .promiseForm
                }
            case "activePromises":
                presentedLinkSheet = .promiseForm
        case "newRoutine":
                presentedLinkSheet = .routineBuilder
            case "todayRoutines", "currentStep":
                if let routineID = viewModel.routineProgress.first?.routine.id {
                    presentedLinkSheet = .openRoutine(routineID)
                } else {
                    presentedLinkSheet = .routineBuilder
                }
            case "openShopping", "neededItems":
                presentedLinkSheet = .shoppingList
            case "quickAddShopping":
                presentedLinkSheet = .shoppingQuickAdd
            case "openPlanner", "planToday", "reviewSchedule", "createScheduledBlock":
                presentedLinkSheet = .planner
            case "openHealth", "logMeal", "logSleep", "healthHistory":
                presentedLinkSheet = .health
            case "activeSession", "history":
                presentedLinkSheet = .vices
            case "debrief":
                presentedLinkSheet = .unavailable(
                    title: "Debriefs Not Available",
                    message: "Open Debriefs from Home to review queue items."
                )
            case "startPractice", "currentPiece", "addPracticeNote", "regimen":
                presentedLinkSheet = .musicPractice
            case "openFitness", "logWorkout", "recentWorkouts", "workoutDays":
                presentedLinkSheet = .fitness
            case "openPeopleMemory", "addPerson", "studyNow", "reviewDue":
                presentedLinkSheet = .peopleMemory
            case "addExpense", "budget", "subscriptions":
                presentedLinkSheet = .finance
            default:
                switch definition.mainDestination {
                case .openTasks:
                    presentedLinkSheet = .tasks
                case .openPlanner:
                    presentedLinkSheet = .planner
                case .openProjects:
                    presentedLinkSheet = .projects
                case .newPromise:
                    presentedLinkSheet = .promiseForm
                case .newRoutine:
                    presentedLinkSheet = .routineBuilder
                case .openShopping:
                    presentedLinkSheet = .shoppingList
                case .openHealth:
                    presentedLinkSheet = .health
                case .openMusicPractice:
                    presentedLinkSheet = .musicPractice
                case .openFitness:
                    presentedLinkSheet = .fitness
                case .openPeopleMemory:
                    presentedLinkSheet = .peopleMemory
                case .openVices:
                    presentedLinkSheet = .vices
                case .openFinance:
                    presentedLinkSheet = .finance
                default:
                    break
                }
            }
        }
    }

    private func performQuickActionCommand(_ command: HomeWidgetQuickActionCommand) {
        switch command {
        case .repeatMostRecentViceLog:
            _ = viewModel.repeatMostRecentViceLog()
        }
    }

    private func sheet(for landingTarget: HomeModuleLandingTarget) -> RoutineStepLinkSheet {
        switch landingTarget {
        case .tasks:
            return .tasks
        case .planner:
            return .planner
        case .projects:
            return .projects
        case .promises:
            return .promiseModule
        case .routines:
            return .routineModule
        case .shopping:
            return .shoppingList
        case .health:
            return .health
        case .musicPractice:
            return .musicPractice
        case .fitness:
            return .fitness
        case .peopleMemory:
            return .peopleMemory
        case .vices:
            return .vices
        case .finance:
            return .finance
        }
    }

    private func descriptor(for link: RoutineStepLink) -> HomeWidgetDescriptor? {
        guard link.kind == .moduleWidget,
              let widgetKind = link.moduleWidgetKind else {
            return nil
        }

        return registry.descriptor(for: widgetKind)
    }

    @ViewBuilder
    private func routineStepLinkEditor(for link: RoutineStepLink) -> some View {
        if let descriptor = descriptor(for: link),
           let definition = registry.definition(for: descriptor.module) {
            HomeWidgetQuickActionSelectionView(
                title: descriptor.displayName,
                subtitle: "Choose this step's quick buttons independently from the Home widget configuration.",
                availableQuickActions: definition.availableQuickActions,
                selectedQuickActionIDs: link.selectedQuickActionIDs
            ) { selectedIDs in
                updateQuickActionSelection(selectedIDs, for: link)
            }
        } else {
            ContentUnavailableView(
                "No Quick Actions",
                systemImage: "slider.horizontal.3",
                description: Text("This routine link does not expose configurable buttons.")
            )
            .navigationTitle("Edit Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingLink = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        editingLink = nil
                    }
                }
            }
        }
    }

    private func updateQuickActionSelection(_ selectedIDs: [String], for link: RoutineStepLink) {
        guard let progress = progressForCurrentRoutine else {
            return
        }

        var updatedRoutine = progress.routine
        guard let linkIndex = updatedRoutine.stepLinks.firstIndex(where: { $0.id == link.id }) else {
            return
        }

        updatedRoutine.stepLinks[linkIndex].selectedQuickActionIDs = HomeWidgetQuickActionResolver.normalizedQuickActionIDs(selectedIDs)
        viewModel.saveRoutine(updatedRoutine, replacingRoutineWithID: updatedRoutine.id)
        editingLink = nil
    }
}

private enum RoutineStepLinkSheet: Identifiable {
    case promiseCheckIn(Promise)
    case pvtTest
    case promiseForm
    case routineBuilder
    case openRoutine(UUID)
    case routineModule
    case promiseModule
    case tasks
    case planner
    case projects
    case shoppingList
    case shoppingQuickAdd
    case health
    case musicPractice
    case fitness
    case peopleMemory
    case vices
    case finance
    case unavailable(title: String, message: String)

    var id: String {
        switch self {
        case .promiseCheckIn(let promise):
            return "promise-\(promise.id.uuidString)"
        case .pvtTest:
            return "pvt-test"
        case .promiseForm:
            return "promise-form"
        case .routineBuilder:
            return "routine-builder"
        case .openRoutine(let routineID):
            return "open-routine-\(routineID.uuidString)"
        case .routineModule:
            return "routine-module"
        case .promiseModule:
            return "promise-module"
        case .tasks:
            return "tasks"
        case .planner:
            return "planner"
        case .projects:
            return "projects"
        case .shoppingList:
            return "shopping-list"
        case .shoppingQuickAdd:
            return "shopping-quick-add"
        case .health:
            return "health"
        case .musicPractice:
            return "music-practice"
        case .fitness:
            return "fitness"
        case .peopleMemory:
            return "people-memory"
        case .vices:
            return "vices"
        case .finance:
            return "finance"
        case .unavailable(let title, _):
            return "unavailable-\(title)"
        }
    }
}

private struct RoutineStepLinkCard: View {
    let link: RoutineStepLink
    let iconSystemName: String?
    let quickActions: [WidgetQuickAction]
    let onOpen: () -> Void
    let onQuickActionTap: (WidgetQuickAction) -> Void
    let onEditQuickActions: (() -> Void)?
    let onRemove: () -> Void

    var body: some View {
        if link.kind == .moduleWidget {
            ZStack(alignment: .topTrailing) {
                HomeModuleWidgetCard(
                    title: link.displayTitle,
                    systemImage: iconSystemName ?? "square.grid.2x2",
                    detail: nil,
                    quickActions: quickActions,
                    isEditing: false,
                    primaryAction: onOpen,
                    onQuickActionTap: onQuickActionTap
                )

                HStack(spacing: 6) {
                    if let onEditQuickActions {
                        Button {
                            onEditQuickActions()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption.weight(.bold))
                                .padding(7)
                        }
                        .buttonStyle(.plain)
                        .background(.thinMaterial, in: Circle())
                    }

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .padding(7)
                    }
                    .buttonStyle(.plain)
                    .background(.thinMaterial, in: Circle())
                }
                .padding(8)
            }
        } else {
            HStack(spacing: 8) {
                Button {
                    onOpen()
                } label: {
                    HStack(spacing: 8) {
                        if let iconSystemName {
                            Image(systemName: iconSystemName)
                                .foregroundStyle(.secondary)
                        }

                        Text(link.displayTitle)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

private struct RoutineLinkUnavailableView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "rectangle.on.rectangle.slash",
            description: Text(message)
        )
        .navigationTitle("Routine Link")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
