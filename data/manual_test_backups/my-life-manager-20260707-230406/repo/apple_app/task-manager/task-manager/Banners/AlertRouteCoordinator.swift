import Foundation
import Combine

@MainActor
final class AlertRouteCoordinator: ObservableObject {
    @Published var pendingRoutineRoute: AlertPendingRoutineRoute?

    func openRoutine(_ routineID: UUID) {
        pendingRoutineRoute = AlertPendingRoutineRoute(routineID: routineID)
    }

    func open(target: AlertTarget) {
        openRoutine(target.mvpRoutingTarget.routineID)
    }

    func clearPendingRoutineRoute() {
        pendingRoutineRoute = nil
    }
}

nonisolated struct AlertPendingRoutineRoute: Identifiable, Equatable, Sendable {
    let id: UUID
    let routineID: UUID

    init(id: UUID = UUID(), routineID: UUID) {
        self.id = id
        self.routineID = routineID
    }
}
