import Foundation

@MainActor
struct RoutineAlertTemplateFactory {
    private let settingsRepository: any SettingsRepository

    init(settingsRepository: any SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    func makeNewTemplateDraft(from routines: [Routine]) -> AlertTemplate? {
        guard let routine = routines.first else {
            return nil
        }

        let settings = (try? settingsRepository.loadSettings()) ?? .mvpDefault
        return AlertTemplate(
            title: "\(routine.name) Banner",
            target: .openRoutine(routine.id),
            trigger: defaultTrigger(for: routine),
            urgency: settings.notificationDefaultUrgency,
            privacyMode: settings.notificationDefaultPrivacyMode,
            isEnabled: true
        )
    }

    func defaultTrigger(for routine: Routine) -> AlertTrigger {
        let lowercasedName = routine.name.lowercased()
        let timeOfDay: AlertTimeOfDay

        if lowercasedName.contains("night")
            || lowercasedName.contains("evening")
            || lowercasedName.contains("bed") {
            timeOfDay = AlertTimeOfDay(hour: 21, minute: 0)
        } else {
            timeOfDay = AlertTimeOfDay(hour: 7, minute: 30)
        }

        return .fixedTime(
            AlertFixedTimeTrigger(
                hour: timeOfDay.hour,
                minute: timeOfDay.minute,
                recurrence: .daily
            )
        )
    }
}
