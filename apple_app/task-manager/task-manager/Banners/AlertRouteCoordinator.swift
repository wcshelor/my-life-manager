import Foundation
import Combine

@MainActor
final class AlertRouteCoordinator: ObservableObject {
    @Published var pendingRoute: AlertPendingRoute?

    func openRoutine(_ routineID: UUID) {
        pendingRoute = AlertPendingRoute(target: .openRoutine(routineID))
    }

    func open(target: AlertTarget) {
        pendingRoute = AlertPendingRoute(target: target.resolvedRoutingTarget)
    }

    func clearPendingRoute() {
        pendingRoute = nil
    }
}

nonisolated struct AlertPendingRoute: Identifiable, Equatable, Sendable {
    let id: UUID
    let target: AlertTarget

    init(id: UUID = UUID(), target: AlertTarget) {
        self.id = id
        self.target = target
    }
}
