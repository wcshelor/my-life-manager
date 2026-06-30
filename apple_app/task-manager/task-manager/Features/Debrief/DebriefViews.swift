import Combine
import Foundation
import SwiftUI

nonisolated enum DebriefPersistAction: Sendable, Equatable {
    case complete
    case skip
}

nonisolated struct DebriefQueueSnapshot: Sendable, Equatable {
    var pendingCandidates: [CalendarDebriefCandidate]
    var debriefsByEventKey: [String: CalendarDebriefRecord]
    var tasksByID: [UUID: MyTask]
    var projectsByID: [UUID: Project]
    var focusesByLookupKey: [String: CalendarBlockFocus]
    var completedTodayCount: Int

    static let empty = DebriefQueueSnapshot(
        pendingCandidates: [],
        debriefsByEventKey: [:],
        tasksByID: [:],
        projectsByID: [:],
        focusesByLookupKey: [:],
        completedTodayCount: 0
    )
}

@MainActor
final class DebriefQueueViewModel: ObservableObject {
    @Published private(set) var pendingCandidates: [CalendarDebriefCandidate] = []
    @Published var draft: DebriefDraft = .placeholder
    @Published private(set) var completedTodayCount = 0
    @Published private(set) var errorMessage: String?

    private let loadSnapshot: @MainActor () async throws -> DebriefQueueSnapshot
    private let persistCurrent: @MainActor (
        CalendarDebriefCandidate,
        DebriefDraft,
        DebriefPersistAction,
        CalendarDebriefRecord?
    ) throws -> Void

    private var snapshot: DebriefQueueSnapshot = .empty

    var currentCandidate: CalendarDebriefCandidate? {
        pendingCandidates.first
    }

    var canShowDetailButton: Bool {
        draft.quickOutcome != nil
    }

    var canFinishCurrent: Bool {
        currentCandidate != nil && draft.quickOutcome != nil
    }

    init(
        loadSnapshot: @escaping @MainActor () async throws -> DebriefQueueSnapshot,
        persistCurrent: @escaping @MainActor (
            CalendarDebriefCandidate,
            DebriefDraft,
            DebriefPersistAction,
            CalendarDebriefRecord?
        ) throws -> Void
    ) {
        self.loadSnapshot = loadSnapshot
        self.persistCurrent = persistCurrent
    }

    convenience init(
        debriefRepository: any DebriefRepository,
        captureRepository: any CaptureRepository,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarReader: any CalendarReading,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        queueSettings: DebriefQueueSettings = .mvpDefault
    ) {
        self.init(
            loadSnapshot: {
                let permissionStatus = calendarPermissionProvider.currentStatus()
                guard permissionStatus == .fullAccessGranted else {
                    return .empty
                }

                let now = nowProvider()
                let queueStart = calendar.date(
                    byAdding: .day,
                    value: -max(1, queueSettings.lookbackDays),
                    to: now
                ) ?? now.addingTimeInterval(-Double(max(1, queueSettings.lookbackDays)) * 86_400)

                let events = try await calendarReader.fetchEvents(
                    in: DateInterval(start: queueStart, end: now)
                )
                let debriefs = try debriefRepository.fetchDebriefs()
                let tasks = try taskRepository.fetchTasks()
                let projects = try projectRepository.fetchProjects(includeArchived: false)
                let focuses = try calendarBlockFocusRepository.fetchFocuses(
                    in: DateInterval(start: queueStart, end: now)
                )

                let pendingCandidates = DebriefQueueService(settings: queueSettings).pendingCandidates(
                    from: events,
                    existingDebriefs: debriefs,
                    now: now
                )

                let debriefsByEventKey = Dictionary(
                    uniqueKeysWithValues: debriefs.map { ($0.eventKey, $0) }
                )
                let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
                let focusesByLookupKey = Dictionary(
                    uniqueKeysWithValues: focuses.map { focus in
                        (
                            Self.focusLookupKey(
                                eventIdentifier: focus.eventIdentifier,
                                calendarIdentifier: focus.calendarIdentifier
                            ),
                            focus
                        )
                    }
                )
                let completedTodayCount = debriefs.filter { debrief in
                    guard let completedAt = debrief.completedAt else {
                        return false
                    }

                    return calendar.isDate(completedAt, inSameDayAs: now)
                }.count

                return DebriefQueueSnapshot(
                    pendingCandidates: pendingCandidates,
                    debriefsByEventKey: debriefsByEventKey,
                    tasksByID: tasksByID,
                    projectsByID: projectsByID,
                    focusesByLookupKey: focusesByLookupKey,
                    completedTodayCount: completedTodayCount
                )
            },
            persistCurrent: { candidate, draft, action, existingDebrief in
                let now = nowProvider()
                var captureIDs: [UUID] = existingDebrief?.createdCaptureIDs ?? []

                switch action {
                case .complete:
                    for captureText in draft.captureLines {
                        guard let cleanedTitle = CaptureItem.cleanedTitle(from: captureText) else {
                            continue
                        }

                        let capture = CaptureItem(
                            title: cleanedTitle,
                            source: "Debrief · \(candidate.title)",
                            createdAt: now,
                            updatedAt: now
                        )
                        try captureRepository.saveCapture(capture, replacingCaptureWithID: nil)
                        captureIDs.append(capture.id)
                    }

                    let debriefID = existingDebrief?.id ?? UUID()
                    let taskOutcomes = draft.taskOutcomeDrafts.map { taskOutcomeDraft in
                        DebriefTaskOutcome(
                            debriefID: debriefID,
                            taskID: taskOutcomeDraft.taskID,
                            taskTitleSnapshot: taskOutcomeDraft.taskTitleSnapshot,
                            outcome: taskOutcomeDraft.outcome,
                            note: taskOutcomeDraft.note,
                            didUpdateTaskStatus: taskOutcomeDraft.didUpdateTaskStatus,
                            createdAt: now,
                            updatedAt: now
                        )
                    }

                    for taskOutcome in taskOutcomes where taskOutcome.outcome == .completed && taskOutcome.didUpdateTaskStatus {
                        guard var task = try taskRepository.task(withID: taskOutcome.taskID) else {
                            continue
                        }

                        task.status = .done
                        task.completedAt = now
                        task.updatedAt = now
                        try? taskRepository.saveTask(task, replacingTaskWithID: task.id)
                    }

                    let completedDebrief = draft.makeDebriefRecord(
                        candidate: candidate,
                        status: .completed,
                        completedAt: now,
                        noDebriefNeeded: false,
                        captureIDs: captureIDs,
                        taskOutcomes: taskOutcomes,
                        preserving: existingDebrief
                    )

                    try debriefRepository.saveDebrief(
                        completedDebrief,
                        replacingDebriefWithID: existingDebrief?.id
                    )

                case .skip:
                    let skippedDebrief = draft.makeDebriefRecord(
                        candidate: candidate,
                        status: .skipped,
                        completedAt: now,
                        noDebriefNeeded: true,
                        captureIDs: captureIDs,
                        taskOutcomes: existingDebrief?.taskOutcomes ?? [],
                        preserving: existingDebrief
                    )

                    try debriefRepository.saveDebrief(
                        skippedDebrief,
                        replacingDebriefWithID: existingDebrief?.id
                    )
                }
            }
        )
    }

    func load() async {
        do {
            snapshot = try await loadSnapshot()
            pendingCandidates = snapshot.pendingCandidates
            completedTodayCount = snapshot.completedTodayCount
            draft = draft(for: currentCandidate)
            errorMessage = nil
        } catch {
            snapshot = .empty
            pendingCandidates = []
            completedTodayCount = 0
            draft = .placeholder
            errorMessage = "Unable to load Debriefs: \(error.localizedDescription)"
        }
    }

    func dismissErrorMessage() {
        errorMessage = nil
    }

    func selectTemplateKind(_ kind: DebriefTemplateKind) {
        draft.templateKind = kind
        draft.rebuildDetailedResponses()
    }

    func selectQuickOutcome(_ outcome: DebriefQuickOutcome) {
        draft.quickOutcome = outcome
        if outcome == .skipped {
            draft.quickNote = draft.quickNote.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func completeCurrent() async -> Bool {
        guard let candidate = currentCandidate else {
            return false
        }

        do {
            try persistCurrent(candidate, draft, .complete, snapshot.debriefsByEventKey[candidate.eventKey])
            await load()
            return true
        } catch {
            errorMessage = "Unable to complete Debrief: \(error.localizedDescription)"
            return false
        }
    }

    func skipCurrent() async -> Bool {
        guard let candidate = currentCandidate else {
            return false
        }

        do {
            try persistCurrent(candidate, draft, .skip, snapshot.debriefsByEventKey[candidate.eventKey])
            await load()
            return true
        } catch {
            errorMessage = "Unable to skip Debrief: \(error.localizedDescription)"
            return false
        }
    }

    func currentDraft(for candidate: CalendarDebriefCandidate) -> DebriefDraft {
        draft(for: candidate)
    }

    private func draft(for candidate: CalendarDebriefCandidate?) -> DebriefDraft {
        guard let candidate else {
            return .placeholder
        }

        return DebriefDraft(
            candidate: candidate,
            existingDebrief: snapshot.debriefsByEventKey[candidate.eventKey],
            blockFocus: focus(for: candidate),
            selectedTasks: selectedTasks(for: candidate)
        )
    }

    private func selectedTasks(for candidate: CalendarDebriefCandidate) -> [MyTask] {
        focus(for: candidate)?
            .selectedTaskIDs
            .compactMap { snapshot.tasksByID[$0] } ?? []
    }

    private func focus(for candidate: CalendarDebriefCandidate) -> CalendarBlockFocus? {
        guard
            let eventIdentifier = candidate.eventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventIdentifier.isEmpty == false,
            let calendarIdentifier = candidate.calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarIdentifier.isEmpty == false
        else {
            return nil
        }

        return snapshot.focusesByLookupKey[Self.focusLookupKey(
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier
        )]
    }

    private static func focusLookupKey(
        eventIdentifier: String,
        calendarIdentifier: String
    ) -> String {
        "\(eventIdentifier.trimmingCharacters(in: .whitespacesAndNewlines))|\(calendarIdentifier.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}

struct DebriefListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DebriefQueueViewModel
    @State private var navigationPath: [DebriefRoute] = []

    let onChanged: () -> Void

    init(
        debriefRepository: any DebriefRepository,
        captureRepository: any CaptureRepository,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarReader: any CalendarReading,
        onChanged: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: DebriefQueueViewModel(
                debriefRepository: debriefRepository,
                captureRepository: captureRepository,
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                calendarBlockFocusRepository: calendarBlockFocusRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader
            )
        )
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let candidate = viewModel.currentCandidate {
                    DebriefQueueCard(
                        candidate: candidate,
                        draft: $viewModel.draft,
                        completedTodayCount: viewModel.completedTodayCount,
                        canShowDetailButton: viewModel.canShowDetailButton,
                        canFinishCurrent: viewModel.canFinishCurrent,
                        onShowDetail: {
                            navigationPath.append(.detail)
                        },
                        onFinish: {
                            Task {
                                if await viewModel.completeCurrent() {
                                    onChanged()
                                }
                            }
                        },
                        onSkip: {
                            Task {
                                if await viewModel.skipCurrent() {
                                    onChanged()
                                }
                            }
                        },
                        selectTemplateKind: { kind in
                            viewModel.selectTemplateKind(kind)
                        },
                        selectQuickOutcome: { outcome in
                            viewModel.selectQuickOutcome(outcome)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "All caught up",
                        systemImage: "checkmark.circle",
                        description: Text("Pending Debriefs are surfaced here one at a time.")
                    )
                    .padding()
                }
            }
            .navigationTitle("Debriefs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onChanged()
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: DebriefRoute.self) { route in
                switch route {
                case .detail:
                    DebriefDetailView(draft: $viewModel.draft)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .alert("Debriefs", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.dismissErrorMessage()
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

private enum DebriefRoute: Hashable {
    case detail
}

private struct DebriefQueueCard: View {
    let candidate: CalendarDebriefCandidate
    @Binding var draft: DebriefDraft
    let completedTodayCount: Int
    let canShowDetailButton: Bool
    let canFinishCurrent: Bool
    let onShowDetail: () -> Void
    let onFinish: () -> Void
    let onSkip: () -> Void
    let selectTemplateKind: (DebriefTemplateKind) -> Void
    let selectQuickOutcome: (DebriefQuickOutcome) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                templateSection
                quickOutcomeSection
                if canShowDetailButton {
                    Button {
                        onShowDetail()
                    } label: {
                        Label("Enter More Detailed Info", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    onFinish()
                } label: {
                    Label("Finish Debrief", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(canFinishCurrent == false)

                Button("No Debrief Needed") {
                    onSkip()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderless)
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(candidate.title)
                .font(.title2.weight(.semibold))
            Text(candidate.timeRangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(candidate.calendarTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if completedTodayCount > 0 {
                Text("\(completedTodayCount) loop\(completedTodayCount == 1 ? "" : "s") closed today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Debrief Type")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(DebriefTemplateKind.allCases) { kind in
                    Button {
                        selectTemplateKind(kind)
                    } label: {
                        Text(kind.displayName)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                draft.templateKind == kind
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickOutcomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Debrief")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(draft.templateDefinition.quickOutcomes) { outcome in
                        Button {
                            selectQuickOutcome(outcome)
                        } label: {
                            Text(outcome.displayName)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    draft.quickOutcome == outcome
                                        ? Color.accentColor.opacity(0.22)
                                        : Color.secondary.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DebriefDetailView: View {
    @Binding var draft: DebriefDraft

    var body: some View {
        Form {
            Section("Quick Note") {
                TextField("Anything to remember quickly?", text: $draft.quickNote, axis: .vertical)
            }

            Section("Detailed Prompts") {
                ForEach($draft.detailedResponses) { $response in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(response.prompt)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        TextField(response.prompt, text: $response.response, axis: .vertical)
                    }
                }
            }

            templateSpecificFields

            if draft.taskOutcomeDrafts.isEmpty == false {
                Section("Tasks from This Block") {
                    ForEach($draft.taskOutcomeDrafts) { $taskOutcomeDraft in
                        DebriefTaskOutcomeCard(taskOutcomeDraft: $taskOutcomeDraft)
                    }
                }
            }

            if draft.captureLines.isEmpty == false {
                Section("Captures") {
                    ForEach(Array(draft.captureLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
            }
        }
        .navigationTitle("More Detail")
    }

    @ViewBuilder
    private var templateSpecificFields: some View {
        switch draft.templateKind {
        case .workBlock:
            Section("Work Block") {
                Picker("Did you do what you planned?", selection: $draft.workPlannedOutcome) {
                    Text("Not set").tag(Optional<WorkBlockPlannedOutcome>.none)
                    ForEach(WorkBlockPlannedOutcome.allCases) { outcome in
                        Text(outcome.displayName).tag(Optional(outcome))
                    }
                }

                Picker("Was the block length right?", selection: $draft.workBlockLengthFit) {
                    Text("Not set").tag(Optional<WorkBlockLengthFit>.none)
                    ForEach(WorkBlockLengthFit.allCases) { fit in
                        Text(fit.displayName).tag(Optional(fit))
                    }
                }

                DebriefRatingPicker(title: "Productivity", selection: $draft.workProductivityRating)
                DebriefRatingPicker(title: "Energy before", selection: $draft.workEnergyBeforeRating)
                DebriefRatingPicker(title: "Energy after", selection: $draft.workEnergyAfterRating)
                DebriefRatingPicker(title: "Focus quality", selection: $draft.workFocusQualityRating)

                TextField("What happened?", text: $draft.workWhatHappened, axis: .vertical)
                TextField("Next concrete step", text: $draft.workNextStep, axis: .vertical)

                TagSelectionGrid(
                    title: "Blockers",
                    allCases: WorkBlockBlocker.allCases,
                    displayName: { $0.displayName },
                    selection: $draft.workBlockers
                )
            }

        case .meeting:
            Section("Meeting") {
                TextField("Main outcomes", text: $draft.meetingOutcomes, axis: .vertical)
                TextField("Follow-ups", text: $draft.meetingFollowUps, axis: .vertical)
                DebriefRatingPicker(title: "Usefulness", selection: $draft.meetingUsefulnessRating)
                TextField("Decisions made", text: $draft.meetingDecisions, axis: .vertical)
                TextField("Open questions", text: $draft.meetingOpenQuestions, axis: .vertical)
                TextField("Deadlines", text: $draft.meetingDeadlines, axis: .vertical)
                DebriefRatingPicker(title: "Preparedness", selection: $draft.meetingPreparednessRating)
                TextField("People involved", text: $draft.meetingPeopleInvolved, axis: .vertical)
                TextField("Remember before next time", text: $draft.meetingRememberBeforeNext, axis: .vertical)
            }

        case .social:
            Section("Social") {
                TextField("Worth remembering", text: $draft.socialWorthRemembering, axis: .vertical)
                TextField("Follow-up", text: $draft.socialFollowUp, axis: .vertical)
                Picker("Mood", selection: $draft.socialMood) {
                    Text("Not set").tag(Optional<SocialDebriefMood>.none)
                    ForEach(SocialDebriefMood.allCases) { mood in
                        Text(mood.displayName).tag(Optional(mood))
                    }
                }
                TextField("Who was there?", text: $draft.socialWhoWasThere, axis: .vertical)
                TextField("What did you learn?", text: $draft.socialLearnedAboutSomeone, axis: .vertical)
                TextField("What did you promise?", text: $draft.socialPromised, axis: .vertical)
                TextField("Anything different next time?", text: $draft.socialDifferentNextTime, axis: .vertical)
                Picker("Nourishment", selection: $draft.socialNourishment) {
                    Text("Not set").tag(Optional<SocialDebriefNourishment>.none)
                    ForEach(SocialDebriefNourishment.allCases) { nourishment in
                        Text(nourishment.displayName).tag(Optional(nourishment))
                    }
                }
            }

        case .generic, .pianoPractice, .jamSession, .viceSession:
            EmptyView()
        }
    }
}

private struct DebriefRatingPicker: View {
    let title: String
    @Binding var selection: Int?

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Not set").tag(Optional<Int>.none)
            ForEach(1...5, id: \.self) { value in
                Text("\(value)").tag(Optional(value))
            }
        }
    }
}

private struct TagSelectionGrid<Tag: CaseIterable & Hashable & Identifiable & Sendable>: View where Tag.AllCases: RandomAccessCollection {
    let title: String
    let allCases: Tag.AllCases
    let displayName: (Tag) -> String
    @Binding var selection: Set<Tag>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(allCases), id: \.self) { value in
                    Button {
                        if selection.contains(value) {
                            selection.remove(value)
                        } else {
                            selection.insert(value)
                        }
                    } label: {
                        Text(displayName(value))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selection.contains(value)
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DebriefTaskOutcomeCard: View {
    @Binding var taskOutcomeDraft: DebriefTaskOutcomeDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(taskOutcomeDraft.taskTitleSnapshot)
                        .font(.subheadline.weight(.semibold))

                    if taskOutcomeDraft.isMissingTask {
                        Text("Task no longer exists")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("Update task", isOn: $taskOutcomeDraft.didUpdateTaskStatus)
                    .disabled(taskOutcomeDraft.outcome != .completed)
                    .opacity(taskOutcomeDraft.outcome == .completed ? 1 : 0.45)
            }

            Picker("Outcome", selection: $taskOutcomeDraft.outcome) {
                ForEach(DebriefTaskOutcomeStatus.allCases) { outcome in
                    Text(outcome.displayName).tag(outcome)
                }
            }
            .onChange(of: taskOutcomeDraft.outcome) { _, newOutcome in
                if newOutcome == .completed {
                    taskOutcomeDraft.didUpdateTaskStatus = true
                } else if taskOutcomeDraft.didUpdateTaskStatus && newOutcome != .completed {
                    taskOutcomeDraft.didUpdateTaskStatus = false
                }
            }

            TextField(taskOutcomeDraft.notePlaceholder, text: $taskOutcomeDraft.note, axis: .vertical)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DebriefDraft: Equatable, Sendable {
    var templateKind: DebriefTemplateKind
    var quickOutcome: DebriefQuickOutcome?
    var quickNote: String
    var detailedResponses: [DebriefPromptResponse]
    var captureLines: [String]

    var workPlannedOutcome: WorkBlockPlannedOutcome?
    var workProductivityRating: Int?
    var workWhatHappened: String
    var workBlockers: Set<WorkBlockBlocker>
    var workBlockLengthFit: WorkBlockLengthFit?
    var workEnergyBeforeRating: Int?
    var workEnergyAfterRating: Int?
    var workFocusQualityRating: Int?
    var workNextStep: String

    var meetingOutcomes: String
    var meetingFollowUps: String
    var meetingUsefulnessRating: Int?
    var meetingDecisions: String
    var meetingOpenQuestions: String
    var meetingDeadlines: String
    var meetingPreparednessRating: Int?
    var meetingPeopleInvolved: String
    var meetingRememberBeforeNext: String

    var socialWorthRemembering: String
    var socialFollowUp: String
    var socialMood: SocialDebriefMood?
    var socialWhoWasThere: String
    var socialLearnedAboutSomeone: String
    var socialPromised: String
    var socialDifferentNextTime: String
    var socialNourishment: SocialDebriefNourishment?

    var taskOutcomeDrafts: [DebriefTaskOutcomeDraft]

    static let placeholder = DebriefDraft(
        templateKind: .generic,
        quickOutcome: nil,
        quickNote: "",
        detailedResponses: [],
        captureLines: [],
        workPlannedOutcome: nil,
        workProductivityRating: nil,
        workWhatHappened: "",
        workBlockers: [],
        workBlockLengthFit: nil,
        workEnergyBeforeRating: nil,
        workEnergyAfterRating: nil,
        workFocusQualityRating: nil,
        workNextStep: "",
        meetingOutcomes: "",
        meetingFollowUps: "",
        meetingUsefulnessRating: nil,
        meetingDecisions: "",
        meetingOpenQuestions: "",
        meetingDeadlines: "",
        meetingPreparednessRating: nil,
        meetingPeopleInvolved: "",
        meetingRememberBeforeNext: "",
        socialWorthRemembering: "",
        socialFollowUp: "",
        socialMood: nil,
        socialWhoWasThere: "",
        socialLearnedAboutSomeone: "",
        socialPromised: "",
        socialDifferentNextTime: "",
        socialNourishment: nil,
        taskOutcomeDrafts: []
    )

    init(
        templateKind: DebriefTemplateKind,
        quickOutcome: DebriefQuickOutcome?,
        quickNote: String,
        detailedResponses: [DebriefPromptResponse],
        captureLines: [String],
        workPlannedOutcome: WorkBlockPlannedOutcome?,
        workProductivityRating: Int?,
        workWhatHappened: String,
        workBlockers: Set<WorkBlockBlocker>,
        workBlockLengthFit: WorkBlockLengthFit?,
        workEnergyBeforeRating: Int?,
        workEnergyAfterRating: Int?,
        workFocusQualityRating: Int?,
        workNextStep: String,
        meetingOutcomes: String,
        meetingFollowUps: String,
        meetingUsefulnessRating: Int?,
        meetingDecisions: String,
        meetingOpenQuestions: String,
        meetingDeadlines: String,
        meetingPreparednessRating: Int?,
        meetingPeopleInvolved: String,
        meetingRememberBeforeNext: String,
        socialWorthRemembering: String,
        socialFollowUp: String,
        socialMood: SocialDebriefMood?,
        socialWhoWasThere: String,
        socialLearnedAboutSomeone: String,
        socialPromised: String,
        socialDifferentNextTime: String,
        socialNourishment: SocialDebriefNourishment?,
        taskOutcomeDrafts: [DebriefTaskOutcomeDraft]
    ) {
        self.templateKind = templateKind
        self.quickOutcome = quickOutcome
        self.quickNote = quickNote
        self.detailedResponses = detailedResponses
        self.captureLines = captureLines
        self.workPlannedOutcome = workPlannedOutcome
        self.workProductivityRating = workProductivityRating
        self.workWhatHappened = workWhatHappened
        self.workBlockers = workBlockers
        self.workBlockLengthFit = workBlockLengthFit
        self.workEnergyBeforeRating = workEnergyBeforeRating
        self.workEnergyAfterRating = workEnergyAfterRating
        self.workFocusQualityRating = workFocusQualityRating
        self.workNextStep = workNextStep
        self.meetingOutcomes = meetingOutcomes
        self.meetingFollowUps = meetingFollowUps
        self.meetingUsefulnessRating = meetingUsefulnessRating
        self.meetingDecisions = meetingDecisions
        self.meetingOpenQuestions = meetingOpenQuestions
        self.meetingDeadlines = meetingDeadlines
        self.meetingPreparednessRating = meetingPreparednessRating
        self.meetingPeopleInvolved = meetingPeopleInvolved
        self.meetingRememberBeforeNext = meetingRememberBeforeNext
        self.socialWorthRemembering = socialWorthRemembering
        self.socialFollowUp = socialFollowUp
        self.socialMood = socialMood
        self.socialWhoWasThere = socialWhoWasThere
        self.socialLearnedAboutSomeone = socialLearnedAboutSomeone
        self.socialPromised = socialPromised
        self.socialDifferentNextTime = socialDifferentNextTime
        self.socialNourishment = socialNourishment
        self.taskOutcomeDrafts = taskOutcomeDrafts
    }

    init(
        candidate: CalendarDebriefCandidate,
        existingDebrief: CalendarDebriefRecord?,
        blockFocus: CalendarBlockFocus? = nil,
        selectedTasks: [MyTask] = []
    ) {
        templateKind = existingDebrief?.templateKind ?? candidate.suggestedTemplate
        quickOutcome = existingDebrief?.quickOutcome
        quickNote = existingDebrief?.quickNote ?? ""
        detailedResponses = existingDebrief?.detailedResponses.isEmpty == false
            ? existingDebrief!.detailedResponses
            : Self.responses(for: existingDebrief?.templateKind ?? candidate.suggestedTemplate)
        captureLines = []

        workPlannedOutcome = existingDebrief?.workPlannedOutcome
        workProductivityRating = existingDebrief?.workProductivityRating
        workWhatHappened = existingDebrief?.workWhatHappened ?? ""
        workBlockers = Set(existingDebrief?.workBlockers ?? [])
        workBlockLengthFit = existingDebrief?.workBlockLengthFit
        workEnergyBeforeRating = existingDebrief?.workEnergyBeforeRating
        workEnergyAfterRating = existingDebrief?.workEnergyAfterRating
        workFocusQualityRating = existingDebrief?.workFocusQualityRating
        workNextStep = existingDebrief?.workNextStep ?? ""

        meetingOutcomes = existingDebrief?.meetingOutcomes ?? ""
        meetingFollowUps = existingDebrief?.meetingFollowUps ?? ""
        meetingUsefulnessRating = existingDebrief?.meetingUsefulnessRating
        meetingDecisions = existingDebrief?.meetingDecisions ?? ""
        meetingOpenQuestions = existingDebrief?.meetingOpenQuestions ?? ""
        meetingDeadlines = existingDebrief?.meetingDeadlines ?? ""
        meetingPreparednessRating = existingDebrief?.meetingPreparednessRating
        meetingPeopleInvolved = existingDebrief?.meetingPeopleInvolved ?? ""
        meetingRememberBeforeNext = existingDebrief?.meetingRememberBeforeNext ?? ""

        socialWorthRemembering = existingDebrief?.socialWorthRemembering ?? ""
        socialFollowUp = existingDebrief?.socialFollowUp ?? ""
        socialMood = existingDebrief?.socialMood
        socialWhoWasThere = existingDebrief?.socialWhoWasThere ?? ""
        socialLearnedAboutSomeone = existingDebrief?.socialLearnedAboutSomeone ?? ""
        socialPromised = existingDebrief?.socialPromised ?? ""
        socialDifferentNextTime = existingDebrief?.socialDifferentNextTime ?? ""
        socialNourishment = existingDebrief?.socialNourishment

        taskOutcomeDrafts = Self.taskOutcomeDrafts(
            from: blockFocus,
            selectedTasks: selectedTasks,
            existingDebrief: existingDebrief
        )
    }

    var templateDefinition: DebriefTemplateDefinition {
        DebriefTemplates.definition(for: templateKind)
    }

    mutating func rebuildDetailedResponses() {
        let template = templateDefinition
        let responseLookup = Dictionary(uniqueKeysWithValues: detailedResponses.map { ($0.id, $0) })
        detailedResponses = template.detailedPrompts.map { prompt in
            if let response = responseLookup[prompt.id] {
                return response
            }

            return DebriefPromptResponse(id: prompt.id, prompt: prompt.prompt, response: "")
        }
    }

    func makeDebriefRecord(
        candidate: CalendarDebriefCandidate,
        status: CalendarDebriefStatus,
        completedAt: Date?,
        noDebriefNeeded: Bool,
        captureIDs: [UUID],
        taskOutcomes: [DebriefTaskOutcome],
        preserving existingDebrief: CalendarDebriefRecord?
    ) -> CalendarDebriefRecord {
        CalendarDebriefRecord(
            id: existingDebrief?.id ?? UUID(),
            sourceType: candidate.sourceType,
            sourceID: candidate.sourceID,
            sourceContext: candidate.sourceContext,
            eventKey: candidate.eventKey,
            eventIdentifier: candidate.eventIdentifier,
            calendarIdentifier: candidate.calendarIdentifier,
            calendarTitleSnapshot: candidate.calendarTitle,
            titleSnapshot: candidate.title,
            startDateSnapshot: candidate.start,
            endDateSnapshot: candidate.end,
            templateKind: templateKind,
            createdAt: existingDebrief?.createdAt ?? Date(),
            updatedAt: Date(),
            completedAt: completedAt,
            status: status,
            noDebriefNeeded: noDebriefNeeded,
            quickOutcome: quickOutcome,
            quickNote: quickNote,
            essentialNote: essentialNote,
            detailedResponses: detailedResponses,
            createdCaptureIDs: (existingDebrief?.createdCaptureIDs ?? []) + captureIDs,
            workPlannedOutcome: workPlannedOutcome,
            workProductivityRating: workProductivityRating,
            workWhatHappened: workWhatHappened,
            workBlockers: Array(workBlockers),
            workBlockLengthFit: workBlockLengthFit,
            workEnergyBeforeRating: workEnergyBeforeRating,
            workEnergyAfterRating: workEnergyAfterRating,
            workFocusQualityRating: workFocusQualityRating,
            workNextStep: workNextStep,
            meetingOutcomes: meetingOutcomes,
            meetingFollowUps: meetingFollowUps,
            meetingUsefulnessRating: meetingUsefulnessRating,
            meetingDecisions: meetingDecisions,
            meetingOpenQuestions: meetingOpenQuestions,
            meetingDeadlines: meetingDeadlines,
            meetingPreparednessRating: meetingPreparednessRating,
            meetingPeopleInvolved: meetingPeopleInvolved,
            meetingRememberBeforeNext: meetingRememberBeforeNext,
            socialWorthRemembering: socialWorthRemembering,
            socialFollowUp: socialFollowUp,
            socialMood: socialMood,
            socialWhoWasThere: socialWhoWasThere,
            socialLearnedAboutSomeone: socialLearnedAboutSomeone,
            socialPromised: socialPromised,
            socialDifferentNextTime: socialDifferentNextTime,
            socialNourishment: socialNourishment,
            taskOutcomes: taskOutcomes
        )
    }

    private var essentialNote: String? {
        switch templateKind {
        case .workBlock:
            return workWhatHappened.isEmpty ? quickNote : workWhatHappened
        case .meeting:
            return meetingOutcomes.isEmpty ? quickNote : meetingOutcomes
        case .social:
            return socialWorthRemembering.isEmpty ? quickNote : socialWorthRemembering
        case .generic, .pianoPractice, .jamSession, .viceSession:
            return quickNote
        }
    }

    private static func responses(for templateKind: DebriefTemplateKind) -> [DebriefPromptResponse] {
        DebriefTemplates.definition(for: templateKind).detailedPrompts.map { prompt in
            DebriefPromptResponse(id: prompt.id, prompt: prompt.prompt, response: "")
        }
    }

    private static func taskOutcomeDrafts(
        from blockFocus: CalendarBlockFocus?,
        selectedTasks: [MyTask],
        existingDebrief: CalendarDebriefRecord?
    ) -> [DebriefTaskOutcomeDraft] {
        guard let blockFocus, blockFocus.selectedTaskIDs.isEmpty == false else {
            return existingDebrief?.taskOutcomes.map { taskOutcome in
                DebriefTaskOutcomeDraft(
                    taskID: taskOutcome.taskID,
                    taskTitleSnapshot: taskOutcome.taskTitleSnapshot,
                    outcome: taskOutcome.outcome,
                    note: taskOutcome.note ?? "",
                    didUpdateTaskStatus: taskOutcome.didUpdateTaskStatus,
                    isMissingTask: false
                )
            } ?? []
        }

        let selectedTaskLookup = Dictionary(uniqueKeysWithValues: selectedTasks.map { ($0.id, $0) })
        let existingOutcomeLookup = Dictionary(uniqueKeysWithValues: existingDebrief?.taskOutcomes.map {
            ($0.taskID, $0)
        } ?? [])

        return blockFocus.selectedTaskIDs.map { taskID in
            if let task = selectedTaskLookup[taskID] {
                let existingOutcome = existingOutcomeLookup[taskID]
                return DebriefTaskOutcomeDraft(
                    taskID: task.id,
                    taskTitleSnapshot: task.title,
                    outcome: existingOutcome?.outcome ?? .notTouched,
                    note: existingOutcome?.note ?? "",
                    didUpdateTaskStatus: existingOutcome?.didUpdateTaskStatus ?? false,
                    isMissingTask: false
                )
            }

            let existingOutcome = existingOutcomeLookup[taskID]
            return DebriefTaskOutcomeDraft(
                taskID: taskID,
                taskTitleSnapshot: existingOutcome?.taskTitleSnapshot ?? "Deleted task",
                outcome: existingOutcome?.outcome ?? .notTouched,
                note: existingOutcome?.note ?? "",
                didUpdateTaskStatus: existingOutcome?.didUpdateTaskStatus ?? false,
                isMissingTask: true
            )
        }
    }
}

struct DebriefTaskOutcomeDraft: Identifiable, Equatable, Sendable {
    let taskID: UUID
    var taskTitleSnapshot: String
    var outcome: DebriefTaskOutcomeStatus
    var note: String
    var didUpdateTaskStatus: Bool
    var isMissingTask: Bool

    var id: UUID {
        taskID
    }

    var notePlaceholder: String {
        switch outcome {
        case .completed:
            return "What got finished?"
        case .partlyDone:
            return "What changed?"
        case .stillOpen:
            return "What remains?"
        case .blocked:
            return "Why blocked?"
        case .notTouched:
            return "What happened instead?"
        }
    }
}

private extension CalendarDebriefCandidate {
    var timeRangeText: String {
        "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }
}
