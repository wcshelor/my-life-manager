//
//  ContentView.swift
//  task-manager
//
//  Created by Camp Shelor on 3/26/26.
//

import SwiftUI

struct ContentView: View {
    private let appEnvironment: AppEnvironment

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
    }

    var body: some View {
        TaskManagerTabShell(appEnvironment: appEnvironment)
    }
}

private struct TaskManagerTabShell: View {
    @ObservedObject private var alertRouteCoordinator: AlertRouteCoordinator
    @StateObject private var notificationHomeViewModel: HomeExecutionViewModel

    private let appEnvironment: AppEnvironment

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
        self.alertRouteCoordinator = appEnvironment.alertRouteCoordinator
        _notificationHomeViewModel = StateObject(
            wrappedValue: HomeExecutionViewModel(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                captureRepository: appEnvironment.captureRepository,
                projectItemRepository: appEnvironment.projectItemRepository,
                promiseRepository: appEnvironment.promiseRepository,
                routineRepository: appEnvironment.routineRepository,
                shoppingRepository: appEnvironment.shoppingRepository,
                healthRepository: appEnvironment.healthRepository,
                musicPracticeRepository: appEnvironment.musicPracticeRepository,
                fitnessRepository: appEnvironment.fitnessRepository,
                peopleMemoryRepository: appEnvironment.peopleMemoryRepository,
                viceRepository: appEnvironment.viceRepository,
                calendarBlockFocusRepository: appEnvironment.calendarBlockFocusRepository,
                debriefRepository: appEnvironment.debriefRepository,
                financeRepository: appEnvironment.financeRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarReader: appEnvironment.calendarReader,
                appUpdateReminderTracker: LiveAppUpdateReminderTracker()
            )
        )
    }

    var body: some View {
        TabView {
            HomeView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                captureRepository: appEnvironment.captureRepository,
                projectItemRepository: appEnvironment.projectItemRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                settingsRepository: appEnvironment.settingsRepository,
                homeLayoutRepository: appEnvironment.homeLayoutRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarListingService: appEnvironment.calendarListingService,
                calendarReader: appEnvironment.calendarReader,
                calendarWriter: appEnvironment.calendarWriter,
                calendarReconciler: appEnvironment.calendarReconciler,
                calendarChangeObserver: appEnvironment.calendarChangeObserver,
                promiseRepository: appEnvironment.promiseRepository,
                routineRepository: appEnvironment.routineRepository,
                shoppingRepository: appEnvironment.shoppingRepository,
                healthRepository: appEnvironment.healthRepository,
                musicPracticeRepository: appEnvironment.musicPracticeRepository,
                fitnessRepository: appEnvironment.fitnessRepository,
                peopleMemoryRepository: appEnvironment.peopleMemoryRepository,
                viceRepository: appEnvironment.viceRepository,
                calendarBlockFocusRepository: appEnvironment.calendarBlockFocusRepository,
                debriefRepository: appEnvironment.debriefRepository,
                financeRepository: appEnvironment.financeRepository
            )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TaskListView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                calendarWriter: appEnvironment.calendarWriter,
                promiseRepository: appEnvironment.promiseRepository
            )
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            ProjectsView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                captureRepository: appEnvironment.captureRepository,
                projectItemRepository: appEnvironment.projectItemRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarReader: appEnvironment.calendarReader,
                calendarBlockFocusRepository: appEnvironment.calendarBlockFocusRepository,
                debriefRepository: appEnvironment.debriefRepository
            )
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            SettingsView(
                settingsRepository: appEnvironment.settingsRepository,
                alertRepository: appEnvironment.alertRepository,
                alertScheduler: appEnvironment.alertScheduler,
                homeLayoutRepository: appEnvironment.homeLayoutRepository,
                projectRepository: appEnvironment.projectRepository,
                routineRepository: appEnvironment.routineRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarListingService: appEnvironment.calendarListingService
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .sheet(item: pendingRouteBinding, onDismiss: {
            alertRouteCoordinator.clearPendingRoute()
        }) { route in
            AppNotificationRouteSheet(
                route: route,
                appEnvironment: appEnvironment,
                homeViewModel: notificationHomeViewModel
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    private var pendingRouteBinding: Binding<AlertPendingRoute?> {
        Binding(
            get: {
                alertRouteCoordinator.pendingRoute
            },
            set: { newValue in
                alertRouteCoordinator.pendingRoute = newValue
            }
        )
    }
}

#Preview {
    ContentView(appEnvironment: AppEnvironment(container: .makePreview()))
}
