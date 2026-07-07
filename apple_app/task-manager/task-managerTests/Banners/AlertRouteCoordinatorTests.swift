import Foundation
import Testing
@testable import task_manager

@MainActor
struct AlertRouteCoordinatorTests {
    @Test func routeCoordinatorTreatsRoutineTargetsAsPendingRoutineRoutes() {
        let coordinator = AlertRouteCoordinator()
        let routineID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174400")!

        coordinator.open(target: .startRoutine(routineID))

        #expect(coordinator.pendingRoutineRoute?.routineID == routineID)
        #expect(coordinator.pendingRoutineRoute != nil)

        coordinator.clearPendingRoutineRoute()

        #expect(coordinator.pendingRoutineRoute == nil)
    }
}
