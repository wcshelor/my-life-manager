import Foundation
import UserNotifications

private enum AlertModelText {
    static func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanedOptional(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let cleaned = cleaned(text)
        return cleaned.isEmpty ? nil : cleaned
    }
}

nonisolated enum AlertUrgency: String, CaseIterable, Codable, Sendable {
    case normal
    case timeSensitive

    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .timeSensitive:
            return "Time Sensitive"
        }
    }

    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .normal:
            return .active
        case .timeSensitive:
            return .timeSensitive
        }
    }
}

nonisolated enum AlertPrivacyMode: String, CaseIterable, Codable, Sendable {
    case full
    case titleOnly

    var displayName: String {
        switch self {
        case .full:
            return "Full"
        case .titleOnly:
            return "Title Only"
        }
    }
}

nonisolated enum AlertActionKind: String, CaseIterable, Codable, Sendable {
    case primaryRoutineAction
    case snooze

    static let canonicalOrder: [AlertActionKind] = [.primaryRoutineAction, .snooze]

    var displayTitle: String {
        switch self {
        case .primaryRoutineAction:
            return "Open Routine"
        case .snooze:
            return "Snooze"
        }
    }
}

nonisolated struct AlertAction: Identifiable, Equatable, Codable, Sendable {
    let kind: AlertActionKind

    var id: String {
        kind.rawValue
    }

    var displayTitle: String {
        kind.displayTitle
    }

    init(kind: AlertActionKind) {
        self.kind = kind
    }
}

nonisolated extension AlertAction {
    static let primaryRoutineAction = AlertAction(kind: .primaryRoutineAction)
    static let snooze = AlertAction(kind: .snooze)

    static let canonical: [AlertAction] = [.primaryRoutineAction, .snooze]
}

nonisolated enum AlertRecurrence: Equatable, Codable, Sendable {
    case daily
    case weekdays([RoutineWeekday])

    var normalized: AlertRecurrence {
        switch self {
        case .daily:
            return .daily
        case .weekdays(let weekdays):
            let normalizedWeekdays = weekdays
                .reduce(into: [RoutineWeekday]()) { result, weekday in
                    guard result.contains(weekday) == false else {
                        return
                    }
                    result.append(weekday)
                }
                .sorted { $0.rawValue < $1.rawValue }

            return normalizedWeekdays.isEmpty ? .daily : .weekdays(normalizedWeekdays)
        }
    }

    var weekdays: [RoutineWeekday] {
        switch normalized {
        case .daily:
            return []
        case .weekdays(let weekdays):
            return weekdays
        }
    }

    var displaySummary: String {
        switch normalized {
        case .daily:
            return "Daily"
        case .weekdays(let weekdays):
            return weekdays.map(\.shortName).joined(separator: ", ")
        }
    }

    func calendarDateComponents(hour: Int, minute: Int) -> [DateComponents] {
        switch normalized {
        case .daily:
            return [
                DateComponents(hour: hour, minute: minute)
            ]
        case .weekdays(let weekdays):
            return weekdays.map { weekday in
                DateComponents(hour: hour, minute: minute, weekday: weekday.rawValue)
            }
        }
    }
}

nonisolated struct AlertFixedTimeTrigger: Equatable, Codable, Sendable {
    var hour: Int
    var minute: Int
    var recurrence: AlertRecurrence

    init(
        hour: Int,
        minute: Int,
        recurrence: AlertRecurrence = .daily
    ) {
        self.hour = Self.normalizedHour(hour)
        self.minute = Self.normalizedMinute(minute)
        self.recurrence = recurrence.normalized
    }

    var isDaily: Bool {
        recurrence.normalized == .daily
    }

    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    var timeSummary: String {
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }

    var scheduleSummary: String {
        "\(recurrence.displaySummary) at \(timeSummary)"
    }

    var calendarDateComponents: [DateComponents] {
        recurrence.calendarDateComponents(hour: hour, minute: minute)
    }

    private static func normalizedHour(_ hour: Int) -> Int {
        min(max(hour, 0), 23)
    }

    private static func normalizedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 59)
    }
}

nonisolated enum AlertTrigger: Equatable, Codable, Sendable {
    case fixedTime(AlertFixedTimeTrigger)

    var fixedTime: AlertFixedTimeTrigger? {
        guard case let .fixedTime(trigger) = self else {
            return nil
        }

        return trigger
    }

    var scheduleSummary: String {
        switch self {
        case .fixedTime(let trigger):
            return trigger.scheduleSummary
        }
    }

    var calendarDateComponents: [DateComponents] {
        switch self {
        case .fixedTime(let trigger):
            return trigger.calendarDateComponents
        }
    }

    var normalized: AlertTrigger {
        switch self {
        case .fixedTime(let trigger):
            return .fixedTime(trigger)
        }
    }
}

nonisolated enum AlertTarget: Equatable, Codable, Sendable {
    case openRoutine(UUID)
    case startRoutine(UUID)

    var routineID: UUID {
        switch self {
        case .openRoutine(let routineID):
            return routineID
        case .startRoutine(let routineID):
            return routineID
        }
    }

    var displayTitle: String {
        switch self {
        case .openRoutine:
            return "Open Routine"
        case .startRoutine:
            return "Start Routine"
        }
    }

    var mvpRoutingTarget: AlertTarget {
        switch self {
        case .openRoutine:
            return self
        case .startRoutine(let routineID):
            // TODO: If a dedicated routine-session start path becomes cleanly available,
            // route there instead of treating startRoutine as an openRoutine alias.
            return .openRoutine(routineID)
        }
    }
}

nonisolated struct AlertNotificationPresentation: Equatable, Sendable {
    let title: String
    let body: String
}

nonisolated struct AlertNotificationContext: Codable, Equatable, Sendable {
    static let userInfoKey = "alertContext"

    let templateID: UUID
    let notificationTitle: String
    let notificationBody: String
    let target: AlertTarget
    let urgency: AlertUrgency
    let snoozeMinutes: Int
    let maxSnoozes: Int
    let snoozeCount: Int

    init(
        templateID: UUID,
        notificationTitle: String,
        notificationBody: String,
        target: AlertTarget,
        urgency: AlertUrgency,
        snoozeMinutes: Int,
        maxSnoozes: Int,
        snoozeCount: Int = 0
    ) {
        self.templateID = templateID
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
        self.target = target
        self.urgency = urgency
        self.snoozeMinutes = max(1, snoozeMinutes)
        self.maxSnoozes = max(1, maxSnoozes)
        self.snoozeCount = max(0, snoozeCount)
    }

    var canSnoozeAgain: Bool {
        snoozeCount < maxSnoozes
    }

    var nextSnoozeCount: Int {
        snoozeCount + 1
    }

    func incrementedForSnooze() -> AlertNotificationContext {
        AlertNotificationContext(
            templateID: templateID,
            notificationTitle: notificationTitle,
            notificationBody: notificationBody,
            target: target,
            urgency: urgency,
            snoozeMinutes: snoozeMinutes,
            maxSnoozes: maxSnoozes,
            snoozeCount: nextSnoozeCount
        )
    }

    func userInfo() -> [AnyHashable: Any] {
        guard let data = try? JSONEncoder().encode(self) else {
            return [:]
        }

        return [
            Self.userInfoKey: data
        ]
    }

    static func decode(from userInfo: [AnyHashable: Any]) -> AlertNotificationContext? {
        guard let data = userInfo[Self.userInfoKey] as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AlertNotificationContext.self, from: data)
    }
}

nonisolated struct AlertTemplate: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var title: String
    var target: AlertTarget
    var trigger: AlertTrigger
    var urgency: AlertUrgency
    var privacyMode: AlertPrivacyMode
    var actions: [AlertAction]
    var isEnabled: Bool
    var snoozeMinutes: Int
    var maxSnoozes: Int
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        target: AlertTarget,
        trigger: AlertTrigger,
        urgency: AlertUrgency = .normal,
        privacyMode: AlertPrivacyMode = .full,
        actions: [AlertAction] = AlertAction.canonical,
        isEnabled: Bool = true,
        snoozeMinutes: Int = 15,
        maxSnoozes: Int = 3,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = AlertModelText.cleaned(title)
        self.target = target
        self.trigger = trigger.normalized
        self.urgency = urgency
        self.privacyMode = privacyMode
        self.actions = Self.normalizedActions(actions)
        self.isEnabled = isEnabled
        self.snoozeMinutes = max(1, snoozeMinutes)
        self.maxSnoozes = max(1, maxSnoozes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var routineID: UUID {
        target.routineID
    }

    var scheduleSummary: String {
        "\(trigger.scheduleSummary) · \(target.displayTitle)"
    }

    var notificationPresentation: AlertNotificationPresentation {
        switch privacyMode {
        case .full:
            return AlertNotificationPresentation(title: title, body: scheduleSummary)
        case .titleOnly:
            return AlertNotificationPresentation(
                title: title,
                body: "Open the app to view this Banner."
            )
        }
    }

    func notificationContext(snoozeCount: Int = 0) -> AlertNotificationContext {
        let presentation = notificationPresentation
        return AlertNotificationContext(
            templateID: id,
            notificationTitle: presentation.title,
            notificationBody: presentation.body,
            target: target.mvpRoutingTarget,
            urgency: urgency,
            snoozeMinutes: snoozeMinutes,
            maxSnoozes: maxSnoozes,
            snoozeCount: snoozeCount
        )
    }

    var baseNotificationIdentifier: String {
        "banner.\(id.uuidString)"
    }

    var dailyNotificationIdentifier: String {
        "\(baseNotificationIdentifier).daily"
    }

    func weekdayNotificationIdentifier(for weekday: RoutineWeekday) -> String {
        "\(baseNotificationIdentifier).weekday.\(weekday.rawValue)"
    }

    var snoozeNotificationIdentifier: String {
        "\(baseNotificationIdentifier).snooze"
    }

    var recurringNotificationIdentifiers: [String] {
        switch trigger {
        case .fixedTime(let fixedTime):
            switch fixedTime.recurrence.normalized {
            case .daily:
                return [dailyNotificationIdentifier]
            case .weekdays(let weekdays):
                return weekdays.map { weekdayNotificationIdentifier(for: $0) }
            }
        }
    }

    static func normalizedActions(_ actions: [AlertAction]) -> [AlertAction] {
        _ = actions
        return AlertAction.canonical
    }
}

nonisolated enum NotificationCategoryIdentifier {
    static let fixedTimePrimaryOnly = "banner.fixedTime.primaryOnly"
    static let fixedTimePrimaryAndSnooze = "banner.fixedTime.primaryAndSnooze"
}
