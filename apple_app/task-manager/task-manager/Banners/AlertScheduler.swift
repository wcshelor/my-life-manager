import Foundation
import UserNotifications

@MainActor
protocol AlertNotificationCenter: AnyObject {
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class LiveAlertNotificationCenter: AlertNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
final class NoopAlertNotificationCenter: AlertNotificationCenter {
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        _ = categories
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        _ = options
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        _ = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        _ = identifiers
    }
}

@MainActor
final class AlertScheduler {
    private let notificationCenter: any AlertNotificationCenter

    init() {
        self.notificationCenter = LiveAlertNotificationCenter()
        self.notificationCenter.setNotificationCategories(Self.notificationCategories)
    }

    init(notificationCenter: any AlertNotificationCenter) {
        self.notificationCenter = notificationCenter
        self.notificationCenter.setNotificationCategories(Self.notificationCategories)
    }

    func requestNotificationAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [
            .alert,
            .badge,
            .sound,
            .timeSensitive
        ])
    }

    func schedule(_ template: AlertTemplate) async throws {
        guard template.isEnabled else {
            try await cancel(templateID: template.id)
            return
        }

        try await cancel(templateID: template.id)

        let context = template.notificationContext()
        for (identifier, components) in zip(template.recurringNotificationIdentifiers, template.trigger.calendarDateComponents) {
            let content = makeContent(from: context)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            try await notificationCenter.add(request)
        }
    }

    func reschedule(_ template: AlertTemplate) async throws {
        try await schedule(template)
    }

    func cancel(templateID: UUID) async throws {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Self.notificationIdentifiers(for: templateID))
    }

    func scheduleSnooze(from context: AlertNotificationContext) async throws {
        guard context.nextSnoozeCount <= context.maxSnoozes else {
            return
        }

        let snoozeContext = context.incrementedForSnooze()
        let identifier = Self.snoozeNotificationIdentifier(for: context.templateID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = makeContent(from: snoozeContext)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(snoozeContext.snoozeMinutes * 60),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try await notificationCenter.add(request)
    }

    private func makeContent(from context: AlertNotificationContext) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = context.notificationTitle
        content.body = context.notificationBody
        content.sound = .default
        content.categoryIdentifier = context.canSnoozeAgain
            ? NotificationCategoryIdentifier.fixedTimePrimaryAndSnooze
            : NotificationCategoryIdentifier.fixedTimePrimaryOnly
        content.interruptionLevel = context.urgency.interruptionLevel
        content.userInfo = context.userInfo()
        return content
    }

    private static let notificationCategories: Set<UNNotificationCategory> = {
        let primaryAction = UNNotificationAction(
            identifier: AlertActionKind.primaryRoutineAction.rawValue,
            title: AlertActionKind.primaryRoutineAction.displayTitle,
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: AlertActionKind.snooze.rawValue,
            title: AlertActionKind.snooze.displayTitle,
            options: []
        )
        return [
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.fixedTimePrimaryOnly,
                actions: [primaryAction],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.fixedTimePrimaryAndSnooze,
                actions: [primaryAction, snoozeAction],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
        ]
    }()

    private static func notificationIdentifiers(for templateID: UUID) -> [String] {
        let base = "banner.\(templateID.uuidString)"
        return [
            "\(base).daily",
            "\(base).weekday.1",
            "\(base).weekday.2",
            "\(base).weekday.3",
            "\(base).weekday.4",
            "\(base).weekday.5",
            "\(base).weekday.6",
            "\(base).weekday.7",
            "\(base).snooze"
        ]
    }

    private static func snoozeNotificationIdentifier(for templateID: UUID) -> String {
        "banner.\(templateID.uuidString).snooze"
    }
}
