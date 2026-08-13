import Foundation
import SwiftData

@Model
final class AppSettingsRecord {
    static let singletonID = "app-settings"

    var id: String = AppSettingsRecord.singletonID
    var excludedReadCalendarTitlesText: String = ""
    var writeCalendarIdentifier: String = ""
    var writeCalendarTitle: String = ""
    var hiddenHomeWidgetKindsText: String = ""
    var minimumGapMinutes: Int = AppSettings.mvpDefault.minimumGapMinutes
    var notificationsEnabled: Bool = AppSettings.mvpDefault.notificationsEnabled
    var notificationQuietHoursEnabled: Bool = AppSettings.mvpDefault.notificationQuietHoursEnabled
    var notificationQuietHoursStartHour: Int = AppSettings.mvpDefault.notificationQuietHoursStart.hour
    var notificationQuietHoursStartMinute: Int = AppSettings.mvpDefault.notificationQuietHoursStart.minute
    var notificationQuietHoursEndHour: Int = AppSettings.mvpDefault.notificationQuietHoursEnd.hour
    var notificationQuietHoursEndMinute: Int = AppSettings.mvpDefault.notificationQuietHoursEnd.minute
    var notificationMaxNudgesPerDay: Int = AppSettings.mvpDefault.notificationMaxNudgesPerDay
    var notificationDefaultPrivacyModeRawValue: String = AppSettings.mvpDefault.notificationDefaultPrivacyMode.rawValue
    var notificationDefaultUrgencyRawValue: String = AppSettings.mvpDefault.notificationDefaultUrgency.rawValue
    var notificationAvoidCalendarBusyPeriods: Bool = AppSettings.mvpDefault.notificationAvoidCalendarBusyPeriods
    var defaultAssumedDurationMinutes: Int = AppSettings.mvpDefault.defaultAssumedDurationMinutes
    var plannerSuggestionCap: Int = AppSettings.mvpDefault.plannerSuggestionCap

    init(
        id: String = AppSettingsRecord.singletonID,
        settings: AppSettings
    ) {
        self.id = id
        self.excludedReadCalendarTitlesText = Self.encodeTitles(settings.excludedReadCalendarTitles)
        self.writeCalendarIdentifier = settings.writeCalendarIdentifier
        self.writeCalendarTitle = settings.writeCalendarTitle
        self.hiddenHomeWidgetKindsText = Self.encodeTitles(settings.hiddenHomeWidgetKinds)
        self.minimumGapMinutes = settings.minimumGapMinutes
        self.defaultAssumedDurationMinutes = settings.defaultAssumedDurationMinutes
        self.plannerSuggestionCap = settings.plannerSuggestionCap
    }

    var settings: AppSettings {
        AppSettings(
            excludedReadCalendarTitles: Self.decodeTitles(excludedReadCalendarTitlesText),
            writeCalendarIdentifier: writeCalendarIdentifier,
            writeCalendarTitle: writeCalendarTitle,
            hiddenHomeWidgetKinds: Self.decodeTitles(hiddenHomeWidgetKindsText),
            minimumGapMinutes: minimumGapMinutes,
            notificationsEnabled: notificationsEnabled,
            notificationQuietHoursEnabled: notificationQuietHoursEnabled,
            notificationQuietHoursStart: AlertTimeOfDay(
                hour: notificationQuietHoursStartHour,
                minute: notificationQuietHoursStartMinute
            ),
            notificationQuietHoursEnd: AlertTimeOfDay(
                hour: notificationQuietHoursEndHour,
                minute: notificationQuietHoursEndMinute
            ),
            notificationMaxNudgesPerDay: notificationMaxNudgesPerDay,
            notificationDefaultPrivacyMode: AlertPrivacyMode(
                rawValue: notificationDefaultPrivacyModeRawValue
            ) ?? .full,
            notificationDefaultUrgency: AlertUrgency(
                rawValue: notificationDefaultUrgencyRawValue
            ) ?? .normal,
            notificationAvoidCalendarBusyPeriods: notificationAvoidCalendarBusyPeriods,
            defaultAssumedDurationMinutes: defaultAssumedDurationMinutes,
            plannerSuggestionCap: plannerSuggestionCap
        )
    }

    func update(from settings: AppSettings) {
        excludedReadCalendarTitlesText = Self.encodeTitles(settings.excludedReadCalendarTitles)
        writeCalendarIdentifier = settings.writeCalendarIdentifier
        writeCalendarTitle = settings.writeCalendarTitle
        hiddenHomeWidgetKindsText = Self.encodeTitles(settings.hiddenHomeWidgetKinds)
        minimumGapMinutes = settings.minimumGapMinutes
        notificationsEnabled = settings.notificationsEnabled
        notificationQuietHoursEnabled = settings.notificationQuietHoursEnabled
        notificationQuietHoursStartHour = settings.notificationQuietHoursStart.hour
        notificationQuietHoursStartMinute = settings.notificationQuietHoursStart.minute
        notificationQuietHoursEndHour = settings.notificationQuietHoursEnd.hour
        notificationQuietHoursEndMinute = settings.notificationQuietHoursEnd.minute
        notificationMaxNudgesPerDay = settings.notificationMaxNudgesPerDay
        notificationDefaultPrivacyModeRawValue = settings.notificationDefaultPrivacyMode.rawValue
        notificationDefaultUrgencyRawValue = settings.notificationDefaultUrgency.rawValue
        notificationAvoidCalendarBusyPeriods = settings.notificationAvoidCalendarBusyPeriods
        defaultAssumedDurationMinutes = settings.defaultAssumedDurationMinutes
        plannerSuggestionCap = settings.plannerSuggestionCap
    }

    private static func encodeTitles(_ titles: [String]) -> String {
        titles.joined(separator: "\n")
    }

    private static func decodeTitles(_ text: String) -> [String] {
        text
            .split(separator: "\n")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
