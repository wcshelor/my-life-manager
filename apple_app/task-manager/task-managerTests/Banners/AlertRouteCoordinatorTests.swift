import Foundation
import Testing
@testable import task_manager

@MainActor
struct AlertRouteCoordinatorTests {
    @Test func routeCoordinatorTreatsRoutineTargetsAsPendingRoutes() {
        let coordinator = AlertRouteCoordinator()
        let routineID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174400")!

        coordinator.open(target: .startRoutine(routineID))

        #expect(coordinator.pendingRoute?.target == .openRoutine(routineID))
        #expect(coordinator.pendingRoute != nil)

        coordinator.clearPendingRoute()

        #expect(coordinator.pendingRoute == nil)
    }
}
