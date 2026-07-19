import Foundation
import UserNotifications
import Testing
@testable import task_manager

struct AlertModelTests {
    @Test func fixedTimeTriggerNormalizationClampsHourMinuteAndWeekdays() {
        let trigger = AlertFixedTimeTrigger(
            hour: 27,
            minute: -3,
            recurrence: .weekdays([.friday, .monday, .monday])
        )

        #expect(trigger.hour == 23)
        #expect(trigger.minute == 0)
        #expect(trigger.recurrence == .weekdays([.monday, .friday]))
        #expect(trigger.timeSummary == "11:00 PM")
    }

    @Test func urgencyMappingUsesActiveAndTimeSensitiveLevels() {
        #expect(AlertUrgency.normal.interruptionLevel == .active)
        #expect(AlertUrgency.timeSensitive.interruptionLevel == .timeSensitive)
    }

    @Test func privacyRenderingUsesCentralCopyForFullAndTitleOnly() {
        let routineID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174100")!
        let baseTrigger = AlertFixedTimeTrigger(hour: 7, minute: 30)
        let fullTemplate = AlertTemplate(
            title: "Morning Banner",
            target: .openRoutine(routineID),
            trigger: .fixedTime(baseTrigger),
            privacyMode: .full
        )
        let hiddenTemplate = AlertTemplate(
            title: "Morning Banner",
            target: .openRoutine(routineID),
            trigger: .fixedTime(baseTrigger),
            privacyMode: .titleOnly
        )

        #expect(fullTemplate.notificationPresentation.title == "Morning Banner")
        #expect(fullTemplate.notificationPresentation.body.contains("Daily"))
        #expect(fullTemplate.notificationPresentation.body.contains("Open Routine"))
        #expect(hiddenTemplate.notificationPresentation.title == "Morning Banner")
        #expect(hiddenTemplate.notificationPresentation.body == "Open the app to view this Banner.")
    }

    @Test func actionDedupingValidationKeepsTheFiniteCatalog() {
        let routineID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174101")!
        let template = AlertTemplate(
            title: "Night Banner",
            target: .openRoutine(routineID),
            trigger: .fixedTime(AlertFixedTimeTrigger(hour: 21, minute: 0)),
            actions: [.snooze, .snooze]
        )

        #expect(template.actions.map(\.kind) == [.primaryRoutineAction, .snooze])
        #expect(template.actions.map(\.displayTitle) == ["Open Routine", "Snooze"])
    }
}
