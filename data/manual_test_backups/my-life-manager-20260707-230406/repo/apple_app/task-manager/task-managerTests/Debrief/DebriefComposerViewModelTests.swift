import Foundation
import Testing
@testable import task_manager

@MainActor
struct DebriefComposerViewModelTests {
    @Test func quickActionCanApplyPresetNoteAndCompleteImmediately() {
        let candidate = CalendarDebriefCandidate(
            sourceType: .meeting,
            sourceID: "meeting-1",
            sourceContext: "Work",
            eventKey: "meeting-1",
            eventIdentifier: "meeting-1",
            calendarIdentifier: "work",
            calendarTitle: "Work",
            title: "Weekly Sync",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000),
            suggestedTemplate: .meeting,
            existingRecordID: nil
        )
        let viewModel = DebriefComposerViewModel(
            draft: DebriefDraft(candidate: candidate, existingDebrief: nil)
        )
        let wasteAction = DebriefQuickAction.actions(for: .meeting).last!

        let completed = viewModel.applyQuickAction(wasteAction)

        #expect(completed.quickOutcome == .bad)
        #expect(completed.quickNote == "Felt like a poor use of time.")
        #expect(completed.meetingOutcomes.isEmpty)
        #expect(completed.socialWorthRemembering.isEmpty)
    }

    @Test func detailedFlowCanBeOpenedAfterQuickOutcome() {
        let candidate = CalendarDebriefCandidate(
            sourceType: .meeting,
            sourceID: "meeting-1",
            sourceContext: "Work",
            eventKey: "event-2",
            eventIdentifier: "event-2",
            calendarIdentifier: "work",
            calendarTitle: "Work",
            title: "Weekly Sync",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000),
            suggestedTemplate: .meeting,
            existingRecordID: nil
        )
        let viewModel = DebriefComposerViewModel(
            draft: DebriefDraft(candidate: candidate, existingDebrief: nil)
        )

        viewModel.selectQuickOutcome(.useful)
        viewModel.showDetailedPrompts()

        #expect(viewModel.isShowingDetailedPrompts == true)
        #expect(viewModel.templateDefinition.kind == .meeting)
    }

    @Test func detailedFlowPreservesManualQuickNote() {
        let candidate = CalendarDebriefCandidate(
            sourceType: .calendarBlock,
            sourceID: "event-1",
            sourceContext: "Work",
            eventKey: "event-1",
            eventIdentifier: "event-1",
            calendarIdentifier: "work",
            calendarTitle: "Work",
            title: "Deep Work",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000),
            suggestedTemplate: .workBlock,
            existingRecordID: nil
        )
        let viewModel = DebriefComposerViewModel(
            draft: DebriefDraft(candidate: candidate, existingDebrief: nil)
        )

        viewModel.selectQuickOutcome(.good)
        viewModel.draft.quickNote = "Closed the main task"
        viewModel.showDetailedPrompts()

        #expect(viewModel.completeQuickDebrief().quickNote == "Closed the main task")
        #expect(viewModel.isShowingDetailedPrompts == true)
    }
}
