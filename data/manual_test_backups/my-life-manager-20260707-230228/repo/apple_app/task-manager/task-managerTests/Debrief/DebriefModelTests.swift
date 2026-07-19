import Foundation
import Testing
@testable import task_manager

struct DebriefModelTests {
    @Test func quickCompletionMarksDebriefCompletedWithOutcomeAndNote() {
        let completedAt = Date(timeIntervalSince1970: 5_000)
        let debrief = CalendarDebriefRecord(
            sourceType: .meeting,
            sourceID: "meeting-1",
            sourceContext: "Team sync",
            eventKey: "event-1",
            eventIdentifier: "event-1",
            calendarIdentifier: "work",
            calendarTitleSnapshot: "Work",
            titleSnapshot: "Weekly sync",
            startDateSnapshot: Date(timeIntervalSince1970: 1_000),
            endDateSnapshot: Date(timeIntervalSince1970: 2_000),
            templateKind: .meeting,
            status: .pending
        )

        let completed = debrief.completedQuickly(
            outcome: .useful,
            note: "Clear next steps",
            completedAt: completedAt
        )

        #expect(completed.status == .completed)
        #expect(completed.quickOutcome == .useful)
        #expect(completed.quickNote == "Clear next steps")
        #expect(completed.completedAt == completedAt)
    }

    @Test func skippedQuickOutcomeMarksNoDebriefNeeded() {
        let debrief = CalendarDebriefRecord(
            eventKey: "event-2",
            eventIdentifier: "event-2",
            calendarIdentifier: "work",
            calendarTitleSnapshot: "Work",
            titleSnapshot: "Admin",
            startDateSnapshot: Date(timeIntervalSince1970: 1_000),
            endDateSnapshot: Date(timeIntervalSince1970: 2_000),
            templateKind: .workBlock,
            status: .pending
        )

        let skipped = debrief.completedQuickly(
            outcome: .skipped,
            note: nil,
            completedAt: Date(timeIntervalSince1970: 6_000)
        )

        #expect(skipped.status == .skipped)
        #expect(skipped.noDebriefNeeded == true)
    }

    @Test func templateDefinitionsExposeExpectedQuickOutcomes() {
        let meeting = DebriefTemplates.definition(for: .meeting)
        let vice = DebriefTemplates.definition(for: .viceSession)

        #expect(meeting.quickOutcomes == [.useful, .fine, .unclear, .skipped, .cancelled])
        #expect(vice.quickOutcomes == [.intentional, .mixed, .regretful, .skipped])
    }
}
