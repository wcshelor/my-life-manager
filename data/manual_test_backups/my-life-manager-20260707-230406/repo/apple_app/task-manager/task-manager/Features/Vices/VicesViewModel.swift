import Combine
import Foundation

nonisolated struct ViceCardSummary: Identifiable, Equatable, Sendable {
    let vice: Vice
    let todayCount: Int
    let lastLogAt: Date?
    let recentGaps: [TimeInterval]
    let goalProgress: ViceGoalProgress?
    let linkedRoutine: Routine?
    let activeUnlock: ViceRoutineUnlock?

    var id: UUID {
        vice.id
    }

    func timeSinceLastLogText(now: Date) -> String? {
        guard let lastLogAt else {
            return nil
        }

        return ViceDurationFormatter.elapsedSince(lastLogAt, now: now)
    }

    func recentHistorySummaryText() -> String? {
        guard recentGaps.isEmpty == false else {
            return nil
        }

        let formattedGaps = recentGaps.map { gap in
            ViceDurationFormatter.format(gap, style: .compact)
        }
        return formattedGaps.joined(separator: " · ")
    }

    func unlockSummaryText(now: Date) -> String? {
        guard let linkedRoutine else {
            return nil
        }

        guard let activeUnlock, activeUnlock.isActive(at: now) else {
            return "Do \(linkedRoutine.name) before logging."
        }

        let remaining = max(0, activeUnlock.expiresAt.timeIntervalSince(now))
        return "Routine unlocked for \(ViceDurationFormatter.format(remaining, style: .compact))."
    }
}

enum ViceLogAttemptResult: Equatable {
    case logged
    case needsRoutine(viceID: UUID, routineID: UUID)
}

nonisolated enum ViceRoutineGatePolicy {
    static let unlockWindow: TimeInterval = 15 * 60
}

@MainActor
final class VicesViewModel: ObservableObject {
    @Published private(set) var vices: [Vice] = []
    @Published private(set) var logs: [ViceLog] = []
    @Published private(set) var goals: [ViceGoal] = []
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var activeUnlocks: [ViceRoutineUnlock] = []
    @Published private(set) var pendingUndoLogID: UUID?
    @Published private(set) var pendingUndoViceName: String?
    @Published private(set) var errorMessage: String?

    private let viceRepository: any ViceRepository
    private let routineRepository: any RoutineRepository
    private let debriefRepository: any DebriefRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false
    private var undoExpirationTask: Task<Void, Never>?
    private let sessionCandidateFactory = ViceSessionDebriefCandidateFactory()

    init(
        viceRepository: any ViceRepository,
        routineRepository: any RoutineRepository,
        debriefRepository: any DebriefRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.viceRepository = viceRepository
        self.routineRepository = routineRepository
        self.debriefRepository = debriefRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    deinit {
        undoExpirationTask?.cancel()
    }

    var activeVices: [Vice] {
        vices.filter { $0.isArchived == false }
    }

    var summaries: [ViceCardSummary] {
        let logsByViceID = Dictionary(grouping: logs, by: \.viceID)
        let now = nowProvider()
        let activeGoalsByViceID = Dictionary(
            uniqueKeysWithValues: goals.filter { $0.isActive(at: now) }.map { ($0.viceID, $0) }
        )
        let routineByID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let unlockByViceID = Dictionary(
            uniqueKeysWithValues: activeUnlocks.map { ($0.viceID, $0) }
        )

        return activeVices.map { vice in
            let viceLogs = logsByViceID[vice.id] ?? []
            let todayCount = viceLogs
                .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
                .reduce(0) { partialResult, log in
                    partialResult + log.amount
                }
            let goalProgress = activeGoalsByViceID[vice.id].map { goal in
                let goalCount = viceLogs
                    .filter { goal.contains($0.timestamp) }
                    .reduce(0) { partialResult, log in
                        partialResult + log.amount
                    }
                return ViceGoalProgress(goal: goal, count: goalCount)
            }

            return ViceCardSummary(
                vice: vice,
                todayCount: todayCount,
                lastLogAt: viceLogs.first?.timestamp,
                recentGaps: viceLogs.sortedForViceHistory().gapsBetweenRecentInstances(),
                goalProgress: goalProgress,
                linkedRoutine: vice.linkedRoutineID.flatMap { routineByID[$0] },
                activeUnlock: unlockByViceID[vice.id]
            )
        }
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            let now = nowProvider()
            try routineRepository.deleteExpiredViceRoutineUnlocks(asOf: now)
            vices = try viceRepository.fetchVices(includeArchived: true)
            logs = try viceRepository.fetchViceLogs()
            goals = try viceRepository.fetchViceGoals(includeArchived: true)
            routines = try routineRepository.fetchRoutines()
            activeUnlocks = try routines.compactMap { routine in
                guard routine.kind == .viceLinked, let viceID = routine.viceID else {
                    return nil
                }
                guard let unlock = try routineRepository.fetchViceRoutineUnlock(for: viceID, routineID: routine.id),
                      unlock.isActive(at: now) else {
                    return nil
                }
                return unlock
            }
            closeExpiredSessionsAndQueueDebriefs(now: now)
            archiveExpiredGoals(now: now)
            goals = try viceRepository.fetchViceGoals(includeArchived: true)
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load Vices: \(error.localizedDescription)"
        }
    }

    func saveVice(
        name: String,
        unitLabel: String,
        replacingViceWithID originalID: UUID? = nil
    ) -> Bool {
        guard var vice = Vice(newName: name, unitLabel: unitLabel, createdAt: nowProvider()) else {
            errorMessage = "Enter a vice name and unit label."
            return false
        }

        if let originalID,
           let existingVice = vices.first(where: { $0.id == originalID }) {
            vice = Vice(
                id: existingVice.id,
                name: vice.name,
                unitLabel: vice.unitLabel,
                linkedRoutineID: existingVice.linkedRoutineID,
                createdAt: existingVice.createdAt,
                updatedAt: nowProvider(),
                isArchived: existingVice.isArchived
            )
        }

        do {
            try viceRepository.saveVice(vice, replacingViceWithID: originalID)
            load()
            return true
        } catch {
            errorMessage = "Unable to save vice: \(error.localizedDescription)"
            return false
        }
    }

    func archiveVice(withID id: UUID) {
        do {
            try viceRepository.archiveVice(withID: id, archivedAt: nowProvider())
            load()
        } catch {
            errorMessage = "Unable to archive vice: \(error.localizedDescription)"
        }
    }

    func saveGoal(
        viceID: UUID,
        maxOccurrences: Int,
        deadline: Date,
        replacingGoalWithID originalID: UUID? = nil
    ) -> Bool {
        let now = nowProvider()
        let existingGoal = goals.first(where: { $0.id == originalID })
        var goal = ViceGoal(
            viceID: viceID,
            maxOccurrences: maxOccurrences,
            startDate: existingGoal?.startDate ?? now,
            deadline: deadline,
            createdAt: existingGoal?.createdAt ?? now,
            updatedAt: now
        )

        if let existingGoal {
            goal = ViceGoal(
                id: existingGoal.id,
                viceID: existingGoal.viceID,
                maxOccurrences: maxOccurrences,
                startDate: existingGoal.startDate,
                deadline: deadline,
                createdAt: existingGoal.createdAt,
                updatedAt: now,
                archivedAt: existingGoal.archivedAt
            )
        }

        do {
            let activeGoalsForVice = goals.filter { $0.viceID == viceID && $0.isArchived == false && $0.id != goal.id }
            for activeGoal in activeGoalsForVice {
                try viceRepository.archiveViceGoal(withID: activeGoal.id, archivedAt: now)
            }

            try viceRepository.saveViceGoal(goal, replacingGoalWithID: originalID)
            load()
            return true
        } catch {
            errorMessage = "Unable to save goal: \(error.localizedDescription)"
            return false
        }
    }

    func attemptLogVice(viceID: UUID) -> ViceLogAttemptResult? {
        guard let vice = vices.first(where: { $0.id == viceID }) else {
            return nil
        }

        if let routineID = vice.linkedRoutineID,
           let routine = routines.first(where: { $0.id == routineID && $0.kind == .viceLinked }),
           let owningViceID = routine.viceID {
            do {
                if let unlock = try routineRepository.fetchViceRoutineUnlock(for: owningViceID, routineID: routine.id),
                   unlock.isActive(at: nowProvider()) {
                    logViceHit(vice: vice)
                    return .logged
                }
            } catch {
                errorMessage = "Unable to check vice routine gate: \(error.localizedDescription)"
                return nil
            }

            return .needsRoutine(viceID: vice.id, routineID: routine.id)
        }

        logViceHit(vice: vice)
        return .logged
    }

    func logViceHit(viceID: UUID) {
        guard let vice = vices.first(where: { $0.id == viceID }) else {
            return
        }
        logViceHit(vice: vice)
    }

    func saveViceRoutine(
        _ routine: Routine,
        for viceID: UUID,
        replacingRoutineWithID originalID: UUID? = nil
    ) -> Bool {
        do {
            let existingVice = try viceRepository.vice(withID: viceID)
            let linkedRoutine = Routine(
                id: originalID ?? routine.id,
                name: routine.name,
                notes: routine.notes,
                kind: .viceLinked,
                viceID: viceID,
                activeWeekdays: [],
                items: routine.items,
                stepLinks: routine.stepLinks,
                isArchived: routine.isArchived,
                createdAt: routine.createdAt,
                updatedAt: routine.updatedAt
            )
            try routineRepository.saveRoutine(linkedRoutine, replacingRoutineWithID: originalID)
            if let existingVice {
                let updatedVice = Vice(
                    id: existingVice.id,
                    name: existingVice.name,
                    unitLabel: existingVice.unitLabel,
                    linkedRoutineID: linkedRoutine.id,
                    createdAt: existingVice.createdAt,
                    updatedAt: nowProvider(),
                    isArchived: existingVice.isArchived
                )
                try viceRepository.saveVice(updatedVice, replacingViceWithID: existingVice.id)
            }
            load()
            return true
        } catch {
            errorMessage = "Unable to save vice routine: \(error.localizedDescription)"
            return false
        }
    }

    func linkExistingRoutine(_ routineID: UUID, toViceID viceID: UUID) -> Bool {
        do {
            guard let sourceRoutine = try routineRepository.routine(withID: routineID),
                  let existingVice = try viceRepository.vice(withID: viceID) else {
                errorMessage = "Unable to find the selected routine."
                return false
            }

            let copiedRoutine = Routine(
                name: sourceRoutine.name,
                notes: sourceRoutine.notes,
                kind: .viceLinked,
                viceID: viceID,
                activeWeekdays: [],
                items: sourceRoutine.items,
                stepLinks: sourceRoutine.stepLinks,
                isArchived: false,
                createdAt: nowProvider(),
                updatedAt: nowProvider()
            )
            try routineRepository.saveRoutine(copiedRoutine, replacingRoutineWithID: nil)
            let updatedVice = Vice(
                id: existingVice.id,
                name: existingVice.name,
                unitLabel: existingVice.unitLabel,
                linkedRoutineID: copiedRoutine.id,
                createdAt: existingVice.createdAt,
                updatedAt: nowProvider(),
                isArchived: existingVice.isArchived
            )
            try viceRepository.saveVice(updatedVice, replacingViceWithID: existingVice.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to link routine: \(error.localizedDescription)"
            return false
        }
    }

    func completeViceRoutineUnlock(viceID: UUID, routineID: UUID) -> Bool {
        let now = nowProvider()
        let unlock = ViceRoutineUnlock(
            viceID: viceID,
            routineID: routineID,
            completedAt: now,
            expiresAt: now.addingTimeInterval(ViceRoutineGatePolicy.unlockWindow),
            updatedAt: now
        )

        do {
            let existingUnlock = try routineRepository.fetchViceRoutineUnlock(for: viceID, routineID: routineID)
            try routineRepository.saveViceRoutineUnlock(unlock, replacingUnlockWithID: existingUnlock?.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to unlock vice routine: \(error.localizedDescription)"
            return false
        }
    }

    func undoLastLog() {
        guard let logID = pendingUndoLogID else {
            return
        }

        do {
            try viceRepository.deleteViceLog(withID: logID)
            clearUndoState()
            load()
        } catch {
            errorMessage = "Unable to undo log: \(error.localizedDescription)"
        }
    }

    private func setUndoState(logID: UUID, viceName: String) {
        pendingUndoLogID = logID
        pendingUndoViceName = viceName
        undoExpirationTask?.cancel()
        undoExpirationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard Task.isCancelled == false else {
                return
            }
            await self?.clearUndoState()
        }
    }

    private func clearUndoState() {
        pendingUndoLogID = nil
        pendingUndoViceName = nil
        undoExpirationTask?.cancel()
        undoExpirationTask = nil
    }

    private func closeExpiredSessionsAndQueueDebriefs(now: Date) {
        do {
            let sessions = try viceRepository.fetchViceSessions()
            let activeSessions = sessions.filter { $0.isClosed == false }
            for session in activeSessions where session.isActive(at: now) == false {
                try closeSession(session, now: now)
            }
        } catch {
            errorMessage = "Unable to update vice sessions: \(error.localizedDescription)"
        }
    }

    private func archiveExpiredGoals(now: Date) {
        do {
            for goal in goals where goal.isArchived == false && goal.isActive(at: now) == false {
                try viceRepository.archiveViceGoal(withID: goal.id, archivedAt: now)
            }
        } catch {
            errorMessage = "Unable to update vice goals: \(error.localizedDescription)"
        }
    }

    private func logViceHit(vice: Vice) {
        do {
            let log = try ViceLogRecorder.recordHit(
                for: vice,
                at: nowProvider(),
                repository: viceRepository
            )
            load()
            setUndoState(logID: log.id, viceName: vice.name)
        } catch {
            errorMessage = "Unable to log vice: \(error.localizedDescription)"
        }
    }

    private func closeSession(_ session: ViceSession, now: Date) throws {
        guard let vice = vices.first(where: { $0.id == session.viceID }) else {
            return
        }

        var closedSession = session
        closedSession.closedAt = session.closingDate()
        try viceRepository.saveViceSession(closedSession)

        let candidate = sessionCandidateFactory.makeCandidate(
            for: closedSession,
            vice: vice,
            now: now
        )

        if try debriefRepository.debrief(withEventKey: candidate.eventKey) == nil {
            try debriefRepository.saveDebrief(candidate, replacingDebriefWithID: nil)
        }
    }
}
