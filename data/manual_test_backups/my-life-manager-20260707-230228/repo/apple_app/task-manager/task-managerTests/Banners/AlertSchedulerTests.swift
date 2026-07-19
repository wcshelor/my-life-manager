import Foundation
import UserNotifications
import Testing
@testable import task_manager

@MainActor
struct AlertSchedulerTests {
    @Test func scheduleFixedTimeRequestUsesCalendarTrigger() async throws {
        let center = FakeNotificationCenter()
        let scheduler = AlertScheduler(notificationCenter: center)
        let template = makeTemplate()

        try await scheduler.schedule(template)

        #expect(center.removedIdentifiers.contains(template.dailyNotificationIdentifier))
        #expect(center.addedRequests.count == 1)

        let request = try #require(center.addedRequests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)

        #expect(request.identifier == template.dailyNotificationIdentifier)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 7)
        #expect(trigger.dateComponents.minute == 30)
        #expect(request.content.categoryIdentifier == NotificationCategoryIdentifier.fixedTimePrimaryAndSnooze)
    }

    @Test func timeSensitiveMappingUsesTimeSensitiveInterruptionLevel() async throws {
        let center = FakeNotificationCenter()
        let scheduler = AlertScheduler(notificationCenter: center)
        let template = makeTemplate(urgency: .timeSensitive)

        try await scheduler.schedule(template)

        let request = try #require(center.addedRequests.first)
        #expect(request.content.interruptionLevel == .timeSensitive)
    }

    @Test func cancelRemovesRecurringAndSnoozeRequests() async throws {
        let center = FakeNotificationCenter()
        let scheduler = AlertScheduler(notificationCenter: center)
        let template = makeTemplate(recurrence: .weekdays([.monday, .wednesday]))

        try await scheduler.cancel(templateID: template.id)

        #expect(center.removedIdentifiers.contains(template.weekdayNotificationIdentifier(for: .monday)))
        #expect(center.removedIdentifiers.contains(template.weekdayNotificationIdentifier(for: .wednesday)))
        #expect(center.removedIdentifiers.contains(template.snoozeNotificationIdentifier))
        #expect(center.removedIdentifiers.count == 9)
    }

    @Test func snoozeRequestGenerationUsesUNTimeIntervalNotificationTriggerAndStopsAtMaxCount() async throws {
        let center = FakeNotificationCenter()
        let scheduler = AlertScheduler(notificationCenter: center)
        let template = makeTemplate(maxSnoozes: 1)

        try await scheduler.scheduleSnooze(from: template.notificationContext())

        #expect(center.addedRequests.count == 1)

        let request = try #require(center.addedRequests.first)
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        let scheduledContext = try #require(AlertNotificationContext.decode(from: request.content.userInfo))

        #expect(request.identifier == template.snoozeNotificationIdentifier)
        #expect(trigger.timeInterval == 900)
        #expect(request.content.categoryIdentifier == NotificationCategoryIdentifier.fixedTimePrimaryOnly)
        #expect(scheduledContext.snoozeCount == 1)

        center.addedRequests.removeAll()

        try await scheduler.scheduleSnooze(from: scheduledContext)

        #expect(center.addedRequests.isEmpty)
    }
}

@MainActor
private final class FakeNotificationCenter: AlertNotificationCenter {
    private(set) var categories: Set<UNNotificationCategory> = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var authorizationOptions: UNAuthorizationOptions?
    private(set) var authorizationCallCount = 0
    var authorizationResult = true

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationCallCount += 1
        authorizationOptions = options
        return authorizationResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}

@MainActor
private func makeTemplate(
    urgency: AlertUrgency = .normal,
    recurrence: AlertRecurrence = .daily,
    maxSnoozes: Int = 1,
    snoozeMinutes: Int = 15
) -> AlertTemplate {
    let routineID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174300")!
    return AlertTemplate(
        id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174301")!,
        title: "Morning Banner",
        target: .openRoutine(routineID),
        trigger: .fixedTime(
            AlertFixedTimeTrigger(
                hour: 7,
                minute: 30,
                recurrence: recurrence
            )
        ),
        urgency: urgency,
        privacyMode: .full,
        isEnabled: true,
        snoozeMinutes: snoozeMinutes,
        maxSnoozes: maxSnoozes,
        createdAt: Date(timeIntervalSince1970: 1_000),
        updatedAt: Date(timeIntervalSince1970: 1_000)
    )
}
