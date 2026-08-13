import Foundation
import UserNotifications

@MainActor
protocol AlertNotificationCenter: AnyObject {
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
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

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
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

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        []
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        _ = identifiers
    }
}

@MainActor
final class AlertScheduler {
    private let notificationCenter: any AlertNotificationCenter
    private let settingsRepository: (any SettingsRepository)?
    private let calendarReader: (any CalendarReading)?
    private let planner: AlertTriggerPlanner
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date

    init() {
        self.notificationCenter = LiveAlertNotificationCenter()
        self.settingsRepository = nil
        self.calendarReader = nil
        self.planner = AlertTriggerPlanner()
        self.calendar = .current
        self.nowProvider = Date.init
        self.notificationCenter.setNotificationCategories(Self.notificationCategories)
    }

    init(
        notificationCenter: any AlertNotificationCenter,
        settingsRepository: (any SettingsRepository)? = nil,
        calendarReader: (any CalendarReading)? = nil,
        planner: AlertTriggerPlanner = AlertTriggerPlanner(),
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.notificationCenter = notificationCenter
        self.settingsRepository = settingsRepository
        self.calendarReader = calendarReader
        self.planner = planner
        self.calendar = calendar
        self.nowProvider = nowProvider
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
        let preferences = currentNotificationPreferences()
        guard template.isEnabled, preferences.notificationsEnabled else {
            try await cancel(templateID: template.id)
            return
        }

        let now = nowProvider()
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let scheduledCountByDay = Self.scheduledCountByDay(
            from: pendingRequests.filter { $0.identifier.hasPrefix(template.baseNotificationIdentifier) == false },
            calendar: calendar
        )
        let busyIntervals = await busyIntervals(
            for: template,
            preferences: preferences,
            now: now
        )
        let plannedRequests = planner.plannedRequests(
            for: template,
            preferences: preferences,
            now: now,
            calendar: calendar,
            busyIntervals: busyIntervals,
            scheduledCountByDay: scheduledCountByDay
        )

        try await cancel(templateID: template.id)

        let context = template.notificationContext()
        for plannedRequest in plannedRequests {
            let content = makeContent(from: context)
            let request = UNNotificationRequest(
                identifier: plannedRequest.identifier,
                content: content,
                trigger: plannedRequest.trigger
            )
            try await notificationCenter.add(request)
        }
    }

    func reschedule(_ template: AlertTemplate) async throws {
        try await schedule(template)
    }

    func cancel(templateID: UUID) async throws {
        let identifiers = await notificationIdentifiers(for: templateID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
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

    private func notificationIdentifiers(for templateID: UUID) async -> [String] {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let pendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix("banner.\(templateID.uuidString)") }
        return Array(Set(Self.legacyNotificationIdentifiers(for: templateID) + pendingIdentifiers)).sorted()
    }

    private func currentNotificationPreferences() -> AlertNotificationPreferences {
        guard let settingsRepository else {
            return .defaults
        }

        return (try? settingsRepository.loadSettings().notificationPreferences) ?? .defaults
    }

    private func busyIntervals(
        for template: AlertTemplate,
        preferences: AlertNotificationPreferences,
        now: Date
    ) async -> [DateInterval] {
        guard preferences.avoidCalendarBusyPeriods,
              let calendarReader,
              let window = busyIntervalFetchWindow(for: template, now: now) else {
            return []
        }

        do {
            let events = try await calendarReader.fetchEvents(in: window)
            return events.map(\.interval)
        } catch {
            return []
        }
    }

    private func busyIntervalFetchWindow(
        for template: AlertTemplate,
        now: Date
    ) -> DateInterval? {
        switch template.trigger {
        case .fixedTime:
            let end = calendar.date(byAdding: .day, value: AlertTriggerPlanner.fixedTimeSchedulingDays + 1, to: now)
                ?? now.addingTimeInterval(Double(AlertTriggerPlanner.fixedTimeSchedulingDays + 1) * 86_400)
            return DateInterval(start: now, end: end)
        case .oneShot(let trigger):
            let start = min(now, trigger.date)
            let end = max(now.addingTimeInterval(86_400), trigger.date.addingTimeInterval(86_400))
            return DateInterval(start: start, end: end)
        case .relative(let trigger):
            let scheduledDate = trigger.scheduledDate
            let start = min(now, scheduledDate)
            let end = max(now.addingTimeInterval(86_400), scheduledDate.addingTimeInterval(86_400))
            return DateInterval(start: start, end: end)
        case .randomDailyWindow:
            let end = calendar.date(byAdding: .day, value: AlertTriggerPlanner.randomWindowSchedulingDays + 1, to: now)
                ?? now.addingTimeInterval(Double(AlertTriggerPlanner.randomWindowSchedulingDays + 1) * 86_400)
            return DateInterval(start: now, end: end)
        }
    }

    private static func scheduledCountByDay(
        from requests: [UNNotificationRequest],
        calendar: Calendar
    ) -> [Date: Int] {
        requests.reduce(into: [Date: Int]()) { counts, request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let scheduledDate = trigger.nextTriggerDate() else {
                return
            }

            counts[calendar.startOfDay(for: scheduledDate), default: 0] += 1
        }
    }

    private static func legacyNotificationIdentifiers(for templateID: UUID) -> [String] {
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
            "\(base).oneShot",
            "\(base).relative",
            "\(base).snooze"
        ]
    }

    private static func snoozeNotificationIdentifier(for templateID: UUID) -> String {
        "banner.\(templateID.uuidString).snooze"
    }
}
