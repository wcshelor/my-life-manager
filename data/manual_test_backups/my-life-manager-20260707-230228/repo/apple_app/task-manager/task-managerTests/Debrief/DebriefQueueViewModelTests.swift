import Foundation
import Testing
@testable import task_manager

@MainActor
struct DebriefQueueViewModelTests {
    @Test func loadExposesCurrentCandidateFromPendingQueue() async {
        let now = Date(timeIntervalSince1970: 10_000)
        let events = [
            makeEvent(identifier: "first", title: "Deep Work", start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(-3_600)),
            makeEvent(identifier: "second", title: "Weekly meeting", start: now.addingTimeInterval(-5_400), end: now.addingTimeInterval(-1_800))
        ]
        let viewModel = makeViewModel(events: events, now: now)

        await viewModel.load()

        #expect(viewModel.pendingCandidates.count == 2)
        #expect(viewModel.currentCandidate?.title == "Weekly meeting")
        #expect(viewModel.selectedIndex == 0)
    }

    @Test func completingCurrentCandidateAdvancesToNextCandidate() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let events = [
            makeEvent(identifier: "first", title: "Deep Work", start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(-3_600)),
            makeEvent(identifier: "second", title: "Weekly meeting", start: now.addingTimeInterval(-5_400), end: now.addingTimeInterval(-1_800))
        ]
        let debriefRepository = FakeDebriefRepository()
        let viewModel = makeViewModel(events: events, now: now, debriefRepository: debriefRepository)

        await viewModel.load()
        let current = try #require(viewModel.currentCandidate)

        try viewModel.completeCurrentDebrief(with: viewModel.draft(for: current))

        #expect(viewModel.pendingCandidates.count == 1)
        #expect(viewModel.currentCandidate?.title == "Deep Work")
        #expect(debriefRepository.debriefs.first?.status == .completed)
    }

    @Test func skippingCurrentCandidateAdvancesToNextCandidate() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let events = [
            makeEvent(identifier: "first", title: "Deep Work", start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(-3_600)),
            makeEvent(identifier: "second", title: "Weekly meeting", start: now.addingTimeInterval(-5_400), end: now.addingTimeInterval(-1_800))
        ]
        let debriefRepository = FakeDebriefRepository()
        let viewModel = makeViewModel(events: events, now: now, debriefRepository: debriefRepository)

        await viewModel.load()

        try viewModel.skipCurrentDebrief()

        #expect(viewModel.pendingCandidates.count == 1)
        #expect(viewModel.currentCandidate?.title == "Deep Work")
        #expect(debriefRepository.debriefs.first?.status == .skipped)
    }

    @Test func selectedIndexStaysValidWhenQueueShrinks() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let events = [
            makeEvent(identifier: "first", title: "Admin", start: now.addingTimeInterval(-9_000), end: now.addingTimeInterval(-7_200)),
            makeEvent(identifier: "second", title: "Deep Work", start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(-3_600)),
            makeEvent(identifier: "third", title: "Weekly meeting", start: now.addingTimeInterval(-5_400), end: now.addingTimeInterval(-1_800))
        ]
        let viewModel = makeViewModel(events: events, now: now)

        await viewModel.load()
        viewModel.selectedIndex = 2

        let current = try #require(viewModel.currentCandidate)
        try viewModel.completeCurrentDebrief(with: viewModel.draft(for: current))

        #expect(viewModel.pendingCandidates.count == 2)
        #expect(viewModel.selectedIndex == 1)
        #expect(viewModel.currentCandidate?.title == "Deep Work")
    }

    @Test func laterMovesCurrentCandidateToBackOfQueue() async {
        let now = Date(timeIntervalSince1970: 10_000)
        let events = [
            makeEvent(identifier: "first", title: "Admin", start: now.addingTimeInterval(-9_000), end: now.addingTimeInterval(-7_200)),
            makeEvent(identifier: "second", title: "Deep Work", start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(-3_600)),
            makeEvent(identifier: "third", title: "Weekly meeting", start: now.addingTimeInterval(-5_400), end: now.addingTimeInterval(-1_800))
        ]
        let viewModel = makeViewModel(events: events, now: now)

        await viewModel.load()
        let moved = viewModel.moveCurrentCandidateToBack()

        #expect(moved == true)
        #expect(viewModel.pendingCandidates.map(\.title) == ["Deep Work", "Admin", "Weekly meeting"])
        #expect(viewModel.currentCandidate?.title == "Deep Work")
    }

    private func makeViewModel(
        events: [CalendarEventSnapshot],
        now: Date,
        debriefRepository: FakeDebriefRepository = FakeDebriefRepository()
    ) -> DebriefQueueViewModel {
        DebriefQueueViewModel(
            debriefRepository: debriefRepository,
            captureRepository: FakeCaptureRepository(),
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            calendarBlockFocusRepository: FakeCalendarBlockFocusRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(status: .fullAccessGranted),
            calendarReader: FakeCalendarReader(events: events),
            nowProvider: { now }
        )
    }

    private func makeEvent(identifier: String, title: String, start: Date, end: Date) -> CalendarEventSnapshot {
        CalendarEventSnapshot(
            identifier: identifier,
            calendarIdentifier: "work-cal",
            title: title,
            start: start,
            end: end,
            isAllDay: false,
            calendarTitle: "Work"
        )
    }
}

@MainActor
private final class FakeDebriefRepository: DebriefRepository {
    var debriefs: [CalendarDebriefRecord]

    init(debriefs: [CalendarDebriefRecord] = []) {
        self.debriefs = debriefs
    }

    func fetchDebriefs() throws -> [CalendarDebriefRecord] {
        debriefs
    }

    func debrief(withID id: UUID) throws -> CalendarDebriefRecord? {
        debriefs.first { $0.id == id }
    }

    func debrief(withEventKey eventKey: String) throws -> CalendarDebriefRecord? {
        debriefs.first { $0.eventKey == eventKey }
    }

    func saveDebrief(_ debrief: CalendarDebriefRecord, replacingDebriefWithID originalID: UUID?) throws {
        let targetID = originalID ?? debrief.id
        if let index = debriefs.firstIndex(where: { $0.id == targetID || $0.eventKey == debrief.eventKey }) {
            debriefs[index] = debrief
        } else {
            debriefs.append(debrief)
        }
    }

    func deleteDebrief(withID id: UUID) throws {
        debriefs.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeCaptureRepository: CaptureRepository {
    func fetchCaptures(includeProcessed: Bool, includeArchived: Bool) throws -> [CaptureItem] { [] }
    func capture(withID id: UUID) throws -> CaptureItem? { nil }
    func saveCapture(_ capture: CaptureItem, replacingCaptureWithID originalID: UUID?) throws {}
    func deleteCapture(withID id: UUID) throws {}
}

@MainActor
private final class FakeTaskRepository: TaskRepository {
    func fetchTasks() throws -> [MyTask] { [] }
    func task(withID id: UUID) throws -> MyTask? { nil }
    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {}
    func deleteTask(withID id: UUID) throws {}
}

@MainActor
private final class FakeProjectRepository: ProjectRepository {
    func fetchProjects(includeArchived: Bool) throws -> [Project] { [] }
    func project(withID id: UUID) throws -> Project? { nil }
    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) throws {}
    func archiveProject(withID id: UUID, archivedAt: Date) throws {}
    func deleteProject(withID id: UUID) throws {}
}

@MainActor
private final class FakeCalendarBlockFocusRepository: CalendarBlockFocusRepository {
    func fetchFocus(forEventIdentifier eventIdentifier: String, calendarIdentifier: String) throws -> CalendarBlockFocus? { nil }
    func fetchFocuses(in dateRange: DateInterval) throws -> [CalendarBlockFocus] { [] }
    func fetchFocuses(linkedTo projectID: UUID) throws -> [CalendarBlockFocus] { [] }
    func saveFocus(_ focus: CalendarBlockFocus, replacingFocusWithID originalID: UUID?) throws {}
    func setLinkedProject(_ projectID: UUID?, for event: CalendarEventSnapshot, isUserConfirmed: Bool) throws {}
    func setSelectedTaskIDs(_ taskIDs: [UUID], for event: CalendarEventSnapshot) throws {}
    func updateIntentionNote(_ note: String?, for event: CalendarEventSnapshot) throws {}
    func markNoFocusNeeded(for event: CalendarEventSnapshot, isNoFocusNeeded: Bool) throws {}
}

@MainActor
private final class FakeCalendarPermissionProvider: CalendarPermissionProviding {
    let status: CalendarPermissionStatus

    init(status: CalendarPermissionStatus) {
        self.status = status
    }

    func currentStatus() -> CalendarPermissionStatus {
        status
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        status
    }
}

@MainActor
private final class FakeCalendarReader: CalendarReading {
    let events: [CalendarEventSnapshot]

    init(events: [CalendarEventSnapshot]) {
        self.events = events
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        events.filter { event in
            event.end > window.start && event.start < window.end
        }
    }
}
