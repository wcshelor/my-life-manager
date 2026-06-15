import Foundation
import Testing
@testable import task_manager

@MainActor
struct DebriefQueueFlowTests {
    @Test func quickOutcomeGatesTheDetailButton() async {
        let harness = DebriefQueueHarness(
            pendingCandidates: [makeCandidate(idSuffix: "1", title: "Weekly meeting")]
        )
        let viewModel = DebriefQueueViewModel(
            loadSnapshot: { harness.snapshot() },
            persistCurrent: harness.persistCurrent(candidate:draft:action:existing:)
        )

        await viewModel.load()

        #expect(viewModel.currentCandidate?.title == "Weekly meeting")
        #expect(viewModel.canShowDetailButton == false)

        viewModel.selectQuickOutcome(.good)

        #expect(viewModel.canShowDetailButton == true)
        #expect(viewModel.canFinishCurrent == true)
    }

    @Test func draftStateSurvivesDetailEditing() async {
        let harness = DebriefQueueHarness(
            pendingCandidates: [makeCandidate(idSuffix: "1", title: "Work block")]
        )
        let viewModel = DebriefQueueViewModel(
            loadSnapshot: { harness.snapshot() },
            persistCurrent: harness.persistCurrent(candidate:draft:action:existing:)
        )

        await viewModel.load()
        viewModel.selectTemplateKind(.workBlock)
        viewModel.selectQuickOutcome(.mid)
        viewModel.draft.workWhatHappened = "Outlined the launch plan"
        viewModel.draft.workNextStep = "Ship review notes"
        viewModel.draft.detailedResponses[0].response = "Ship review notes"

        #expect(viewModel.draft.quickOutcome == .mid)
        #expect(viewModel.draft.workWhatHappened == "Outlined the launch plan")
        #expect(viewModel.draft.workNextStep == "Ship review notes")
        #expect(viewModel.draft.detailedResponses.first?.response == "Ship review notes")
    }

    @Test func completeAdvancesToTheNextPendingDebrief() async {
        let harness = DebriefQueueHarness(
            pendingCandidates: [
                makeCandidate(idSuffix: "1", title: "Weekly meeting"),
                makeCandidate(idSuffix: "2", title: "Writing block"),
            ]
        )
        let viewModel = DebriefQueueViewModel(
            loadSnapshot: { harness.snapshot() },
            persistCurrent: harness.persistCurrent(candidate:draft:action:existing:)
        )

        await viewModel.load()
        viewModel.selectQuickOutcome(.good)
        let firstSaved = await viewModel.completeCurrent()

        #expect(firstSaved == true)
        #expect(harness.persistedActions == [.complete])
        #expect(harness.savedRecords.first?.status == .completed)
        #expect(viewModel.currentCandidate?.title == "Writing block")
        #expect(viewModel.canShowDetailButton == false)
    }

    @Test func skipAdvancesAndEmptiesTheQueueAfterTheLastItem() async {
        let harness = DebriefQueueHarness(
            pendingCandidates: [makeCandidate(idSuffix: "1", title: "Solo debrief")]
        )
        let viewModel = DebriefQueueViewModel(
            loadSnapshot: { harness.snapshot() },
            persistCurrent: harness.persistCurrent(candidate:draft:action:existing:)
        )

        await viewModel.load()
        let skipped = await viewModel.skipCurrent()

        #expect(skipped == true)
        #expect(harness.persistedActions == [.skip])
        #expect(harness.savedRecords.first?.status == .skipped)
        #expect(viewModel.currentCandidate == nil)
        #expect(viewModel.pendingCandidates.isEmpty)
        #expect(viewModel.canFinishCurrent == false)
    }

    private func makeCandidate(idSuffix: String, title: String) -> CalendarDebriefCandidate {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = start.addingTimeInterval(1_800)
        return CalendarDebriefCandidate(
            sourceType: .calendarBlock,
            sourceID: "event-\(idSuffix)",
            sourceContext: "Work",
            eventKey: "event-key-\(idSuffix)",
            eventIdentifier: "event-\(idSuffix)",
            calendarIdentifier: "calendar-\(idSuffix)",
            calendarTitle: "Work",
            title: title,
            start: start,
            end: end,
            suggestedTemplate: .workBlock,
            existingRecordID: nil
        )
    }
}

@MainActor
private final class DebriefQueueHarness {
    var pendingCandidates: [CalendarDebriefCandidate]
    var persistedActions: [DebriefPersistAction] = []
    var savedRecords: [CalendarDebriefRecord] = []

    init(pendingCandidates: [CalendarDebriefCandidate]) {
        self.pendingCandidates = pendingCandidates
    }

    func snapshot() -> DebriefQueueSnapshot {
        DebriefQueueSnapshot(
            pendingCandidates: pendingCandidates,
            debriefsByEventKey: [:],
            tasksByID: [:],
            projectsByID: [:],
            focusesByLookupKey: [:],
            completedTodayCount: savedRecords.filter { record in
                record.completedAt != nil && record.status == .completed
            }.count
        )
    }

    func persistCurrent(
        candidate: CalendarDebriefCandidate,
        draft: DebriefDraft,
        action: DebriefPersistAction,
        existing: CalendarDebriefRecord?
    ) throws {
        persistedActions.append(action)

        let record = draft.makeDebriefRecord(
            candidate: candidate,
            status: action == .complete ? .completed : .skipped,
            completedAt: Date(timeIntervalSince1970: 99_999),
            noDebriefNeeded: action == .skip,
            captureIDs: [],
            taskOutcomes: existing?.taskOutcomes ?? [],
            preserving: existing
        )

        savedRecords.append(record)

        if pendingCandidates.isEmpty == false {
            pendingCandidates.removeFirst()
        }
    }
}
