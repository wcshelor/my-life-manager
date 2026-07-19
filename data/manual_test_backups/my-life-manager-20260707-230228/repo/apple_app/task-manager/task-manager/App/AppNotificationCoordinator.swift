import Foundation
import UserNotifications

final class AppNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let notificationCenter: UNUserNotificationCenter
    private let scheduler: AlertScheduler
    private let routeCoordinator: AlertRouteCoordinator

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        scheduler: AlertScheduler,
        routeCoordinator: AlertRouteCoordinator
    ) {
        self.notificationCenter = notificationCenter
        self.scheduler = scheduler
        self.routeCoordinator = routeCoordinator
        super.init()
        self.notificationCenter.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center

        guard AlertNotificationContext.decode(from: notification.request.content.userInfo) != nil else {
            completionHandler([])
            return
        }

        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center

        Task { @MainActor in
            await self.handle(response: response)
            completionHandler()
        }
    }

    @MainActor
    private func handle(response: UNNotificationResponse) async {
        guard let context = AlertNotificationContext.decode(from: response.notification.request.content.userInfo) else {
            return
        }

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier,
             AlertActionKind.primaryRoutineAction.rawValue:
            routeCoordinator.open(target: context.target)
        case AlertActionKind.snooze.rawValue:
            do {
                try await scheduler.scheduleSnooze(from: context)
            } catch {
                // Notification scheduling failures should not block route delivery.
            }
        default:
            break
        }
    }
}
