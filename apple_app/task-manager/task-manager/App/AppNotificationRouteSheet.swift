import SwiftUI

struct AppNotificationRouteSheet: View {
    let route: AlertPendingRoute
    let appEnvironment: AppEnvironment
    @ObservedObject var homeViewModel: HomeExecutionViewModel

    var body: some View {
        routeContent
            .task {
                homeViewModel.load()
            }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch route.target {
        case .openRoutine(let routineID),
             .startRoutine(let routineID):
            NavigationStack {
                RoutineSessionView(
                    viewModel: homeViewModel,
                    registry: HomeWidgetRegistry.standard,
                    taskRepository: appEnvironment.taskRepository,
                    projectRepository: appEnvironment.projectRepository,
                    captureRepository: appEnvironment.captureRepository,
                    projectItemRepository: appEnvironment.projectItemRepository,
                    scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                    settingsRepository: appEnvironment.settingsRepository,
                    calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                    calendarListingService: appEnvironment.calendarListingService,
                    calendarReader: appEnvironment.calendarReader,
                    calendarWriter: appEnvironment.calendarWriter,
                    calendarReconciler: appEnvironment.calendarReconciler,
                    calendarChangeObserver: appEnvironment.calendarChangeObserver,
                    promiseRepository: appEnvironment.promiseRepository,
                    shoppingRepository: appEnvironment.shoppingRepository,
                    healthRepository: appEnvironment.healthRepository,
                    musicPracticeRepository: appEnvironment.musicPracticeRepository,
                    fitnessRepository: appEnvironment.fitnessRepository,
                    peopleMemoryRepository: appEnvironment.peopleMemoryRepository,
                    viceRepository: appEnvironment.viceRepository,
                    calendarBlockFocusRepository: appEnvironment.calendarBlockFocusRepository,
                    debriefRepository: appEnvironment.debriefRepository,
                    financeRepository: appEnvironment.financeRepository,
                    routineID: routineID
                )
            }
        case .openTasks:
            TaskListView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                calendarWriter: appEnvironment.calendarWriter,
                promiseRepository: appEnvironment.promiseRepository
            )
        case .openPromises:
            NavigationStack {
                PromiseModuleView(viewModel: homeViewModel)
            }
        case .checkInPromise(let promiseID):
            NavigationStack {
                PromiseModuleView(
                    viewModel: homeViewModel,
                    initialRoute: .checkInDuePromise(promiseID)
                )
            }
        case .openDebriefs:
            DebriefListView(
                debriefRepository: appEnvironment.debriefRepository,
                captureRepository: appEnvironment.captureRepository,
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                calendarBlockFocusRepository: appEnvironment.calendarBlockFocusRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarReader: appEnvironment.calendarReader,
                onChanged: {
                    homeViewModel.load()
                }
            )
        case .openPeopleMemory:
            NavigationStack {
                PeopleMemoryView(
                    peopleMemoryRepository: appEnvironment.peopleMemoryRepository,
                    onChanged: {
                        homeViewModel.load()
                    }
                )
            }
        case .openPeopleStudy:
            NavigationStack {
                PeopleMemoryView(
                    peopleMemoryRepository: appEnvironment.peopleMemoryRepository,
                    initialRoute: .studyDueNames,
                    onChanged: {
                        homeViewModel.load()
                    }
                )
            }
        case .openHealth:
            NavigationStack {
                HealthView(
                    healthRepository: appEnvironment.healthRepository,
                    fitnessRepository: appEnvironment.fitnessRepository,
                    onChange: {
                        homeViewModel.load()
                    }
                )
            }
        }
    }
}
