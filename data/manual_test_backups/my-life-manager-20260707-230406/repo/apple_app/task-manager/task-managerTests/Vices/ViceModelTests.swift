import Foundation
import Testing
@testable import task_manager

struct ViceModelTests {
    @Test func viceValidationAndNormalization() {
        #expect(Vice(newName: "  ", unitLabel: "Hits") == nil)
        #expect(Vice(newName: "Dab Pen", unitLabel: " ") == nil)

        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let vice = Vice(name: "  Dab Pen  ", unitLabel: "  Hits ", linkedRoutineID: routineID)

        #expect(vice.name == "Dab Pen")
        #expect(vice.unitLabel == "Hits")
        #expect(vice.linkedRoutineID == routineID)
    }

    @Test func viceLogAmountIsAtLeastOne() {
        let viceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let log = ViceLog(
            viceID: viceID,
            timestamp: Date(timeIntervalSince1970: 100),
            amount: 0
        )

        #expect(log.amount == 1)
    }

    @Test func homeVicesSummaryTracksTodayCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 12))!
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let todaysLog = ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-120))
        let oldLog = ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-90_000))
        let summary = HomeVicesSummary(
            vices: [vice],
            logs: [todaysLog, oldLog],
            now: now,
            calendar: calendar
        )

        #expect(summary.activeViceCount == 1)
        #expect(summary.totalTodayCount == 1)
        #expect(summary.detail == "1 logged today")
    }

    @Test func viceSessionFormattingUsesPositionalElapsedTime() {
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let session = ViceSession(
            viceID: vice.id,
            startedAt: Date(timeIntervalSince1970: 0),
            lastHitAt: Date(timeIntervalSince1970: 9_000),
            hitCount: 5
        )

        #expect(session.isActive(at: Date(timeIntervalSince1970: 9_500)))
        #expect(session.isActive(at: Date(timeIntervalSince1970: 20_000)) == false)
        #expect(ViceDurationFormatter.elapsedSince(Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 3_661)) == "01:01:01")
        #expect(ViceSessionSummary(session: session, viceName: vice.name).summaryText.contains("5 hits over") == true)
    }

    @Test func viceGoalSummaryUsesEndOfDayLabelWhenDeadlineIsEndOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 8))!
        let deadline = calendar.endOfDay(for: start)
        let goal = ViceGoal(
            viceID: UUID(),
            maxOccurrences: 3,
            startDate: start,
            deadline: deadline
        )

        #expect(ViceGoalProgress(goal: goal, count: 1).summaryText(calendar: calendar).contains("end of Jun 30"))
        #expect(deadline.isEndOfDay(in: calendar))
    }

    @Test func viceRoutineUnlockTracksActiveWindow() {
        let completedAt = Date(timeIntervalSince1970: 1_000)
        let unlock = ViceRoutineUnlock(
            viceID: UUID(),
            routineID: UUID(),
            completedAt: completedAt,
            expiresAt: completedAt.addingTimeInterval(900)
        )

        #expect(unlock.isActive(at: completedAt.addingTimeInterval(899)))
        #expect(unlock.isActive(at: completedAt.addingTimeInterval(901)) == false)
    }
}
