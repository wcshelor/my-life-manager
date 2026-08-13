import Foundation
import UserNotifications

struct AlertPlannedRequest {
    let identifier: String
    let trigger: UNNotificationTrigger
}

struct AlertTriggerPlanner {
    static let fixedTimeSchedulingDays = 7
    static let randomWindowSchedulingDays = 7

    func plannedRequests(
        for template: AlertTemplate,
        preferences: AlertNotificationPreferences,
        now: Date,
        calendar: Calendar,
        busyIntervals: [DateInterval] = [],
        scheduledCountByDay: [Date: Int] = [:]
    ) -> [AlertPlannedRequest] {
        switch template.trigger {
        case .fixedTime(let trigger):
            return plannedFixedTimeRequests(
                for: template,
                trigger: trigger,
                preferences: preferences,
                now: now,
                calendar: calendar,
                busyIntervals: busyIntervals,
                scheduledCountByDay: scheduledCountByDay
            )
        case .oneShot(let trigger):
            return plannedSingleDateRequest(
                for: template,
                date: trigger.date,
                identifier: template.oneShotNotificationIdentifier,
                preferences: preferences,
                now: now,
                calendar: calendar,
                busyIntervals: busyIntervals,
                scheduledCountByDay: scheduledCountByDay
            )
        case .relative(let trigger):
            return plannedSingleDateRequest(
                for: template,
                date: trigger.scheduledDate,
                identifier: template.relativeNotificationIdentifier,
                preferences: preferences,
                now: now,
                calendar: calendar,
                busyIntervals: busyIntervals,
                scheduledCountByDay: scheduledCountByDay
            )
        case .randomDailyWindow(let trigger):
            return plannedRandomWindowRequests(
                for: template,
                trigger: trigger,
                preferences: preferences,
                now: now,
                calendar: calendar,
                busyIntervals: busyIntervals,
                scheduledCountByDay: scheduledCountByDay
            )
        }
    }

    private func plannedFixedTimeRequests(
        for template: AlertTemplate,
        trigger: AlertFixedTimeTrigger,
        preferences: AlertNotificationPreferences,
        now: Date,
        calendar: Calendar,
        busyIntervals: [DateInterval],
        scheduledCountByDay: [Date: Int]
    ) -> [AlertPlannedRequest] {
        var requests: [AlertPlannedRequest] = []
        var countsByDay = scheduledCountByDay
        var day = calendar.startOfDay(for: now)
        var searchedDays = 0

        while requests.count < Self.fixedTimeSchedulingDays && searchedDays < 21 {
            defer {
                day = calendar.date(byAdding: .day, value: 1, to: day)
                    ?? day.addingTimeInterval(86_400)
                searchedDays += 1
            }

            guard isEligible(day: day, recurrence: trigger.recurrence, calendar: calendar) else {
                continue
            }

            let candidate = calendar.date(
                bySettingHour: trigger.hour,
                minute: trigger.minute,
                second: 0,
                of: day
            ) ?? day

            guard let adjustedDate = adjustedFireDate(
                from: candidate,
                preferences: preferences,
                busyIntervals: busyIntervals,
                calendar: calendar
            ), adjustedDate > now else {
                continue
            }

            let dayKey = calendar.startOfDay(for: adjustedDate)
            guard (countsByDay[dayKey] ?? 0) < preferences.maxNudgesPerDay else {
                continue
            }

            countsByDay[dayKey, default: 0] += 1
            requests.append(
                AlertPlannedRequest(
                    identifier: template.fixedTimeNotificationIdentifier(for: day, calendar: calendar),
                    trigger: oneShotTrigger(for: adjustedDate, calendar: calendar)
                )
            )
        }

        return requests
    }

    private func plannedSingleDateRequest(
        for template: AlertTemplate,
        date: Date,
        identifier: String,
        preferences: AlertNotificationPreferences,
        now: Date,
        calendar: Calendar,
        busyIntervals: [DateInterval],
        scheduledCountByDay: [Date: Int]
    ) -> [AlertPlannedRequest] {
        guard let adjustedDate = adjustedFireDate(
            from: date,
            preferences: preferences,
            busyIntervals: busyIntervals,
            calendar: calendar
        ), adjustedDate > now else {
            return []
        }

        let dayKey = calendar.startOfDay(for: adjustedDate)
        guard (scheduledCountByDay[dayKey] ?? 0) < preferences.maxNudgesPerDay else {
            return []
        }

        return [
            AlertPlannedRequest(
                identifier: identifier,
                trigger: oneShotTrigger(for: adjustedDate, calendar: calendar)
            )
        ]
    }

    private func plannedRandomWindowRequests(
        for template: AlertTemplate,
        trigger: AlertRandomDailyWindowTrigger,
        preferences: AlertNotificationPreferences,
        now: Date,
        calendar: Calendar,
        busyIntervals: [DateInterval],
        scheduledCountByDay: [Date: Int]
    ) -> [AlertPlannedRequest] {
        var requests: [AlertPlannedRequest] = []
        var countsByDay = scheduledCountByDay
        var day = calendar.startOfDay(for: now)
        var searchedDays = 0

        while requests.count < Self.randomWindowSchedulingDays && searchedDays < 21 {
            defer {
                day = calendar.date(byAdding: .day, value: 1, to: day)
                    ?? day.addingTimeInterval(86_400)
                searchedDays += 1
            }

            guard isEligible(day: day, recurrence: trigger.recurrence, calendar: calendar) else {
                continue
            }

            let window = trigger.window.interval(startingOn: day, calendar: calendar)
            let candidate = randomDate(
                in: window,
                templateID: template.id,
                day: day,
                calendar: calendar
            )

            guard let adjustedDate = adjustedFireDate(
                from: candidate,
                preferences: preferences,
                busyIntervals: busyIntervals,
                calendar: calendar
            ), adjustedDate > now else {
                continue
            }

            let dayKey = calendar.startOfDay(for: adjustedDate)
            guard (countsByDay[dayKey] ?? 0) < preferences.maxNudgesPerDay else {
                continue
            }

            countsByDay[dayKey, default: 0] += 1
            requests.append(
                AlertPlannedRequest(
                    identifier: template.randomWindowNotificationIdentifier(
                        for: adjustedDate,
                        calendar: calendar
                    ),
                    trigger: oneShotTrigger(for: adjustedDate, calendar: calendar)
                )
            )
        }

        return requests
    }

    private func adjustedFireDate(
        from date: Date,
        preferences: AlertNotificationPreferences,
        busyIntervals: [DateInterval],
        calendar: Calendar
    ) -> Date? {
        var adjustedDate = date
        let sortedBusyIntervals = busyIntervals.sorted { $0.start < $1.start }

        for _ in 0 ..< 6 {
            if preferences.quietHoursEnabled,
               preferences.quietHoursWindow.contains(adjustedDate, calendar: calendar),
               let quietHoursEnd = preferences.quietHoursWindow.nextWindowEnd(
                after: adjustedDate,
                calendar: calendar
               ) {
                adjustedDate = quietHoursEnd
                continue
            }

            if preferences.avoidCalendarBusyPeriods,
               let blockingInterval = sortedBusyIntervals.first(where: { $0.contains(adjustedDate) }) {
                adjustedDate = blockingInterval.end
                continue
            }

            return adjustedDate
        }

        return adjustedDate
    }

    private func isEligible(
        day: Date,
        recurrence: AlertRecurrence,
        calendar: Calendar
    ) -> Bool {
        switch recurrence.normalized {
        case .daily:
            return true
        case .weekdays(let weekdays):
            let weekday = calendar.component(.weekday, from: day)
            return weekdays.contains { $0.rawValue == weekday }
        }
    }

    private func randomDate(
        in interval: DateInterval,
        templateID: UUID,
        day: Date,
        calendar: Calendar
    ) -> Date {
        let ratio = deterministicRatio(templateID: templateID, day: day, calendar: calendar)
        let availableDuration = max(1, interval.duration - 1)
        return interval.start.addingTimeInterval(availableDuration * ratio)
    }

    private func deterministicRatio(
        templateID: UUID,
        day: Date,
        calendar: Calendar
    ) -> Double {
        let ordinal = UInt64(
            calendar.ordinality(of: .day, in: .era, for: day)
                ?? Int(day.timeIntervalSince1970 / 86_400)
        )
        var state = ordinal

        withUnsafeBytes(of: templateID.uuid) { bytes in
            for byte in bytes {
                state = (state &* 1_664_525) &+ UInt64(byte) &+ 1_013_904_223
            }
        }

        return Double(state % 10_000) / 10_000
    }

    private func oneShotTrigger(
        for date: Date,
        calendar: Calendar
    ) -> UNCalendarNotificationTrigger {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
    }
}
