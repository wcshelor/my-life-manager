import Combine
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum SheetDestination: Identifiable {
        case addWidget
        case customizeHome
        case inboxReview
        case promiseForm
        case promiseCheckIn(Promise)
        case routineBuilder
        case routineSession(UUID)
        case shoppingList
        case shoppingQuickAdd
        case health
        case musicPractice
        case fitness
        case peopleMemory
        case vices
        case debriefs
        case finance

        var id: String {
            switch self {
            case .addWidget:
                return "addWidget"
            case .customizeHome:
                return "customizeHome"
            case .inboxReview:
                return "inboxReview"
            case .promiseForm:
                return "promiseForm"
            case .promiseCheckIn(let promise):
                return "promiseCheckIn-\(promise.id.uuidString)"
            case .routineBuilder:
                return "routineBuilder"
            case .routineSession(let routineID):
                return "routineSession-\(routineID.uuidString)"
            case .shoppingList:
                return "shoppingList"
            case .shoppingQuickAdd:
                return "shoppingQuickAdd"
            case .health:
                return "health"
            case .musicPractice:
                return "musicPractice"
            case .fitness:
                return "fitness"
            case .peopleMemory:
                return "peopleMemory"
            case .vices:
                return "vices"
            case .debriefs:
                return "debriefs"
            case .finance:
                return "finance"
            }
        }
    }

    private enum NavigationDestination: Hashable {
        case tasks
        case planner
        case projects
        case project(UUID)
    }

    fileprivate struct PreviewDropTarget: Equatable {
        let widgetID: UUID
        let placement: HomeLayoutViewModel.WidgetDropPlacement
    }

    @StateObject private var viewModel: HomeExecutionViewModel
    @StateObject private var homeViewModel: HomeLayoutViewModel
    @State private var presentedSheet: SheetDestination?
    @State private var isShowingCaptureOverlay = false
    @State private var navigationPath: [NavigationDestination] = []
    @State private var isEditingHome = false
    @State private var draggingWidgetID: UUID?
    @State private var previewDropTarget: PreviewDropTarget?
    @State private var editingWidget: HomeWidgetInstance?
    @State private var homeActionFeedback: HomeActionFeedback?
    @State private var homeActionFeedbackDismissTask: Task<Void, Never>?
    private let widgetRendererRegistry = HomeWidgetRendererRegistry.standard

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let scheduledBlockRepository: any ScheduledBlockRepository
    private let settingsRepository: any SettingsRepository
    private let homeLayoutRepository: any HomeLayoutRepository
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
    private let appUpdateReminderTracker: any AppUpdateReminderTracking

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        scheduledBlockRepository: any ScheduledBlockRepository,
        settingsRepository: any SettingsRepository,
        homeLayoutRepository: any HomeLayoutRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendarWriter: any CalendarWriting,
        calendarReconciler: any CalendarReconciling,
        calendarChangeObserver: any CalendarChangeObserving,
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository,
        shoppingRepository: any ShoppingRepository,
        healthRepository: any HealthRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        fitnessRepository: any FitnessRepository,
        peopleMemoryRepository: any PeopleMemoryRepository,
        viceRepository: any ViceRepository,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        debriefRepository: any DebriefRepository,
        financeRepository: any FinanceRepository,
        appUpdateReminderTracker: any AppUpdateReminderTracking = LiveAppUpdateReminderTracker()
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.scheduledBlockRepository = scheduledBlockRepository
        self.settingsRepository = settingsRepository
        self.homeLayoutRepository = homeLayoutRepository
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
        self.appUpdateReminderTracker = appUpdateReminderTracker
        _viewModel = StateObject(
            wrappedValue: HomeExecutionViewModel(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                promiseRepository: promiseRepository,
                routineRepository: routineRepository,
                shoppingRepository: shoppingRepository,
                healthRepository: healthRepository,
                musicPracticeRepository: musicPracticeRepository,
                fitnessRepository: fitnessRepository,
                peopleMemoryRepository: peopleMemoryRepository,
                viceRepository: viceRepository,
                calendarBlockFocusRepository: calendarBlockFocusRepository,
                debriefRepository: debriefRepository,
                financeRepository: financeRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader,
                appUpdateReminderTracker: appUpdateReminderTracker
            )
        )
        _homeViewModel = StateObject(
            wrappedValue: HomeLayoutViewModel(
                homeLayoutRepository: homeLayoutRepository,
                settingsRepository: settingsRepository
            )
        )
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topTrailing) {
                homeBoard
                    .disabled(isShowingCaptureOverlay)

                if isShowingCaptureOverlay {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissCaptureOverlay()
                        }
                        .transition(.opacity)

                    captureOverlay
                        .padding(.top, 10)
                        .padding(.trailing, 16)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.94, anchor: .topTrailing)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: 18, y: -18)),
                                removal: .scale(scale: 0.96, anchor: .topTrailing)
                                    .combined(with: .opacity)
                            )
                        )
                }
            }
            .overlay(alignment: .bottom) {
                homeActionFeedbackOverlay
            }
            .onDisappear {
                cancelHomeActionFeedback()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditingHome ? "Done" : "Edit") {
                        isEditingHome.toggle()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditingHome {
                        Button {
                            presentedSheet = .customizeHome
                        } label: {
                            Label("Customize", systemImage: "slider.horizontal.3")
                        }
                    }

                    Button {
                        presentCaptureOverlay()
                    } label: {
                        Label("Capture", systemImage: "tray.and.arrow.down")
                    }

                    Button {
                        presentedSheet = .routineBuilder
                    } label: {
                        Label("New Routine", systemImage: "list.bullet.clipboard")
                    }

                    Button {
                        presentedSheet = .promiseForm
                    } label: {
                        Label("New Promise", systemImage: "hand.raised.fill")
                    }
                }
            }
            .sheet(item: $presentedSheet) { destination in
                NavigationStack {
                    presentedSheetContent(for: destination)
                }
            }
            .sheet(item: $editingWidget) { widget in
                NavigationStack {
                    if let definition = widgetDefinition(for: widget) {
                        HomeWidgetQuickActionSelectionView(
                            title: "Edit Widget",
                            subtitle: definition.title,
                            availableQuickActions: definition.availableQuickActions,
                            selectedQuickActionIDs: HomeWidgetQuickActionResolver.resolvedQuickActionIDs(
                                selectedQuickActionIDs: widget.configuration.selectedQuickActionIDs,
                                definition: definition
                            )
                        ) { selectedIDs in
                            updateQuickActionSelection(selectedIDs, widgetID: widget.id)
                        }
                    } else {
                        ContentUnavailableView("No Quick Actions", systemImage: "slider.horizontal.3")
                            .navigationTitle("Edit Widget")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        editingWidget = nil
                                    }
                                }
                            }
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                navigationDestinationView(for: destination)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                viewModel.handleSceneDidBecomeActive()
                homeViewModel.load()
            }
            .task {
                viewModel.loadIfNeeded()
                homeViewModel.load()
            }
        }
    }

    private var plannerDestination: AnyView {
        AnyView(PlannerView(
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
    }

    private func presentedSheetContent(for destination: SheetDestination) -> AnyView {
        switch destination {
        case .addWidget:
            return AnyView(AddHomeWidgetView(
                viewModel: homeViewModel,
                projects: viewModel.projects,
                routines: viewModel.routines
            ) {
                presentedSheet = nil
            })
        case .customizeHome:
            return AnyView(HomeCustomizationView(viewModel: homeViewModel) {
                presentedSheet = nil
            })
        case .inboxReview:
            return AnyView(InboxReviewView(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                shoppingRepository: shoppingRepository,
                musicPracticeRepository: musicPracticeRepository,
                initialCaptures: viewModel.captures,
                initialProjects: viewModel.projects,
                onInboxChanged: {
                    viewModel.load()
                }
            ) {
                viewModel.load()
            })
        case .promiseForm:
            return AnyView(PromiseFormView { promise in
                viewModel.savePromise(promise)
                presentedSheet = nil
            })
        case .promiseCheckIn(let promise):
            return AnyView(PromiseCheckInView(
                promise: promise,
                onResolve: { outcome, reflection in
                    viewModel.resolvePromise(
                        withID: promise.id,
                        outcome: outcome,
                        reflection: reflection
                    )
                    presentedSheet = nil
                },
                onReset: { title, checkInAt in
                    viewModel.makeResetPromise(
                        from: promise,
                        title: title,
                        checkInAt: checkInAt
                    )
                    presentedSheet = nil
                }
            ))
        case .routineBuilder:
            return AnyView(RoutineEditorView(routine: nil) { routine, originalID in
                viewModel.saveRoutine(routine, replacingRoutineWithID: originalID)
                presentedSheet = nil
            })
        case .routineSession(let routineID):
            return AnyView(RoutineSessionView(
                viewModel: viewModel,
                registry: homeViewModel.registry,
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
        case .shoppingList:
            return AnyView(ShoppingListView(shoppingRepository: shoppingRepository) {
                viewModel.load()
            })
        case .shoppingQuickAdd:
            return AnyView(ShoppingQuickAddSheet(shoppingRepository: shoppingRepository) {
                viewModel.load()
                presentedSheet = nil
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
        case .debriefs:
            return AnyView(DebriefListView(
                debriefRepository: debriefRepository,
                captureRepository: captureRepository,
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                calendarBlockFocusRepository: calendarBlockFocusRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader
            ) {
                viewModel.load()
            })
        case .finance:
            return AnyView(FinanceDashboardView(financeRepository: financeRepository) {
                viewModel.load()
            })
        }
    }

    private func navigationDestinationView(for destination: NavigationDestination) -> AnyView {
        switch destination {
        case .tasks:
            return AnyView(TaskListView(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                scheduledBlockRepository: scheduledBlockRepository,
                calendarWriter: calendarWriter,
                promiseRepository: promiseRepository
            ))
        case .planner:
            return plannerDestination
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
        case .project(let projectID):
            return AnyView(ProjectDetailView(
                projectID: projectID,
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader,
                calendarBlockFocusRepository: calendarBlockFocusRepository,
                debriefRepository: debriefRepository
            ))
        }
    }

    private var homeBoard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompactWidth ? 18 : 22) {
                welcomeBanner

                errorMessages

                if homeViewModel.widgets.isEmpty {
                    emptyHomeLayout
                } else {
                    ForEach(homeViewModel.widgets) { widget in
                        homeWidgetChrome(for: widget) {
                            widgetRendererRegistry.render(
                                widget: widget,
                                context: widgetRenderContext
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        presentedSheet = isEditingHome ? .customizeHome : .addWidget
                    } label: {
                        Label(isEditingHome ? "Customize Home" : "Add Widget", systemImage: isEditingHome ? "slider.horizontal.3" : "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    if isEditingHome {
                        Button {
                            clearWidgetDragPreview()
                            homeViewModel.resetToDefaultLayout()
                            isEditingHome = false
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(isCompactWidth ? 16 : 20)
        }
        .onChange(of: isEditingHome) { _, isEditing in
            if isEditing == false {
                clearWidgetDragPreview()
            }
        }
        .onChange(of: homeViewModel.widgets.map(\.id)) { _, widgetIDs in
            if let draggingWidgetID, widgetIDs.contains(draggingWidgetID) == false {
                clearWidgetDragPreview()
                return
            }

            if let previewDropTarget, widgetIDs.contains(previewDropTarget.widgetID) == false {
                clearWidgetDragPreview()
            }
        }
    }

    @ViewBuilder
    private var errorMessages: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }

        if let errorMessage = homeViewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var emptyHomeLayout: some View {
        ContentUnavailableView(
            "Home Is Empty",
            systemImage: "square.grid.2x2",
            description: Text("Add widgets or reset to the default layout.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func homeWidgetChrome<Content: View>(
        for widget: HomeWidgetInstance,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            insertionIndicator(
                isVisible: previewDropTarget?.widgetID == widget.id && previewDropTarget?.placement == .before
            )

            VStack(alignment: .leading, spacing: 8) {
                if isEditingHome {
                    HStack(spacing: 8) {
                        Label(
                            homeViewModel.descriptor(for: widget)?.displayName ?? widget.kind.rawValue,
                            systemImage: homeViewModel.descriptor(for: widget)?.iconSystemName ?? "square.grid.2x2"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        Spacer()

                        if let alternateSize = homeViewModel.alternateSize(for: widget) {
                            Button {
                                homeViewModel.resizeWidget(withID: widget.id, to: alternateSize)
                            } label: {
                                Image(systemName: alternateSize == .large ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(role: .destructive) {
                            clearWidgetDragPreview()
                            homeViewModel.removeWidget(withID: widget.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            editingWidget = widget
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Group {
                    if isEditingHome {
                        ZStack {
                            content()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .allowsHitTesting(false)

                            Color.clear
                                .contentShape(Rectangle())
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingWidget = widget
                        }
                        .onDrag {
                            draggingWidgetID = widget.id
                            previewDropTarget = nil
                            return NSItemProvider(object: widget.id.uuidString as NSString)
                        }
                    } else {
                        content()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard isEditingHome == false else {
                        return
                    }
                    isEditingHome = true
                }
                .accessibilityElement(children: .contain)
            }
            .padding(isEditingHome ? 10 : 14)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEditingHome ? 0.12 : 0.08), lineWidth: 1)
            }
            .overlay {
                if isEditingHome {
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .allowsHitTesting(draggingWidgetID != nil)
                            .onDrop(
                                of: [UTType.text],
                                delegate: HomeWidgetDropDelegate(
                                    targetWidgetID: widget.id,
                                    targetHeight: geometry.size.height,
                                    draggingWidgetID: $draggingWidgetID,
                                    previewDropTarget: $previewDropTarget,
                                    viewModel: homeViewModel,
                                    clearPreview: clearWidgetDragPreview
                                )
                            )
                    }
                }
            }
            .opacity(draggingWidgetID == widget.id ? 0.72 : 1)
            .scaleEffect(draggingWidgetID == widget.id ? 0.985 : 1)
            .shadow(
                color: Color.black.opacity(draggingWidgetID == widget.id ? 0.12 : 0.03),
                radius: draggingWidgetID == widget.id ? 20 : 12,
                y: draggingWidgetID == widget.id ? 8 : 3
            )

            insertionIndicator(
                isVisible: previewDropTarget?.widgetID == widget.id && previewDropTarget?.placement == .after
            )
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: previewDropTarget)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: draggingWidgetID)
    }

    private func insertionIndicator(isVisible: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: isVisible ? 8 : 0)

            Capsule()
                .fill(Color.accentColor.opacity(isVisible ? 0.9 : 0))
                .frame(maxWidth: .infinity)
                .frame(height: isVisible ? 4 : 0)
                .padding(.horizontal, 18)

            Spacer()
                .frame(height: isVisible ? 8 : 0)
        }
        .accessibilityHidden(true)
    }

    private func clearWidgetDragPreview() {
        draggingWidgetID = nil
        previewDropTarget = nil
    }

    private func widgetDefinition(for widget: HomeWidgetInstance) -> HomeWidgetDefinition? {
        homeViewModel.descriptor(for: widget).flatMap {
            homeViewModel.registry.definition(for: $0.module)
        }
    }

    private func performQuickAction(_ action: WidgetQuickAction, for widget: HomeWidgetInstance) {
        guard isEditingHome == false else {
            return
        }

        switch action.behavior {
        case .command(let command):
            performQuickActionCommand(command)
        case .navigation:
            guard let definition = widgetDefinition(for: widget) else {
                return
            }

            switch action.id {
            case "addTask":
                presentedSheet = .inboxReview
            case "today":
                navigationPath.append(.planner)
            case "capture":
                presentCaptureOverlay()
            case "overdue":
                navigationPath.append(.tasks)
            case "openProjects", "pinnedProjects", "projectFocus", "projectInbox":
                navigationPath.append(.projects)
            case "newPromise":
                presentedSheet = .promiseForm
            case "checkInDue":
                if let promise = viewModel.duePromises.first {
                    presentedSheet = .promiseCheckIn(promise)
                } else {
                    presentedSheet = .promiseForm
                }
            case "activePromises":
                presentedSheet = .promiseForm
            case "newRoutine":
                presentedSheet = .routineBuilder
            case "todayRoutines":
                if let routineID = viewModel.routineProgress.first?.routine.id {
                    presentedSheet = .routineSession(routineID)
                } else {
                    presentedSheet = .routineBuilder
                }
            case "currentStep":
                if let routineID = viewModel.routineProgress.first?.routine.id {
                    presentedSheet = .routineSession(routineID)
                } else {
                    presentedSheet = .routineBuilder
                }
            case "openShopping", "neededItems":
                presentedSheet = .shoppingList
            case "quickAddShopping":
                presentedSheet = .shoppingQuickAdd
            case "openPlanner", "planToday", "reviewSchedule", "createScheduledBlock":
                navigationPath.append(.planner)
            case "openHealth", "logMeal", "logSleep", "healthHistory":
                presentedSheet = .health
            case "activeSession", "history":
                presentedSheet = .vices
            case "debrief":
                presentedSheet = .debriefs
            case "startPractice", "currentPiece", "addPracticeNote", "regimen":
                presentedSheet = .musicPractice
            case "openFitness", "logWorkout", "recentWorkouts", "workoutDays":
                presentedSheet = .fitness
            case "openPeopleMemory", "addPerson", "studyNow", "reviewDue":
                presentedSheet = .peopleMemory
            case "addExpense", "budget", "subscriptions":
                presentedSheet = .finance
            default:
                switch definition.mainDestination {
                case .openTasks:
                    navigationPath.append(.tasks)
                case .openPlanner:
                    navigationPath.append(.planner)
                case .openProjects:
                    navigationPath.append(.projects)
                case .newPromise:
                    presentedSheet = .promiseForm
                case .newRoutine:
                    presentedSheet = .routineBuilder
                case .openShopping:
                    presentedSheet = .shoppingList
                case .openHealth:
                    presentedSheet = .health
                case .openMusicPractice:
                    presentedSheet = .musicPractice
                case .openFitness:
                    presentedSheet = .fitness
                case .openPeopleMemory:
                    presentedSheet = .peopleMemory
                case .openVices:
                    presentedSheet = .vices
                case .openFinance:
                    presentedSheet = .finance
                default:
                    break
                }
            }
        }
    }

    private func performQuickActionCommand(_ command: HomeWidgetQuickActionCommand) {
        switch command {
        case .repeatMostRecentViceLog:
            showHomeActionFeedback(viewModel.repeatMostRecentViceLog())
        }
    }

    private func updateQuickActionSelection(_ selectedIDs: [String], widgetID: UUID) {
        guard let widget = homeViewModel.widgets.first(where: { $0.id == widgetID }) else {
            return
        }

        var updated = widget
        updated.configuration.selectedQuickActionIDs = HomeWidgetQuickActionResolver.normalizedQuickActionIDs(selectedIDs)
        homeViewModel.updateWidgetConfiguration(updated)
        editingWidget = updated
    }

    private var widgetRenderContext: HomeWidgetRenderContext {
        HomeWidgetRenderContext(
            execution: viewModel,
            isEditing: isEditingHome,
            descriptor: { kind in
                homeViewModel.registry.descriptor(for: kind)
            },
            definition: { module in
                homeViewModel.registry.definition(for: module)
            },
            perform: { action, widget in
                performWidgetAction(action, for: widget)
            },
            performQuickAction: { action, widget in
                performQuickAction(action, for: widget)
            },
            openProject: { projectID in
                navigationPath.append(.project(projectID))
            },
            openRoutine: { routineID in
                presentedSheet = .routineSession(routineID)
            },
            checkInPromise: { promise in
                presentedSheet = .promiseCheckIn(promise)
            },
            openShopping: {
                presentedSheet = .shoppingList
            },
            openHealth: {
                presentedSheet = .health
            },
            openMusicPractice: {
                presentedSheet = .musicPractice
            },
            openFitness: {
                presentedSheet = .fitness
            },
            openPeopleMemory: {
                presentedSheet = .peopleMemory
            },
            openVices: {
                presentedSheet = .vices
            },
            openFinance: {
                presentedSheet = .finance
            }
        )
    }

    private func performWidgetAction(
        _ action: HomeWidgetDefaultAction,
        for widget: HomeWidgetInstance
    ) {
        guard isEditingHome == false else {
            return
        }
        switch action {
        case .openCapture:
            presentCaptureOverlay()
        case .reviewInbox:
            if viewModel.inboxSummary.count > 0 {
                presentedSheet = .inboxReview
            } else {
                presentCaptureOverlay()
            }
        case .openTasks:
            navigationPath.append(.tasks)
        case .openPlanner:
            navigationPath.append(.planner)
        case .openProjects:
            navigationPath.append(.projects)
        case .openConfiguredProject:
            if let projectID = widget.configuration.projectID {
                navigationPath.append(.project(projectID))
            }
        case .newPromise:
            presentedSheet = .promiseForm
        case .checkInDuePromise:
            if let promise = viewModel.duePromises.first {
                presentedSheet = .promiseCheckIn(promise)
            } else {
                presentedSheet = .promiseForm
            }
        case .newRoutine:
            presentedSheet = .routineBuilder
        case .openConfiguredRoutine:
            if let routineID = widget.configuration.routineID {
                presentedSheet = .routineSession(routineID)
            }
        case .openShopping:
            presentedSheet = .shoppingList
        case .quickAddShopping:
            presentedSheet = .shoppingQuickAdd
        case .openHealth:
            presentedSheet = .health
        case .openMusicPractice:
            presentedSheet = .musicPractice
        case .openFitness:
            presentedSheet = .fitness
        case .openPeopleMemory:
            presentedSheet = .peopleMemory
        case .openVices:
            presentedSheet = .vices
        case .openDebriefs:
            presentedSheet = .debriefs
        case .openFinance:
            presentedSheet = .finance
        }
    }

    private var welcomeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.welcomeMessage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }

    @ViewBuilder
    private var homeActionFeedbackOverlay: some View {
        if let feedback = homeActionFeedback {
            HomeActionFeedbackBanner(feedback: feedback)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    private func showHomeActionFeedback(_ feedback: HomeActionFeedback) {
        withAnimation(.easeOut(duration: 0.18)) {
            homeActionFeedback = feedback
        }

        homeActionFeedbackDismissTask?.cancel()
        homeActionFeedbackDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard Task.isCancelled == false else {
                return
            }

            withAnimation(.easeOut(duration: 0.18)) {
                homeActionFeedback = nil
            }
            homeActionFeedbackDismissTask = nil
        }
    }

    private func cancelHomeActionFeedback() {
        homeActionFeedbackDismissTask?.cancel()
        homeActionFeedbackDismissTask = nil
        homeActionFeedback = nil
    }

    private var captureOverlay: some View {
        CaptureQuickAddPopover(
            projects: viewModel.projects,
            onCancel: dismissCaptureOverlay
        ) { capture in
            viewModel.saveCapture(capture)
            dismissCaptureOverlay()
        }
    }

    private func presentCaptureOverlay() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isShowingCaptureOverlay = true
        }
    }

    private func dismissCaptureOverlay() {
        withAnimation(.easeOut(duration: 0.18)) {
            isShowingCaptureOverlay = false
        }
    }

}

private struct HomeActionFeedbackBanner: View {
    let feedback: HomeActionFeedback

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tintColor)

            Text(feedback.message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background {
            Capsule(style: .continuous)
                .fill(Color(.systemBackground).opacity(0.96))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(tintColor.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 14, y: 6)
    }

    private var iconName: String {
        switch feedback.kind {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "info.circle.fill"
        }
    }

    private var tintColor: Color {
        switch feedback.kind {
        case .success:
            return .green
        case .warning:
            return .orange
        }
    }
}

private struct HomeWidgetDropDelegate: DropDelegate {
    let targetWidgetID: UUID
    let targetHeight: CGFloat
    @Binding var draggingWidgetID: UUID?
    @Binding var previewDropTarget: HomeView.PreviewDropTarget?
    let viewModel: HomeLayoutViewModel
    let clearPreview: () -> Void

    func dropEntered(info: DropInfo) {
        updatePreview(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePreview(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard previewDropTarget?.widgetID == targetWidgetID else {
            return
        }
        previewDropTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingWidgetID else {
            clearPreview()
            return false
        }

        let placement = resolvedPlacement(for: info.location)
        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: draggingWidgetID,
            relativeTo: targetWidgetID,
            placement: placement
        )
        defer { clearPreview() }

        guard reorderedWidgets.map(\.id) != viewModel.widgets.map(\.id) else {
            return false
        }

        viewModel.moveWidget(
            withID: draggingWidgetID,
            relativeTo: targetWidgetID,
            placement: placement
        )
        return true
    }

    private func updatePreview(for info: DropInfo) {
        guard let draggingWidgetID, draggingWidgetID != targetWidgetID else {
            previewDropTarget = nil
            return
        }

        let placement = resolvedPlacement(for: info.location)
        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: draggingWidgetID,
            relativeTo: targetWidgetID,
            placement: placement
        )
        guard reorderedWidgets.map(\.id) != viewModel.widgets.map(\.id) else {
            previewDropTarget = nil
            return
        }

        previewDropTarget = HomeView.PreviewDropTarget(
            widgetID: targetWidgetID,
            placement: placement
        )
    }

    private func resolvedPlacement(for location: CGPoint) -> HomeLayoutViewModel.WidgetDropPlacement {
        location.y < targetHeight / 2 ? .before : .after
    }
}

private struct HomeCustomizationView: View {
    @ObservedObject var viewModel: HomeLayoutViewModel
    @Environment(\.dismiss) private var dismiss

    let onDone: () -> Void

    var body: some View {
        List {
            ForEach(viewModel.registry.modules, id: \.self) { module in
                Section(module.displayName) {
                    moduleSummary(for: module)

                    ForEach(descriptors(for: module)) { descriptor in
                        descriptorRow(descriptor)
                    }
                }
            }
        }
        .navigationTitle("Customize Home")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone()
                    dismiss()
                }
            }
        }
    }

    private func descriptors(for module: HomeWidgetModule) -> [HomeWidgetDescriptor] {
        let moduleDescriptor = viewModel.registry.moduleWidget(for: module).map { [$0] } ?? []
        return moduleDescriptor + viewModel.registry.featureWidgets(for: module)
    }

    private func moduleSummary(for module: HomeWidgetModule) -> some View {
        let descriptors = descriptors(for: module)
        let visibleCount = descriptors.filter { viewModel.isVisible($0) }.count

        return VStack(alignment: .leading, spacing: 4) {
            Text(module.displayName)
                .font(.headline)
            Text("\(visibleCount) visible of \(descriptors.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func descriptorRow(_ descriptor: HomeWidgetDescriptor) -> some View {
        HStack(spacing: 12) {
            Image(systemName: descriptor.iconSystemName)
                .foregroundStyle(descriptor.isAvailable ? Color.blue : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.displayName)
                    .foregroundStyle(descriptor.isAvailable ? Color.primary : Color.secondary)
                Text(customizationSubtitle(for: descriptor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.supportsVisibilityToggle(descriptor) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.isVisible(descriptor) },
                        set: { viewModel.setVisibility($0, for: descriptor) }
                    )
                )
                .labelsHidden()
                .disabled(descriptor.isAvailable == false)
            } else {
                Text(stateLabel(for: descriptor))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func customizationSubtitle(for descriptor: HomeWidgetDescriptor) -> String {
        switch viewModel.visibilityState(for: descriptor) {
        case .visible:
            return "Visible on Home"
        case .hidden:
            return "Hidden by Home customization"
        case .added:
            return "Added on Home"
        case .available:
            return descriptor.requiresConfiguration ? "Add from gallery to configure" : "Available to add"
        case .planned:
            return descriptor.availability.message ?? "Planned"
        }
    }

    private func stateLabel(for descriptor: HomeWidgetDescriptor) -> String {
        switch viewModel.visibilityState(for: descriptor) {
        case .visible:
            return "Visible"
        case .hidden:
            return "Hidden"
        case .added:
            return "Added"
        case .available:
            return descriptor.isAvailable ? "Optional" : "Planned"
        case .planned:
            return "Planned"
        }
    }
}

struct HomeCalendarOverviewCard: View {
    let overview: HomeCalendarOverview
    let onPlanTheDay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Today’s Events", systemImage: "calendar.badge.clock")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let nextEvent = overview.nextEvent {
                    Text("Next \(nextEvent.start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

            if overview.events.isEmpty {
                Text("No calendar events on the books today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(overview.events.prefix(3).enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(event.isAllDay ? Color.blue : Color.orange)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.subheadline.weight(.medium))
                            Text(eventTimeLabel(for: event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(event.calendarTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if overview.events.count > 3 {
                    Text("+ \(overview.events.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onPlanTheDay()
            } label: {
                Label("Plan the Day", systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        )
    }

    private var summaryText: String {
        if overview.events.isEmpty {
            return "Your day is open so far."
        }

        if overview.allDayEvents.isEmpty {
            return overview.events.count == 1 ? "1 event scheduled today." : "\(overview.events.count) events scheduled today."
        }

        return "\(overview.events.count) events, including \(overview.allDayEvents.count) all-day."
    }

    private func eventTimeLabel(for event: CalendarEventSnapshot) -> String {
        if event.isAllDay {
            return "All day"
        }

        return "\(event.start.formatted(date: .omitted, time: .shortened)) - \(event.end.formatted(date: .omitted, time: .shortened))"
    }
}

struct HomeCalendarPermissionCard: View {
    let status: CalendarPermissionStatus

    var body: some View {
        if status != .fullAccessGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Today’s Events", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline)

                Text(copyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var copyText: String {
        switch status {
        case .notDetermined:
            return "Calendar access is pending, so today’s event overview is not available yet."
        case .fullAccessGranted:
            return ""
        case .writeOnlyGrantedButInsufficient, .denied, .restricted:
            return "Grant full Calendar access to show today’s event overview here."
        case .error(let message):
            return message
        }
    }
}

struct PromisePresenceBanner: View {
    @StateObject private var viewModel: PromisePresenceViewModel

    init(promiseRepository: any PromiseRepository) {
        _viewModel = StateObject(
            wrappedValue: PromisePresenceViewModel(promiseRepository: promiseRepository)
        )
    }

    var body: some View {
        if let promise = viewModel.activePromises.first {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text(promise.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(promise.checkInAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .task {
                viewModel.load()
            }
        } else {
            EmptyView()
                .task {
                    viewModel.load()
                }
        }
    }
}

struct PromiseCard: View {
    let promise: Promise
    let isDue: Bool
    let onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(promise.title)
                        .font(.headline)
                    Text("Check in \(promise.checkInAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isDue ? "Check In" : "Open") {
                    onCheckIn()
                }
                .buttonStyle(.borderedProminent)
            }

            if let whyItMatters = promise.whyItMatters {
                Text(whyItMatters)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let expectedFriction = promise.expectedFriction {
                Label(expectedFriction, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PromiseStatView: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct HomeInboxCard: View {
    let summary: HomeInboxSummary
    let onCapture: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Inbox", systemImage: "tray.full.fill")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if summary.count > 0 {
                    Text("\(summary.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                Button {
                    onReview()
                } label: {
                    Label("Review", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(summary.count == 0)

                Button {
                    onCapture()
                } label: {
                    Label("Capture", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(inboxBackgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(summary.count == 0 ? 0.08 : 0.18), lineWidth: 1)
        )
    }

    private var summaryText: String {
        guard summary.count > 0 else {
            return "Clear. New ideas can land here without becoming tasks yet."
        }

        var parts = ["\(summary.count) unprocessed capture\(summary.count == 1 ? "" : "s")"]
        if let oldestAgeLabel = summary.oldestAgeLabel {
            parts.append("oldest \(oldestAgeLabel)")
        }
        if summary.projectTaggedCount > 0 {
            parts.append("\(summary.projectTaggedCount) project-tagged")
        }

        return parts.joined(separator: " • ")
    }

    private var inboxBackgroundColor: Color {
        if summary.count >= 8 {
            return Color.orange.opacity(0.12)
        }

        if summary.count > 0 {
            return Color.blue.opacity(0.08)
        }

        return Color.primary.opacity(0.035)
    }
}

struct HomePinnedProjectCard: View {
    let summary: HomePinnedProjectSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.project.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let projectSummary = summary.project.summary {
                Text(projectSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Label("\(summary.activeTaskCount)", systemImage: "checklist")
                Label("\(summary.projectItemCount)", systemImage: "sparkle.magnifyingglass")
                Text(summary.progressSummary)
                if let nextTask = summary.nextTask {
                    Text("Next: \(nextTask.title)")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CaptureQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var title = ""
    @State private var selectedProjectID: UUID?

    let projects: [Project]
    let onSave: (CaptureItem) -> Void

    var body: some View {
        Form {
            Section("Capture") {
                TextField("Jot it down", text: $title, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($isTitleFocused)

                if projects.isEmpty == false {
                    Picker("Project", selection: $selectedProjectID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id as UUID?)
                        }
                    }
                }
            }
        }
        .navigationTitle("Quick Capture")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let capture = CaptureItem(newTitle: title, projectID: selectedProjectID) else {
                        return
                    }

                    onSave(capture)
                }
                .disabled(CaptureItem.cleanedTitle(from: title) == nil)
            }
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}

private struct CaptureQuickAddPopover: View {
    @FocusState private var isTitleFocused: Bool
    @State private var title = ""
    @State private var selectedProjectID: UUID?

    let projects: [Project]
    let onCancel: () -> Void
    let onSave: (CaptureItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.medium))
            }

            TextField("Jot it down", text: $title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .focused($isTitleFocused)

            if projects.isEmpty == false {
                Picker("Project", selection: $selectedProjectID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(projects) { project in
                        Text(project.name).tag(project.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Spacer()
                Button {
                    guard let capture = CaptureItem(newTitle: title, projectID: selectedProjectID) else {
                        return
                    }

                    onSave(capture)
                } label: {
                    Label("Save", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(CaptureItem.cleanedTitle(from: title) == nil)
            }
        }
        .padding(18)
        .frame(maxWidth: 360, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 10)
        .onAppear {
            isTitleFocused = true
        }
    }
}

@MainActor
final class InboxReviewViewModel: ObservableObject {
    @Published private(set) var captures: [CaptureItem]
    @Published private(set) var projects: [Project]
    @Published private(set) var candidateGroups: [CaptureCandidateGroup] = []
    @Published private(set) var errorMessage: String?
    @Published var selectedIndex = 0

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let shoppingRepository: any ShoppingRepository
    private let musicPracticeRepository: any MusicPracticeRepository
    private let captureCapabilityRegistry: CaptureCapabilityRegistry
    private let nowProvider: @Sendable () -> Date

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        shoppingRepository: any ShoppingRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        captureCapabilityRegistry: CaptureCapabilityRegistry = .standard,
        initialCaptures: [CaptureItem],
        initialProjects: [Project],
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.shoppingRepository = shoppingRepository
        self.musicPracticeRepository = musicPracticeRepository
        self.captureCapabilityRegistry = captureCapabilityRegistry
        self.captures = initialCaptures
        self.projects = initialProjects
        self.nowProvider = nowProvider
    }

    var currentCapture: CaptureItem? {
        guard captures.indices.contains(selectedIndex) else {
            return nil
        }

        return captures[selectedIndex]
    }

    var currentRawCapture: RawCapture? {
        currentCapture.map(RawCapture.init(capture:))
    }

    var currentCandidateGroups: [CaptureCandidateGroup] {
        guard let rawCapture = currentRawCapture else {
            return []
        }

        return captureCapabilityRegistry.captureCandidateGroups(for: rawCapture)
    }

    func load() {
        do {
            captures = try captureRepository.fetchCaptures(
                includeProcessed: false,
                includeArchived: false
            )
            projects = try projectRepository.fetchProjects(includeArchived: false)
            selectedIndex = min(selectedIndex, max(captures.count - 1, 0))
            candidateGroups = currentCandidateGroups
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load inbox: \(error.localizedDescription)"
        }
    }

    func createProject(named name: String) -> Project? {
        guard let project = Project(newName: name) else {
            return nil
        }

        do {
            try projectRepository.saveProject(project, replacingProjectWithID: nil)
            projects = try projectRepository.fetchProjects(includeArchived: false)
            return project
        } catch {
            errorMessage = "Unable to create project: \(error.localizedDescription)"
            return nil
        }
    }

    func convertCurrentCaptureToTask(_ formData: MyTaskFormData) -> Bool {
        guard var capture = currentCapture, let task = formData.makeTask(savedAt: nowProvider()) else {
            return false
        }

        do {
            try taskRepository.saveTask(task, replacingTaskWithID: nil)
            capture.markProcessed(at: nowProvider(), convertedTaskID: task.id)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to create task: \(error.localizedDescription)"
            return false
        }
    }

    func convertCurrentCaptureToShoppingItem(_ formData: ShoppingItemFormData) -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        let now = nowProvider()
        guard let item = formData.makeItem(createdAt: now, updatedAt: now) else {
            errorMessage = "Enter a shopping item title."
            return false
        }

        do {
            try shoppingRepository.saveShoppingItem(item, replacingItemWithID: nil)
            capture.markProcessed(at: now)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to create shopping item: \(error.localizedDescription)"
            return false
        }
    }

    func convertCurrentCaptureToPracticePiece(_ piece: PracticePiece) -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        do {
            try musicPracticeRepository.savePracticePiece(piece, replacingPieceWithID: nil)
            capture.markProcessed(at: nowProvider())
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to save practice piece: \(error.localizedDescription)"
            return false
        }
    }

    func archiveCurrentCapture() -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        do {
            capture.archive(at: nowProvider())
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to archive capture: \(error.localizedDescription)"
            return false
        }
    }

    func tempSkipCurrentCapture() -> Bool {
        guard captures.count > 1, captures.indices.contains(selectedIndex) else {
            return false
        }

        let wasLastCapture = selectedIndex == captures.count - 1
        let skippedCapture = captures.remove(at: selectedIndex)
        captures.append(skippedCapture)
        selectedIndex = wasLastCapture ? 0 : selectedIndex
        errorMessage = nil
        return true
    }
}

struct InboxReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: InboxReviewViewModel
    @State private var selectedCandidate: CaptureCandidate?
    @State private var showingTaskForm = false
    @State private var showingShoppingForm = false
    @State private var showingPracticeForm = false
    @State private var taskFormData = MyTaskFormData()
    @State private var shoppingFormData = ShoppingItemFormData()
    @State private var practicePiece: PracticePiece?
    let onInboxChanged: () -> Void
    let onDone: () -> Void

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        shoppingRepository: any ShoppingRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        initialCaptures: [CaptureItem],
        initialProjects: [Project],
        onInboxChanged: @escaping () -> Void = {},
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InboxReviewViewModel(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                shoppingRepository: shoppingRepository,
                musicPracticeRepository: musicPracticeRepository,
                initialCaptures: initialCaptures,
                initialProjects: initialProjects
            )
        )
        self.onInboxChanged = onInboxChanged
        self.onDone = onDone
    }

    var body: some View {
        Group {
            if let capture = viewModel.currentCapture {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        captureCard(capture)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        ForEach(viewModel.currentCandidateGroups) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.title)
                                    .font(.headline)
                                ForEach(group.candidates) { candidate in
                                    Button {
                                        selectedCandidate = candidate
                                        openCandidate(candidate)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Label(candidate.moduleID.displayName, systemImage: "square.grid.2x2")
                                                .font(.subheadline.weight(.semibold))
                                            Text(candidate.title)
                                                .font(.headline)
                                            Text(candidate.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(candidate.primaryActionTitle)
                                                .font(.caption.weight(.semibold))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                if viewModel.tempSkipCurrentCapture() {
                                    resetDrafts()
                                }
                            } label: {
                                Label("Later", systemImage: "arrow.uturn.backward.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.captures.count < 2)

                            Button(role: .destructive) {
                                if viewModel.archiveCurrentCapture() {
                                    onInboxChanged()
                                    resetDrafts()
                                }
                            } label: {
                                Label("Archive Capture", systemImage: "archivebox")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "Inbox Clear",
                    systemImage: "tray",
                    description: Text("Captured thoughts are reviewed.")
                )
            }
        }
        .navigationTitle("Review Inbox")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onInboxChanged()
                    onDone()
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.load()
            resetDrafts()
        }
        .onChange(of: viewModel.currentCapture?.id) { _, _ in
            resetDrafts()
        }
        .sheet(isPresented: $showingTaskForm) {
            NavigationStack {
                TaskFormView(
                    mode: .create,
                    initialFormData: taskFormData,
                    projects: viewModel.projects,
                    reservedTaskIDs: Set(viewModel.captures.map(\.id))
                ) { task in
                    if viewModel.convertCurrentCaptureToTask(MyTaskFormData(task: task)) {
                        onInboxChanged()
                        showingTaskForm = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingShoppingForm) {
            NavigationStack {
                ShoppingItemFormView(
                    initialItem: ShoppingItem(
                        title: shoppingFormData.title,
                        notes: shoppingFormData.notes,
                        category: shoppingFormData.category,
                        storeType: shoppingFormData.storeType,
                        storeName: shoppingFormData.storeName,
                        urgency: shoppingFormData.urgency,
                        necessity: shoppingFormData.necessity
                    )
                ) { item in
                    if viewModel.convertCurrentCaptureToShoppingItem(ShoppingItemFormData(item: item)) {
                        onInboxChanged()
                        showingShoppingForm = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingPracticeForm) {
            NavigationStack {
                PracticePieceFormView(initialPiece: practicePiece) { piece in
                    if viewModel.convertCurrentCaptureToPracticePiece(piece) {
                        onInboxChanged()
                        showingPracticeForm = false
                    }
                }
            }
        }
    }

    private func captureCard(_ capture: CaptureItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(capture.title)
                .font(.title3.weight(.semibold))
            if let source = capture.source {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func resetDrafts() {
        guard let capture = viewModel.currentCapture else {
            return
        }

        taskFormData = MyTaskFormData(title: capture.title, notesText: capture.notes ?? "", projectID: capture.projectID)
        shoppingFormData = ShoppingItemFormData(title: capture.title, notes: capture.notes ?? "")
        practicePiece = PracticePiece(title: capture.title, notes: capture.notes)
        selectedCandidate = viewModel.currentCandidateGroups.first?.candidates.first
    }

    private func openCandidate(_ candidate: CaptureCandidate) {
        if candidate.taskFormData != nil {
            showingTaskForm = true
        } else if candidate.shoppingFormData != nil {
            showingShoppingForm = true
        } else if candidate.practicePiece != nil {
            showingPracticeForm = true
        }
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var tasks: [MyTask] = []
    @Published private(set) var captures: [CaptureItem] = []
    @Published private(set) var projectItems: [ProjectItem] = []
    @Published private(set) var errorMessage: String?

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
    }

    func load() {
        do {
            projects = try projectRepository.fetchProjects(includeArchived: false)
            tasks = try taskRepository.fetchTasks()
            captures = try captureRepository.fetchCaptures(includeProcessed: false, includeArchived: false)
            projectItems = try projectItemRepository.fetchProjectItems(includeArchived: false)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load projects: \(error.localizedDescription)"
        }
    }

    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID? = nil) {
        do {
            try projectRepository.saveProject(project, replacingProjectWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save project: \(error.localizedDescription)"
        }
    }
}

struct ProjectsView: View {
    @StateObject private var viewModel: ProjectsViewModel
    @State private var isProjectFormPresented = false

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarReader: any CalendarReading
    private let calendarBlockFocusRepository: any CalendarBlockFocusRepository
    private let debriefRepository: any DebriefRepository

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarReader: any CalendarReading,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        debriefRepository: any DebriefRepository
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarReader = calendarReader
        self.calendarBlockFocusRepository = calendarBlockFocusRepository
        self.debriefRepository = debriefRepository
        _viewModel = StateObject(
            wrappedValue: ProjectsViewModel(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Create a project for larger work that needs its own context.")
                    )
                } else {
                    ForEach(viewModel.projects) { project in
                        NavigationLink {
                            ProjectDetailView(
                                projectID: project.id,
                                taskRepository: taskRepository,
                                projectRepository: projectRepository,
                                captureRepository: captureRepository,
                                projectItemRepository: projectItemRepository,
                                calendarPermissionProvider: calendarPermissionProvider,
                                calendarReader: calendarReader,
                                calendarBlockFocusRepository: calendarBlockFocusRepository,
                                debriefRepository: debriefRepository
                            )
                        } label: {
                            ProjectListRow(
                                project: project,
                                taskSummary: project.taskSummary(from: viewModel.tasks),
                                itemCount: viewModel.projectItems.filter { $0.projectID == project.id }.count
                            )
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isProjectFormPresented = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isProjectFormPresented) {
                NavigationStack {
                    ProjectFormView { project in
                        viewModel.saveProject(project)
                        isProjectFormPresented = false
                    }
                }
            }
            .task {
                viewModel.load()
            }
            .onAppear {
                viewModel.load()
            }
        }
    }
}

private struct ProjectListRow: View {
    let project: Project
    let taskSummary: ProjectTaskSummary
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(project.name)
                    .font(.body.weight(.semibold))
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if let summary = project.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("\(taskSummary.progressSummary) • \(itemCount) project items")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let nextAction = taskSummary.nextAction {
                Text("Next: \(nextAction.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectDetailView: View {
    private enum SheetDestination: Identifiable {
        case capture
        case task
        case maybe
        case note
        case editProject(Project)
        case focus(CalendarEventSnapshot)

        var id: String {
            switch self {
            case .capture:
                return "capture"
            case .task:
                return "task"
            case .maybe:
                return "maybe"
            case .note:
                return "note"
            case .editProject(let project):
                return "edit-\(project.id.uuidString)"
            case .focus(let event):
                let identifier = event.identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let identifier, identifier.isEmpty == false {
                    return "focus-\(identifier)-\(event.start.timeIntervalSince1970)"
                }

                return "focus-\(event.title)-\(event.start.timeIntervalSince1970)"
            }
        }
    }

    let projectID: UUID
    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarReader: any CalendarReading
    private let calendarBlockFocusRepository: any CalendarBlockFocusRepository
    private let debriefRepository: any DebriefRepository

    @State private var project: Project?
    @State private var tasks: [MyTask] = []
    @State private var captures: [CaptureItem] = []
    @State private var projectItems: [ProjectItem] = []
    @State private var allProjects: [Project] = []
    @State private var upcomingEvents: [CalendarEventSnapshot] = []
    @State private var debriefs: [CalendarDebriefRecord] = []
    @State private var focuses: [CalendarBlockFocus] = []
    @State private var errorMessage: String?
    @State private var sheetDestination: SheetDestination?

    init(
        projectID: UUID,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarReader: any CalendarReading,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        debriefRepository: any DebriefRepository
    ) {
        self.projectID = projectID
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarReader = calendarReader
        self.calendarBlockFocusRepository = calendarBlockFocusRepository
        self.debriefRepository = debriefRepository
    }

    private var projectTasks: [MyTask] {
        projectTaskSummary?.activeTasks.filter { $0.status != .done } ?? []
    }

    private var nextTasks: [MyTask] {
        projectTaskSummary?.nextActions(limit: 3) ?? []
    }

    private var projectTaskSummary: ProjectTaskSummary? {
        project?.taskSummary(from: tasks)
    }

    private var maybes: [ProjectItem] {
        projectItems.filter { $0.projectID == projectID && $0.kind == .maybe && $0.isArchived == false }
    }

    private var notes: [ProjectItem] {
        projectItems.filter { $0.projectID == projectID && $0.kind == .note && $0.isArchived == false }
    }

    var body: some View {
        Group {
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overview(project)
                        calendarActivitySection(project)
                        taskSection(title: "Next Tasks", tasks: nextTasks)
                        taskSection(title: "All Tasks", tasks: projectTasks)
                        itemSection(title: "Maybes", items: maybes, emptyText: "No maybe items yet.")
                        itemSection(title: "Notes", items: notes, emptyText: "No project notes yet.")
                    }
                    .padding()
                }
                .navigationTitle(project.name)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button("Capture") { sheetDestination = .capture }
                            Button("Task") { sheetDestination = .task }
                            Button("Maybe") { sheetDestination = .maybe }
                            Button("Note") { sheetDestination = .note }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }

                        Button {
                            sheetDestination = .editProject(project)
                        } label: {
                            Label("Edit Project", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text(errorMessage ?? "This project is no longer available.")
                )
            }
        }
        .sheet(item: $sheetDestination) { destination in
            NavigationStack {
                switch destination {
                case .capture:
                    CaptureQuickAddView(
                        projects: project.map { [$0] } ?? []
                    ) { capture in
                        var projectCapture = capture
                        projectCapture.projectID = projectID
                        saveCapture(projectCapture)
                        sheetDestination = nil
                    }
                case .task:
                    TaskFormView(
                        mode: .create,
                        initialFormData: MyTaskFormData(projectID: projectID),
                        projects: project.map { [$0] } ?? []
                    ) { task in
                        saveTask(task)
                        sheetDestination = nil
                    }
                case .maybe:
                    ProjectItemFormView(projectID: projectID, kind: .maybe) { item in
                        saveProjectItem(item)
                        sheetDestination = nil
                    }
                case .note:
                    ProjectItemFormView(projectID: projectID, kind: .note) { item in
                        saveProjectItem(item)
                        sheetDestination = nil
                    }
                case .editProject(let project):
                    ProjectFormView(initialProject: project) { updatedProject in
                        saveProject(updatedProject, replacingProjectWithID: project.id)
                        sheetDestination = nil
                    }
                case .focus(let event):
                    CalendarBlockFocusSheet(
                        event: event,
                        existingFocus: focus(for: event),
                        projects: allProjects,
                        tasks: tasks,
                        onSave: { focus in
                            saveFocus(focus)
                            sheetDestination = nil
                        }
                    )
                }
            }
        }
        .task {
            await load()
        }
        .onAppear {
            Task {
                await load()
            }
        }
    }

    private func overview(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(project.isPinned ? "Pinned" : "Project", systemImage: project.isPinned ? "pin.fill" : "folder")
                    .font(.headline)
                Spacer()
                Button(project.isPinned ? "Unpin" : "Pin") {
                    var updatedProject = project
                    updatedProject.isPinned.toggle()
                    updatedProject.updatedAt = .now
                    saveProject(updatedProject, replacingProjectWithID: project.id)
                }
                .buttonStyle(.bordered)
            }

            if let summary = project.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let taskSummary = projectTaskSummary {
                Text(taskSummary.progressSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let nextAction = taskSummary.nextAction {
                    Text("Next: \(nextAction.title)")
                        .font(.footnote.weight(.medium))
                        .lineLimit(2)
                }
            }

            HStack {
                ProjectMetricView(title: "Tasks", value: projectTaskSummary?.activeTaskCount ?? projectTasks.count)
                ProjectMetricView(title: "Done", value: projectTaskSummary?.completedActiveTaskCount ?? 0)
                ProjectMetricView(title: "Maybes", value: maybes.count)
                ProjectMetricView(title: "Notes", value: notes.count)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func calendarActivitySection(_ project: Project) -> some View {
        let upcomingBlocks = upcomingProjectBlocks(for: project)
        let recentProjectDebriefs = recentProjectDebriefs(for: project)
        let recentTaskOutcomes = recentTaskOutcomes(for: project)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Calendar Activity")
                .font(.headline)

            activitySubsection(
                title: "Upcoming",
                emptyText: "No upcoming linked blocks yet.",
                rows: upcomingBlocks.map { event in
                    let focus = focus(for: event)
                    return AnyView(
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(event.formattedTimeRange)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(focus != nil ? "Edit Focus" : "Pick Focus") {
                                    sheetDestination = .focus(event)
                                }
                                .buttonStyle(.bordered)
                            }

                            if let focus, let projectName = focus.linkedProjectID.flatMap({ cachedProjectName(for: $0) }) {
                                Text(projectName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let focus, focus.selectedTaskCount > 0 {
                                Text("\(focus.selectedTaskCount) focus task\(focus.selectedTaskCount == 1 ? "" : "s") selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                    )
                }
            )

            activitySubsection(
                title: "Recent Debriefs",
                emptyText: "No linked Debriefs yet.",
                rows: recentProjectDebriefs.map { debrief in
                    AnyView(
                        VStack(alignment: .leading, spacing: 4) {
                            Text(debrief.titleSnapshot)
                                .font(.subheadline.weight(.medium))
                            Text(recentDebriefDetailText(for: debrief))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                    )
                }
            )

            activitySubsection(
                title: "Recent Task Outcomes",
                emptyText: "No task outcomes recorded yet.",
                rows: recentTaskOutcomes.map { outcome in
                    AnyView(
                        VStack(alignment: .leading, spacing: 4) {
                            Text(outcome.taskTitleSnapshot)
                                .font(.subheadline.weight(.medium))
                            Text(outcome.outcome.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                    )
                }
            )
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func activitySubsection(
        title: String,
        emptyText: String,
        rows: [AnyView]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if rows.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                    entry.element
                }
            }
        }
    }

    private func upcomingProjectBlocks(for project: Project) -> [CalendarEventSnapshot] {
        let matcher = CalendarProjectMatcher()

        return upcomingEvents.filter { event in
            if let focus = focus(for: event), focus.linkedProjectID == project.id {
                return true
            }

            return matcher.match(eventTitle: event.title, project: project)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }

            return lhs.end < rhs.end
        }
    }

    private func recentProjectDebriefs(for project: Project) -> [CalendarDebriefRecord] {
        let cutoff = Date().addingTimeInterval(-86_400 * 7)
        let matcher = CalendarProjectMatcher()

        return debriefs
            .filter { $0.status == .completed && $0.endDateSnapshot >= cutoff }
            .filter { debrief in
                if let focus = focus(for: debrief), focus.linkedProjectID == project.id {
                    return true
                }

                return matcher.match(eventTitle: debrief.titleSnapshot, project: project)
            }
            .sorted { lhs, rhs in
                if lhs.completedAt != rhs.completedAt {
                    return (lhs.completedAt ?? lhs.updatedAt) > (rhs.completedAt ?? rhs.updatedAt)
                }

                return lhs.endDateSnapshot > rhs.endDateSnapshot
            }
    }

    private func recentTaskOutcomes(for project: Project) -> [DebriefTaskOutcome] {
        recentProjectDebriefs(for: project)
            .flatMap(\.taskOutcomes)
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.taskTitleSnapshot.localizedCaseInsensitiveCompare(rhs.taskTitleSnapshot) == .orderedAscending
            }
    }

    private func recentDebriefDetailText(for debrief: CalendarDebriefRecord) -> String {
        var parts: [String] = []

        if let rating = debrief.workProductivityRating {
            parts.append("Productivity \(rating)/5")
        }

        if debrief.taskOutcomes.isEmpty == false {
            parts.append("\(debrief.taskOutcomes.count) task outcome\(debrief.taskOutcomes.count == 1 ? "" : "s")")
        }

        parts.append(debrief.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? debrief.endDateSnapshot.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }

    private func focus(for event: CalendarEventSnapshot) -> CalendarBlockFocus? {
        guard
            let eventIdentifier = event.identifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventIdentifier.isEmpty == false,
            let calendarIdentifier = event.calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarIdentifier.isEmpty == false
        else {
            return nil
        }

        return focuses.first { focus in
            focus.eventIdentifier == eventIdentifier
                && focus.calendarIdentifier == calendarIdentifier
        }
    }

    private func focus(for debrief: CalendarDebriefRecord) -> CalendarBlockFocus? {
        guard
            let eventIdentifier = debrief.eventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventIdentifier.isEmpty == false,
            let calendarIdentifier = debrief.calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarIdentifier.isEmpty == false
        else {
            return nil
        }

        return focuses.first { focus in
            focus.eventIdentifier == eventIdentifier
                && focus.calendarIdentifier == calendarIdentifier
        }
    }

    private func cachedProjectName(for projectID: UUID) -> String? {
        allProjects.first(where: { $0.id == projectID })?.name
    }

    private func upcomingCalendarEvents(relativeTo now: Date) async -> [CalendarEventSnapshot] {
        guard calendarPermissionProvider.currentStatus() == .fullAccessGranted else {
            return []
        }

        do {
            let window = DateInterval(
                start: now,
                end: now.addingTimeInterval(86_400 * 7)
            )

            return try await calendarReader.fetchEvents(in: window)
                .filter { $0.end > now }
                .sorted { lhs, rhs in
                    if lhs.start != rhs.start {
                        return lhs.start < rhs.start
                    }

                    if lhs.end != rhs.end {
                        return lhs.end < rhs.end
                    }

                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
        } catch {
            return []
        }
    }

    private func taskSection(title: String, tasks: [MyTask]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if tasks.isEmpty {
                Text("No tasks here yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.status == .done ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                            if let dueDate = task.dueDate {
                                Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func itemSection(title: String, items: [ProjectItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if items.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                        if let notes = item.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if item.kind == .maybe, let pressure = item.pressure {
                            Text(pressure.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @MainActor
    private func load() async {
        do {
            let now = Date()
            project = try projectRepository.project(withID: projectID)
            tasks = try taskRepository.fetchTasks()
            captures = try captureRepository.fetchCaptures(includeProcessed: false, includeArchived: false)
            projectItems = try projectItemRepository.fetchProjectItems(for: projectID, includeArchived: false)
            allProjects = try projectRepository.fetchProjects(includeArchived: false)
            debriefs = try debriefRepository.fetchDebriefs()
            focuses = try calendarBlockFocusRepository.fetchFocuses(
                in: DateInterval(
                    start: now.addingTimeInterval(-86_400 * 7),
                    end: now.addingTimeInterval(86_400 * 7)
                )
            )
            upcomingEvents = await upcomingCalendarEvents(relativeTo: now)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load project: \(error.localizedDescription)"
        }
    }

    private func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) {
        do {
            try projectRepository.saveProject(project, replacingProjectWithID: originalID)
            Task {
                await load()
            }
        } catch {
            errorMessage = "Unable to save project: \(error.localizedDescription)"
        }
    }

    private func saveTask(_ task: MyTask) {
        do {
            try taskRepository.saveTask(task, replacingTaskWithID: nil)
            Task {
                await load()
            }
        } catch {
            errorMessage = "Unable to save task: \(error.localizedDescription)"
        }
    }

    private func saveCapture(_ capture: CaptureItem) {
        do {
            try captureRepository.saveCapture(capture, replacingCaptureWithID: nil)
            Task {
                await load()
            }
        } catch {
            errorMessage = "Unable to save capture: \(error.localizedDescription)"
        }
    }

    private func saveProjectItem(_ item: ProjectItem) {
        do {
            try projectItemRepository.saveProjectItem(item, replacingProjectItemWithID: nil)
            Task {
                await load()
            }
        } catch {
            errorMessage = "Unable to save project item: \(error.localizedDescription)"
        }
    }

    private func saveFocus(_ focus: CalendarBlockFocus) {
        do {
            try calendarBlockFocusRepository.saveFocus(focus, replacingFocusWithID: focus.id)
            Task {
                await load()
            }
        } catch {
            errorMessage = "Unable to save focus: \(error.localizedDescription)"
        }
    }
}

private struct ProjectMetricView: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarBlockFocusSheet: View {
    @Environment(\.dismiss) private var dismiss

    let event: CalendarEventSnapshot
    let existingFocus: CalendarBlockFocus?
    let projects: [Project]
    let tasks: [MyTask]
    let onSave: (CalendarBlockFocus) -> Void

    @State private var draft: CalendarBlockFocus

    init(
        event: CalendarEventSnapshot,
        existingFocus: CalendarBlockFocus?,
        projects: [Project],
        tasks: [MyTask],
        onSave: @escaping (CalendarBlockFocus) -> Void
    ) {
        self.event = event
        self.existingFocus = existingFocus
        self.projects = projects
        self.tasks = tasks
        self.onSave = onSave

        var initialDraft = existingFocus
            ?? CalendarBlockFocus(
                event: event
            )
            ?? CalendarBlockFocus(
                id: UUID(),
                eventKey: DebriefEventKey.from(
                    eventIdentifier: event.identifier,
                    title: event.title,
                    start: event.start,
                    end: event.end,
                    calendarIdentifier: event.calendarIdentifier,
                    calendarTitle: event.calendarTitle
                ),
                eventIdentifier: event.identifier ?? "",
                calendarIdentifier: event.calendarIdentifier ?? "",
                titleSnapshot: event.title,
                startDateSnapshot: event.start,
                endDateSnapshot: event.end
            )

        if initialDraft.preferredDebriefTemplateKind == nil {
            initialDraft.preferredDebriefTemplateKind = CalendarDebriefRecord.suggestedTemplate(
                for: event.title,
                calendarTitle: event.calendarTitle
            )
        }

        _draft = State(initialValue: initialDraft)
    }

    private var selectedProject: Project? {
        guard let projectID = draft.linkedProjectID else {
            return nil
        }

        return projects.first(where: { $0.id == projectID })
    }

    private var suggestedTasks: [MyTask] {
        guard let selectedProject else {
            return []
        }

        return CalendarBlockFocusTaskSuggestionService().suggestedTasks(
            for: selectedProject,
            tasks: tasks,
            blockDurationMinutes: draft.durationMinutes
        )
    }

    private var saveDisabled: Bool {
        draft.eventIdentifier.isEmpty || draft.calendarIdentifier.isEmpty
    }

    var body: some View {
        Form {
            Section("Block") {
                Text(event.title)
                    .font(.headline)
                Text(event.formattedTimeRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(event.calendarTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Project") {
                Picker("Linked project", selection: $draft.linkedProjectID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(projects) { project in
                        Text(project.name).tag(project.id as UUID?)
                    }
                }
                .onChange(of: draft.linkedProjectID) { _, newProjectID in
                    draft.selectedTaskIDs = []
                    draft.isProjectLinkUserConfirmed = newProjectID != nil
                    if newProjectID == nil {
                        draft.isNoFocusNeeded = false
                    }
                }

                Toggle("No focus needed", isOn: $draft.isNoFocusNeeded)
                    .onChange(of: draft.isNoFocusNeeded) { _, newValue in
                        if newValue {
                            draft.linkedProjectID = nil
                            draft.selectedTaskIDs = []
                            draft.isProjectLinkUserConfirmed = false
                        }
                    }

                if draft.isNoFocusNeeded == false {
                    TextField(
                        "Intention note",
                        text: Binding(
                            get: { draft.intentionNote ?? "" },
                            set: { draft.intentionNote = $0 }
                        ),
                        axis: .vertical
                    )
                }
            }

            if draft.isNoFocusNeeded == false {
                Section("Suggested tasks") {
                    if selectedProject != nil {
                        if suggestedTasks.isEmpty {
                            Text("No open tasks for this project.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(suggestedTasks) { task in
                                    Button {
                                        toggleTaskSelection(task.id)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: draft.selectedTaskIDs.contains(task.id) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(
                                                    draft.selectedTaskIDs.contains(task.id)
                                                        ? Color.accentColor
                                                        : Color.secondary
                                                )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(task.title)
                                                    .font(.subheadline.weight(.medium))
                                                if let dueDate = task.dueDate {
                                                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                } else if let estimatedMinutes = task.estimatedMinutes {
                                                    Text("\(estimatedMinutes)m estimated")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        Text("Pick a project to see suggested tasks.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Debrief template") {
                    Picker("Preferred template", selection: Binding(
                        get: { draft.preferredDebriefTemplateKind ?? .workBlock },
                        set: { draft.preferredDebriefTemplateKind = $0 }
                    )) {
                        ForEach(DebriefTemplateKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .navigationTitle("Focus")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(saveDisabled)
            }
        }
        .onAppear {
            if draft.linkedProjectID == nil, let matchedProject = CalendarProjectMatcher().match(
                eventTitle: event.title,
                projects: projects
            ).matchedProjectID {
                draft.linkedProjectID = matchedProject
                draft.isProjectLinkUserConfirmed = existingFocus?.isProjectLinkUserConfirmed ?? false
            }
        }
    }

    private func toggleTaskSelection(_ taskID: UUID) {
        if let index = draft.selectedTaskIDs.firstIndex(of: taskID) {
            draft.selectedTaskIDs.remove(at: index)
        } else {
            draft.selectedTaskIDs.append(taskID)
        }
    }

    private func save() {
        let updatedEventIdentifier = event.identifier ?? draft.eventIdentifier
        let updatedCalendarIdentifier = event.calendarIdentifier ?? draft.calendarIdentifier
        let updatedEventKey = DebriefEventKey.from(
            eventIdentifier: event.identifier,
            title: event.title,
            start: event.start,
            end: event.end,
            calendarIdentifier: event.calendarIdentifier,
            calendarTitle: event.calendarTitle
        )
        let updatedDraft = CalendarBlockFocus(
            id: draft.id,
            eventKey: updatedEventKey,
            eventIdentifier: updatedEventIdentifier,
            calendarIdentifier: updatedCalendarIdentifier,
            titleSnapshot: event.title,
            startDateSnapshot: event.start,
            endDateSnapshot: event.end,
            linkedProjectID: draft.linkedProjectID,
            selectedTaskIDs: draft.selectedTaskIDs,
            intentionNote: draft.intentionNote,
            preferredDebriefTemplateKind: draft.preferredDebriefTemplateKind,
            isProjectLinkUserConfirmed: draft.linkedProjectID != nil && draft.isNoFocusNeeded == false,
            isNoFocusNeeded: draft.isNoFocusNeeded,
            createdAt: draft.createdAt,
            updatedAt: .now
        )
        onSave(updatedDraft)
        dismiss()
    }
}

private extension CalendarEventSnapshot {
    var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        }

        return "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var summary: String
    @State private var isPinned: Bool
    let initialProject: Project?
    let onSave: (Project) -> Void

    init(initialProject: Project? = nil, onSave: @escaping (Project) -> Void) {
        self.initialProject = initialProject
        self.onSave = onSave
        _name = State(initialValue: initialProject?.name ?? "")
        _summary = State(initialValue: initialProject?.summary ?? "")
        _isPinned = State(initialValue: initialProject?.isPinned ?? false)
    }

    var body: some View {
        Form {
            Section("Project") {
                TextField("Name", text: $name)
                TextField("Summary", text: $summary, axis: .vertical)
                Toggle("Pin to Home", isOn: $isPinned)
            }
        }
        .navigationTitle(initialProject == nil ? "New Project" : "Edit Project")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let now = Date()
                    let project = Project(
                        id: initialProject?.id ?? UUID(),
                        name: name,
                        summary: summary,
                        isPinned: isPinned,
                        isArchived: initialProject?.isArchived ?? false,
                        createdAt: initialProject?.createdAt ?? now,
                        updatedAt: now
                    )
                    onSave(project)
                }
                .disabled(Project.cleanedName(from: name) == nil)
            }
        }
    }
}

private struct ProjectItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var source = ""
    @State private var pressure: ProjectItemPressure? = .noPressure
    @State private var hasReviewDate = false
    @State private var reviewAfter = Date()

    let projectID: UUID
    let kind: ProjectItemKind
    let onSave: (ProjectItem) -> Void

    var body: some View {
        Form {
            Section(kind.displayName) {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                TextField("Source", text: $source)
            }
            if kind == .maybe {
                Section("Review") {
                    Picker("Pressure", selection: $pressure) {
                        Text("None").tag(nil as ProjectItemPressure?)
                        ForEach(ProjectItemPressure.allCases, id: \.self) { pressure in
                            Text(pressure.displayName).tag(pressure as ProjectItemPressure?)
                        }
                    }
                    Toggle("Review Later", isOn: $hasReviewDate)
                    if hasReviewDate {
                        DatePicker("Review", selection: $reviewAfter, displayedComponents: [.date])
                    }
                }
            }
        }
        .navigationTitle("New \(kind.displayName)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        ProjectItem(
                            projectID: projectID,
                            kind: kind,
                            title: title,
                            notes: notes,
                            source: source,
                            pressure: kind == .maybe ? pressure : nil,
                            reviewAfter: kind == .maybe && hasReviewDate ? reviewAfter : nil
                        )
                    )
                }
                .disabled(ProjectItem.cleanedTitle(from: title) == nil)
            }
        }
    }
}

#Preview {
    let container = AppContainer.makePreview()
    HomeView(
        taskRepository: container.taskRepository,
        projectRepository: container.projectRepository,
        captureRepository: container.captureRepository,
        projectItemRepository: container.projectItemRepository,
        scheduledBlockRepository: container.scheduledBlockRepository,
        settingsRepository: container.settingsRepository,
        homeLayoutRepository: container.homeLayoutRepository,
        calendarPermissionProvider: container.calendarPermissionProvider,
        calendarListingService: container.calendarListingService,
        calendarReader: container.calendarReader,
        calendarWriter: container.calendarWriter,
        calendarReconciler: container.calendarReconciler,
        calendarChangeObserver: container.calendarChangeObserver,
        promiseRepository: container.promiseRepository,
        routineRepository: container.routineRepository,
        shoppingRepository: container.shoppingRepository,
        healthRepository: container.healthRepository,
        musicPracticeRepository: container.musicPracticeRepository,
        fitnessRepository: container.fitnessRepository,
        peopleMemoryRepository: container.peopleMemoryRepository,
        viceRepository: container.viceRepository,
        calendarBlockFocusRepository: container.calendarBlockFocusRepository,
        debriefRepository: container.debriefRepository,
        financeRepository: container.financeRepository
    )
}
