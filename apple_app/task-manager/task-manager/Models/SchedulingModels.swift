import Foundation

nonisolated enum ScheduledBlockStatus: String, CaseIterable, Codable, Sendable {
    case proposed
    case accepted
    case rejected
    case canceled
    case completed
    case deletedExternally
}

nonisolated enum CalendarLinkState: String, CaseIterable, Codable, Sendable {
    case notWritten
    case writePending
    case linked
    case movedExternally
    case deletedExternally
    case identifierStale
    case syncError
}

nonisolated struct ScheduledBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    var taskID: UUID
    var start: Date
    var end: Date
    var status: ScheduledBlockStatus
    var calendarLinkState: CalendarLinkState
    var calendarEventIdentifier: String?
    var calendarTitle: String?
    var eventTitleSnapshot: String?
    let createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?
    var syncErrorMessage: String?
    var isAllDay: Bool

    init(
        id: UUID = UUID(),
        taskID: UUID,
        start: Date,
        end: Date,
        status: ScheduledBlockStatus = .proposed,
        calendarLinkState: CalendarLinkState = .notWritten,
        calendarEventIdentifier: String? = nil,
        calendarTitle: String? = nil,
        eventTitleSnapshot: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        syncErrorMessage: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.taskID = taskID
        self.start = start
        self.end = end
        self.status = status
        self.calendarLinkState = calendarLinkState
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarTitle = calendarTitle
        self.eventTitleSnapshot = eventTitleSnapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastSyncedAt = lastSyncedAt
        self.syncErrorMessage = syncErrorMessage
        self.isAllDay = isAllDay
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    var isActivelyScheduled: Bool {
        status == .accepted && calendarLinkState != .deletedExternally
    }
}

nonisolated struct AlertNotificationPreferences: Equatable, Sendable {
    var notificationsEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursWindow: AlertDailyWindow
    var maxNudgesPerDay: Int
    var defaultPrivacyMode: AlertPrivacyMode
    var defaultUrgency: AlertUrgency
    var avoidCalendarBusyPeriods: Bool

    static let defaults = AlertNotificationPreferences(
        notificationsEnabled: AppSettings.mvpDefault.notificationsEnabled,
        quietHoursEnabled: AppSettings.mvpDefault.notificationQuietHoursEnabled,
        quietHoursWindow: AlertDailyWindow(
            start: AppSettings.mvpDefault.notificationQuietHoursStart,
            end: AppSettings.mvpDefault.notificationQuietHoursEnd
        ),
        maxNudgesPerDay: AppSettings.mvpDefault.notificationMaxNudgesPerDay,
        defaultPrivacyMode: AppSettings.mvpDefault.notificationDefaultPrivacyMode,
        defaultUrgency: AppSettings.mvpDefault.notificationDefaultUrgency,
        avoidCalendarBusyPeriods: AppSettings.mvpDefault.notificationAvoidCalendarBusyPeriods
    )
}

nonisolated struct AppSettings: Equatable, Sendable {
    static let defaultWriteCalendarTitle = "Tasks"

    var excludedReadCalendarTitles: [String]
    var writeCalendarIdentifier: String
    var writeCalendarTitle: String
    var hiddenHomeWidgetKinds: [String]
    var minimumGapMinutes: Int
    var notificationsEnabled: Bool
    var notificationQuietHoursEnabled: Bool
    var notificationQuietHoursStart: AlertTimeOfDay
    var notificationQuietHoursEnd: AlertTimeOfDay
    var notificationMaxNudgesPerDay: Int
    var notificationDefaultPrivacyMode: AlertPrivacyMode
    var notificationDefaultUrgency: AlertUrgency
    var notificationAvoidCalendarBusyPeriods: Bool
    private var storedDefaultAssumedDurationMinutes: Int
    var defaultAssumedDurationMinutes: Int {
        get {
            storedDefaultAssumedDurationMinutes
        }
        set {
            storedDefaultAssumedDurationMinutes =
                TaskDurationRules.cleanedDefaultAssumedDurationMinutes(newValue)
        }
    }
    var plannerSuggestionCap: Int

    init(
        excludedReadCalendarTitles: [String],
        writeCalendarIdentifier: String = "",
        writeCalendarTitle: String,
        hiddenHomeWidgetKinds: [String] = [],
        minimumGapMinutes: Int,
        notificationsEnabled: Bool = true,
        notificationQuietHoursEnabled: Bool = false,
        notificationQuietHoursStart: AlertTimeOfDay = AlertTimeOfDay(hour: 22, minute: 0),
        notificationQuietHoursEnd: AlertTimeOfDay = AlertTimeOfDay(hour: 7, minute: 0),
        notificationMaxNudgesPerDay: Int = 3,
        notificationDefaultPrivacyMode: AlertPrivacyMode = .full,
        notificationDefaultUrgency: AlertUrgency = .normal,
        notificationAvoidCalendarBusyPeriods: Bool = false,
        defaultAssumedDurationMinutes: Int,
        plannerSuggestionCap: Int
    ) {
        self.excludedReadCalendarTitles = excludedReadCalendarTitles
        self.writeCalendarIdentifier = Self.normalizedCalendarValue(writeCalendarIdentifier)
        self.writeCalendarTitle = Self.normalizedCalendarValue(writeCalendarTitle)
        self.hiddenHomeWidgetKinds = Self.normalizedWidgetKinds(hiddenHomeWidgetKinds)
        self.minimumGapMinutes = max(1, minimumGapMinutes)
        self.notificationsEnabled = notificationsEnabled
        self.notificationQuietHoursEnabled = notificationQuietHoursEnabled
        self.notificationQuietHoursStart = notificationQuietHoursStart
        self.notificationQuietHoursEnd = notificationQuietHoursEnd
        self.notificationMaxNudgesPerDay = max(1, notificationMaxNudgesPerDay)
        self.notificationDefaultPrivacyMode = notificationDefaultPrivacyMode
        self.notificationDefaultUrgency = notificationDefaultUrgency
        self.notificationAvoidCalendarBusyPeriods = notificationAvoidCalendarBusyPeriods
        self.storedDefaultAssumedDurationMinutes =
            TaskDurationRules.cleanedDefaultAssumedDurationMinutes(defaultAssumedDurationMinutes)
        self.plannerSuggestionCap = max(0, plannerSuggestionCap)
    }

    var hasConfiguredWriteCalendar: Bool {
        writeCalendarIdentifier.isEmpty == false
    }

    var notificationPreferences: AlertNotificationPreferences {
        AlertNotificationPreferences(
            notificationsEnabled: notificationsEnabled,
            quietHoursEnabled: notificationQuietHoursEnabled,
            quietHoursWindow: AlertDailyWindow(
                start: notificationQuietHoursStart,
                end: notificationQuietHoursEnd
            ),
            maxNudgesPerDay: notificationMaxNudgesPerDay,
            defaultPrivacyMode: notificationDefaultPrivacyMode,
            defaultUrgency: notificationDefaultUrgency,
            avoidCalendarBusyPeriods: notificationAvoidCalendarBusyPeriods
        )
    }

    static let mvpDefault = AppSettings(
        excludedReadCalendarTitles: ["Birthdays"],
        writeCalendarIdentifier: "",
        writeCalendarTitle: defaultWriteCalendarTitle,
        hiddenHomeWidgetKinds: [],
        minimumGapMinutes: 15,
        notificationsEnabled: true,
        notificationQuietHoursEnabled: false,
        notificationQuietHoursStart: AlertTimeOfDay(hour: 22, minute: 0),
        notificationQuietHoursEnd: AlertTimeOfDay(hour: 7, minute: 0),
        notificationMaxNudgesPerDay: 3,
        notificationDefaultPrivacyMode: .full,
        notificationDefaultUrgency: .normal,
        notificationAvoidCalendarBusyPeriods: false,
        defaultAssumedDurationMinutes: 30,
        plannerSuggestionCap: 5
    )

    private static func normalizedCalendarValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedWidgetKinds(_ kinds: [String]) -> [String] {
        Array(
            Set(
                kinds
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            )
        )
        .sorted()
    }
}
