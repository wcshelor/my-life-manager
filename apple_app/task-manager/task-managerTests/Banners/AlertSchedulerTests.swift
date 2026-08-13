import Foundation
import UserNotifications
import Testing
@testable import task_manager

@MainActor
struct AlertSchedulerTests {
    @Test func scheduleFixedTimeRequestSchedulesFiniteCalendarRequests() async throws {
        let center = FakeNotificationCenter()
        let now = makeDate(year: 2026, month: 8, day: 6, hour: 6, minute: 0)
        let scheduler = AlertScheduler(
            notificationCenter: center,
            nowProvider: { now }
        )
        let template = makeTemplate()

        try await scheduler.schedule(template)

        #expect(center.addedRequests.count == AlertTriggerPlanner.fixedTimeSchedulingDays)

        let request = try #require(center.addedRequests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)

        #expect(request.identifier == template.fixedTimeNotificationIdentifier(for: now))
        #expect(trigger.repeats == false)
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
        #expect(center.removedIdentifiers.count == 11)
    }

    @Test func oneShotTriggerUsesNonRepeatingCalendarRequest() async throws {
        let center = FakeNotificationCenter()
        let scheduler = AlertScheduler(notificationCenter: center)
        let template = AlertTemplate(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174302")!,
            title: "One Shot",
            target: .openHealth,
            trigger: .oneShot(
                AlertOneShotTrigger(
                    date: Date(timeIntervalSince1970: 2_000_000)
                )
            ),
            urgency: .normal,
            privacyMode: .full
        )

        try await scheduler.schedule(template)

        let request = try #require(center.addedRequests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        #expect(request.identifier == template.oneShotNotificationIdentifier)
    }

    @Test func randomDailyWindowTriggerSchedulesFiniteOneShotRequests() async throws {
        let center = FakeNotificationCenter()
        let scheduler = AlertScheduler(
            notificationCenter: center,
            nowProvider: { Date(timeIntervalSince1970: 1_000_000) }
        )
        let template = AlertTemplate(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174303")!,
            title: "Random Window",
            target: .openPeopleStudy,
            trigger: .randomDailyWindow(
                AlertRandomDailyWindowTrigger(
                    start: AlertTimeOfDay(hour: 9, minute: 0),
                    end: AlertTimeOfDay(hour: 11, minute: 0)
                )
            ),
            urgency: .normal,
            privacyMode: .full
        )

        try await scheduler.schedule(template)

        #expect(center.addedRequests.count == AlertTriggerPlanner.randomWindowSchedulingDays)
        #expect(center.addedRequests.allSatisfy {
            $0.identifier.contains(".random.")
        })
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

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        addedRequests.filter { removedIdentifiers.contains($0.identifier) == false }
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

private func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date ?? Date(timeIntervalSince1970: 0)
}
