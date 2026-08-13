import SwiftData
import Testing
@testable import task_manager

struct SwiftDataSettingsRepositoryTests {
    @Test @MainActor func settingsRepositorySeedsMVPDefaults() throws {
        let repository = try makeRepository()

        let settings = try repository.loadSettings()

        #expect(settings == .mvpDefault)
    }

    @Test @MainActor func settingsRepositoryPersistsUpdates() throws {
        let repository = try makeRepository()
        let updatedSettings = AppSettings(
            excludedReadCalendarTitles: ["Birthdays", "Holidays"],
            writeCalendarIdentifier: "planner",
            writeCalendarTitle: "Important",
            hiddenHomeWidgetKinds: ["tasksModule", "healthModule"],
            minimumGapMinutes: 20,
            defaultAssumedDurationMinutes: 45,
            plannerSuggestionCap: 7
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings == updatedSettings)
    }

    @Test @MainActor func settingsRepositoryNormalizesInvalidDefaultAssumedDurationOnSave() throws {
        let repository = try makeRepository()
        let updatedSettings = AppSettings(
            excludedReadCalendarTitles: [],
            writeCalendarIdentifier: "planner",
            writeCalendarTitle: "Important",
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 37,
            plannerSuggestionCap: 5
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings.defaultAssumedDurationMinutes == 30)
    }

    @Test @MainActor func settingsRepositoryPersistsHiddenHomeWidgetKinds() throws {
        let repository = try makeRepository()
        let updatedSettings = AppSettings(
            excludedReadCalendarTitles: [],
            writeCalendarIdentifier: "",
            writeCalendarTitle: "Tasks",
            hiddenHomeWidgetKinds: ["tasksModule", "healthModule", "tasksModule"],
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 30,
            plannerSuggestionCap: 5
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings.hiddenHomeWidgetKinds == ["healthModule", "tasksModule"])
    }

    @Test @MainActor func settingsRepositoryPersistsNotificationPreferences() throws {
        let repository = try makeRepository()
        let updatedSettings = AppSettings(
            excludedReadCalendarTitles: [],
            writeCalendarIdentifier: "",
            writeCalendarTitle: "Tasks",
            minimumGapMinutes: 15,
            notificationsEnabled: false,
            notificationQuietHoursEnabled: true,
            notificationQuietHoursStart: AlertTimeOfDay(hour: 21, minute: 30),
            notificationQuietHoursEnd: AlertTimeOfDay(hour: 6, minute: 45),
            notificationMaxNudgesPerDay: 2,
            notificationDefaultPrivacyMode: .titleOnly,
            notificationDefaultUrgency: .timeSensitive,
            notificationAvoidCalendarBusyPeriods: true,
            defaultAssumedDurationMinutes: 30,
            plannerSuggestionCap: 5
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings.notificationsEnabled == false)
        #expect(reloadedSettings.notificationQuietHoursEnabled)
        #expect(reloadedSettings.notificationQuietHoursStart == AlertTimeOfDay(hour: 21, minute: 30))
        #expect(reloadedSettings.notificationQuietHoursEnd == AlertTimeOfDay(hour: 6, minute: 45))
        #expect(reloadedSettings.notificationMaxNudgesPerDay == 2)
        #expect(reloadedSettings.notificationDefaultPrivacyMode == .titleOnly)
        #expect(reloadedSettings.notificationDefaultUrgency == .timeSensitive)
        #expect(reloadedSettings.notificationAvoidCalendarBusyPeriods)
    }

    @Test @MainActor func settingsRepositoryBackfillsMissingHiddenHomeWidgetKinds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let record = AppSettingsRecord(settings: .mvpDefault)
        record.hiddenHomeWidgetKindsText = ""
        container.mainContext.insert(record)
        try container.mainContext.save()

        let repository = SwiftDataSettingsRepository(modelContainer: container)
        let settings = try repository.loadSettings()

        #expect(settings.hiddenHomeWidgetKinds.isEmpty)
    }

    @Test @MainActor func settingsRepositoryRepairsLegacyInvalidDefaultAssumedDurationOnLoad() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let record = AppSettingsRecord(settings: .mvpDefault)
        record.defaultAssumedDurationMinutes = 20
        container.mainContext.insert(record)
        try container.mainContext.save()

        let repository = SwiftDataSettingsRepository(modelContainer: container)
        let settings = try repository.loadSettings()
        let persistedRecord = try container.mainContext
            .fetch(FetchDescriptor<AppSettingsRecord>())
            .first { $0.id == AppSettingsRecord.singletonID }

        #expect(settings.defaultAssumedDurationMinutes == 30)
        #expect(persistedRecord?.defaultAssumedDurationMinutes == 30)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataSettingsRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataSettingsRepository(modelContainer: container)
    }
}
