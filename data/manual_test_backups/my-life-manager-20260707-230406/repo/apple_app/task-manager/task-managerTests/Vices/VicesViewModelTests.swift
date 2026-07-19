import Foundation
import Testing
@testable import task_manager

@MainActor
struct VicesViewModelTests {
    @Test func tappingViceCardLogsOneEventAndUpdatesSummary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 12))!
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)

        #expect(viewModel.summaries.first?.todayCount == 1)
        #expect(viewModel.pendingUndoLogID != nil)
        #expect(viewModel.pendingUndoViceName == "Dab Pen")
        #expect(repository.sessions.count == 1)
        #expect(repository.sessions.first?.hitCount == 1)
        #expect(debriefRepository.debriefs.isEmpty)
    }

    @Test func undoWithinWindowDeletesNewLog() {
        let now = Date(timeIntervalSince1970: 2_000)
        let vice = Vice(name: "Alcohol", unitLabel: "Drinks")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)
        let logCountBeforeUndo = viewModel.logs.count
        viewModel.undoLastLog()

        #expect(logCountBeforeUndo == 1)
        #expect(viewModel.logs.isEmpty)
        #expect(viewModel.pendingUndoLogID == nil)
    }

    @Test func undoExpiresAfterFiveSeconds() async {
        let now = Date(timeIntervalSince1970: 3_000)
        let vice = Vice(name: "Social Media", unitLabel: "Sessions")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)
        #expect(viewModel.pendingUndoLogID != nil)

        try? await Task.sleep(nanoseconds: 5_300_000_000)

        #expect(viewModel.pendingUndoLogID == nil)
        #expect(viewModel.logs.count == 1)
    }

    @Test func hitInsideThreeHourWindowAttachesToExistingSession() {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 10_000)
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let existingSession = ViceSession(
            viceID: vice.id,
            startedAt: base,
            lastHitAt: base.addingTimeInterval(3_200),
            hitCount: 1
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [], sessions: [existingSession])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            calendar: calendar,
            nowProvider: { base.addingTimeInterval(3_500) }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)

        #expect(repository.sessions.count == 1)
        #expect(repository.sessions.first?.hitCount == 2)
        #expect(repository.sessions.first?.lastHitAt == base.addingTimeInterval(3_500))
    }

    @Test func hitAfterSessionWindowCreatesNewSession() {
        let base = Date(timeIntervalSince1970: 20_000)
        let vice = Vice(name: "Alcohol", unitLabel: "Drinks")
        let expiredSession = ViceSession(
            viceID: vice.id,
            startedAt: base,
            lastHitAt: base.addingTimeInterval(10_000),
            hitCount: 3
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [], sessions: [expiredSession])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { base.addingTimeInterval(20_500) }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)

        #expect(repository.sessions.count == 2)
        #expect(repository.sessions.sortedForViceSessions().first?.hitCount == 1)
    }

    @Test func timeSinceLastLogAndRecentGapsAreFormatted() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 15, minute: 0, second: 0))!
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let logs = [
            ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-3_600)),
            ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-7_200)),
            ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-10_800))
        ]
        let repository = InMemoryViceRepository(vices: [vice], logs: logs)
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        let summary = viewModel.summaries.first

        #expect(summary?.timeSinceLastLogText(now: now) == "01:00:00")
        #expect(summary?.recentHistorySummaryText() == "01:00:00 · 01:00:00")
    }

    @Test func sessionClosureCreatesSingleDebriefCandidate() {
        let base = Date(timeIntervalSince1970: 30_000)
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let openSession = ViceSession(
            viceID: vice.id,
            startedAt: base,
            lastHitAt: base.addingTimeInterval(100),
            hitCount: 5
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [], sessions: [openSession])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { base.addingTimeInterval(3 * 3_600 + 1) }
        )

        viewModel.loadIfNeeded()

        #expect(repository.sessions.first?.closedAt != nil)
        #expect(debriefRepository.debriefs.count == 1)
        #expect(debriefRepository.debriefs.first?.sourceType == .viceSession)
        #expect(debriefRepository.debriefs.first?.titleSnapshot.contains("5 hits") == true)
    }

    @Test func nonSessionVicesStillWorkAsNormalOneTapLogs() {
        let now = Date(timeIntervalSince1970: 40_000)
        let vice = Vice(name: "Coffee", unitLabel: "Cups")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)

        #expect(viewModel.logs.count == 1)
        #expect(repository.sessions.count == 1)
        #expect(repository.sessions.first?.hitCount == 1)
    }

    @Test func saveGoalCreatesProgressForViceCard() {
        let now = Date(timeIntervalSince1970: 50_000)
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        let saved = viewModel.saveGoal(
            viceID: vice.id,
            maxOccurrences: 5,
            deadline: now.addingTimeInterval(86_400)
        )

        #expect(saved)
        #expect(repository.goals.count == 1)
        #expect(viewModel.summaries.first?.goalProgress?.count == 0)
        #expect(viewModel.summaries.first?.goalProgress?.goal.maxOccurrences == 5)
    }

    @Test func goalProgressOnlyCountsLogsInsideGoalWindow() {
        let now = Date(timeIntervalSince1970: 60_000)
        let start = now.addingTimeInterval(-3_600)
        let deadline = now.addingTimeInterval(3_600)
        let vice = Vice(name: "Alcohol", unitLabel: "Drinks")
        let goal = ViceGoal(
            viceID: vice.id,
            maxOccurrences: 4,
            startDate: start,
            deadline: deadline,
            createdAt: start
        )
        let logs = [
            ViceLog(viceID: vice.id, timestamp: start.addingTimeInterval(-10), amount: 2),
            ViceLog(viceID: vice.id, timestamp: start.addingTimeInterval(300), amount: 1),
            ViceLog(viceID: vice.id, timestamp: now, amount: 2),
            ViceLog(viceID: vice.id, timestamp: deadline.addingTimeInterval(10), amount: 3)
        ]
        let repository = InMemoryViceRepository(vices: [vice], logs: logs, goals: [goal])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.summaries.first?.goalProgress?.count == 3)
    }

    @Test func goalStatusTransitionsFromGreenToYellowToRed() {
        let now = Date(timeIntervalSince1970: 70_000)
        let goal = ViceGoal(
            viceID: UUID(),
            maxOccurrences: 10,
            startDate: now,
            deadline: now.addingTimeInterval(3_600)
        )

        #expect(goal.status(forCount: 2) == .onTrack)
        #expect(goal.status(forCount: 7) == .warning)
        #expect(goal.status(forCount: 10) == .exceeded)
    }

    @Test func savingNewGoalArchivesPreviousActiveGoalForVice() {
        let now = Date(timeIntervalSince1970: 80_000)
        let vice = Vice(name: "Social Media", unitLabel: "Sessions")
        let existingGoal = ViceGoal(
            viceID: vice.id,
            maxOccurrences: 2,
            startDate: now.addingTimeInterval(-600),
            deadline: now.addingTimeInterval(3_600),
            createdAt: now.addingTimeInterval(-600)
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [], goals: [existingGoal])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        let saved = viewModel.saveGoal(
            viceID: vice.id,
            maxOccurrences: 5,
            deadline: now.addingTimeInterval(7_200)
        )

        #expect(saved)
        #expect(repository.goals.count == 2)
        #expect(repository.goals.filter { $0.isArchived == false }.count == 1)
        #expect(repository.goals.first(where: { $0.id == existingGoal.id })?.isArchived == true)
        #expect(viewModel.summaries.first?.goalProgress?.goal.maxOccurrences == 5)
    }

    @Test func expiredGoalIsArchivedOnLoad() {
        let now = Date(timeIntervalSince1970: 90_000)
        let vice = Vice(name: "Coffee", unitLabel: "Cups")
        let expiredGoal = ViceGoal(
            viceID: vice.id,
            maxOccurrences: 3,
            startDate: now.addingTimeInterval(-7_200),
            deadline: now.addingTimeInterval(-60),
            createdAt: now.addingTimeInterval(-7_200)
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [], goals: [expiredGoal])
        let debriefRepository = InMemoryDebriefRepository()
        let routineRepository = InMemoryRoutineRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(repository.goals.first?.isArchived == true)
        #expect(viewModel.summaries.first?.goalProgress == nil)
    }

    @Test func linkedViceRequiresRoutineBeforeLogging() {
        let now = Date(timeIntervalSince1970: 100_000)
        let routine = Routine(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174801")!,
            name: "Smoke Gate",
            kind: .viceLinked,
            viceID: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174802")!,
            items: [RoutineItem(title: "Walk", position: 0)]
        )
        let vice = Vice(
            id: routine.viceID!,
            name: "Smoke",
            unitLabel: "Hits",
            linkedRoutineID: routine.id
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let routineRepository = InMemoryRoutineRepository(routines: [routine])
        let debriefRepository = InMemoryDebriefRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        let result = viewModel.attemptLogVice(viceID: vice.id)

        #expect(result == .needsRoutine(viceID: vice.id, routineID: routine.id))
        #expect(viewModel.logs.isEmpty)
    }

    @Test func completingViceRoutineUnlockAllowsLoggingUntilWindowExpires() {
        let base = Date(timeIntervalSince1970: 110_000)
        let routine = Routine(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174811")!,
            name: "Drink Gate",
            kind: .viceLinked,
            viceID: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174812")!,
            items: [RoutineItem(title: "Pushups", position: 0)]
        )
        let vice = Vice(
            id: routine.viceID!,
            name: "Alcohol",
            unitLabel: "Drinks",
            linkedRoutineID: routine.id
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let routineRepository = InMemoryRoutineRepository(routines: [routine])
        let debriefRepository = InMemoryDebriefRepository()
        var currentNow = base
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { currentNow }
        )

        viewModel.loadIfNeeded()
        #expect(viewModel.completeViceRoutineUnlock(viceID: vice.id, routineID: routine.id))
        #expect(viewModel.attemptLogVice(viceID: vice.id) == .logged)
        #expect(viewModel.logs.count == 1)

        currentNow = base.addingTimeInterval(ViceRoutineGatePolicy.unlockWindow + 1)
        viewModel.load()

        #expect(viewModel.attemptLogVice(viceID: vice.id) == .needsRoutine(viceID: vice.id, routineID: routine.id))
    }

    @Test func linkingExistingRoutineDuplicatesViceLinkedCopy() {
        let now = Date(timeIntervalSince1970: 120_000)
        let vice = Vice(name: "Social Media", unitLabel: "Sessions")
        let standardRoutine = Routine(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174821")!,
            name: "Phone Gate",
            items: [RoutineItem(title: "Read one page", position: 0)]
        )
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let routineRepository = InMemoryRoutineRepository(routines: [standardRoutine])
        let debriefRepository = InMemoryDebriefRepository()
        let viewModel = VicesViewModel(
            viceRepository: repository,
            routineRepository: routineRepository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        #expect(viewModel.linkExistingRoutine(standardRoutine.id, toViceID: vice.id))

        #expect(routineRepository.routines.count == 2)
        let copiedRoutine = routineRepository.routines.first { $0.id != standardRoutine.id }
        #expect(copiedRoutine?.kind == .viceLinked)
        #expect(copiedRoutine?.viceID == vice.id)
        #expect(repository.vices.first?.linkedRoutineID == copiedRoutine?.id)
    }
}

@MainActor
private final class InMemoryViceRepository: ViceRepository {
    var vices: [Vice]
    var logs: [ViceLog]
    var sessions: [ViceSession]
    var goals: [ViceGoal]

    init(vices: [Vice], logs: [ViceLog], sessions: [ViceSession] = [], goals: [ViceGoal] = []) {
        self.vices = vices
        self.logs = logs
        self.sessions = sessions
        self.goals = goals
    }

    func fetchVices(includeArchived: Bool) throws -> [Vice] {
        let values = includeArchived ? vices : vices.filter { $0.isArchived == false }
        return values.sortedForVices()
    }

    func vice(withID id: UUID) throws -> Vice? {
        vices.first { $0.id == id }
    }

    func saveVice(_ vice: Vice, replacingViceWithID originalID: UUID?) throws {
        let targetID = originalID ?? vice.id
        if let index = vices.firstIndex(where: { $0.id == targetID || $0.id == vice.id }) {
            vices[index] = vice
        } else {
            vices.append(vice)
        }
    }

    func archiveVice(withID id: UUID, archivedAt: Date) throws {
        guard let index = vices.firstIndex(where: { $0.id == id }) else {
            return
        }

        vices[index].isArchived = true
        vices[index].updatedAt = archivedAt
    }

    func fetchViceLogs() throws -> [ViceLog] {
        logs.sortedForViceLogs()
    }

    func fetchViceLogs(for viceID: UUID, from startDate: Date, to endDate: Date) throws -> [ViceLog] {
        logs.filter { log in
            log.viceID == viceID && log.timestamp >= startDate && log.timestamp <= endDate
        }
    }

    func saveViceLog(_ log: ViceLog) throws {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
    }

    func deleteViceLog(withID id: UUID) throws {
        logs.removeAll { $0.id == id }
    }

    func fetchViceSessions() throws -> [ViceSession] {
        sessions.sortedForViceSessions()
    }

    func saveViceSession(_ session: ViceSession) throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else if let index = sessions.firstIndex(where: { $0.viceID == session.viceID && $0.isActive(at: session.lastHitAt) }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func deleteViceSession(withID id: UUID) throws {
        sessions.removeAll { $0.id == id }
    }

    func fetchViceGoals(includeArchived: Bool) throws -> [ViceGoal] {
        let values = includeArchived ? goals : goals.filter { $0.isArchived == false }
        return values.sortedForViceGoals()
    }

    func saveViceGoal(_ goal: ViceGoal, replacingGoalWithID originalID: UUID?) throws {
        let targetID = originalID ?? goal.id
        if let index = goals.firstIndex(where: { $0.id == targetID || $0.id == goal.id }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
    }

    func archiveViceGoal(withID id: UUID, archivedAt: Date) throws {
        guard let index = goals.firstIndex(where: { $0.id == id }) else {
            return
        }

        goals[index].archivedAt = archivedAt
        goals[index].updatedAt = archivedAt
    }
}

@MainActor
private final class InMemoryRoutineRepository: RoutineRepository {
    var routines: [Routine]
    var completionLogs: [RoutineCompletionLog]
    var unlocks: [ViceRoutineUnlock]

    init(
        routines: [Routine] = [],
        completionLogs: [RoutineCompletionLog] = [],
        unlocks: [ViceRoutineUnlock] = []
    ) {
        self.routines = routines
        self.completionLogs = completionLogs
        self.unlocks = unlocks
    }

    func fetchRoutines() throws -> [Routine] {
        routines
    }

    func fetchActiveRoutines(on date: Date, calendar: Calendar) throws -> [Routine] {
        routines.filter { $0.isActive(on: date, calendar: calendar) }
    }

    func routine(withID id: UUID) throws -> Routine? {
        routines.first { $0.id == id }
    }

    func saveRoutine(_ routine: Routine, replacingRoutineWithID originalID: UUID?) throws {
        let targetID = originalID ?? routine.id
        if let index = routines.firstIndex(where: { $0.id == targetID || $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    func deleteRoutine(withID id: UUID) throws {
        routines.removeAll { $0.id == id }
    }

    func fetchCompletionLog(for routineID: UUID, on date: Date, calendar: Calendar) throws -> RoutineCompletionLog? {
        completionLogs.first { $0.routineID == routineID && calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchCompletionLogs(on date: Date, calendar: Calendar) throws -> [RoutineCompletionLog] {
        completionLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func saveCompletionLog(_ log: RoutineCompletionLog, replacingLogWithID originalID: UUID?) throws {
        let targetID = originalID ?? log.id
        if let index = completionLogs.firstIndex(where: { $0.id == targetID || $0.id == log.id }) {
            completionLogs[index] = log
        } else {
            completionLogs.append(log)
        }
    }

    func fetchViceRoutineUnlock(for viceID: UUID, routineID: UUID) throws -> ViceRoutineUnlock? {
        unlocks.first { $0.viceID == viceID && $0.routineID == routineID }
    }

    func saveViceRoutineUnlock(_ unlock: ViceRoutineUnlock, replacingUnlockWithID originalID: UUID?) throws {
        let targetID = originalID ?? unlock.id
        if let index = unlocks.firstIndex(where: { $0.id == targetID || ($0.viceID == unlock.viceID && $0.routineID == unlock.routineID) }) {
            unlocks[index] = unlock
        } else {
            unlocks.append(unlock)
        }
    }

    func deleteViceRoutineUnlock(withID id: UUID) throws {
        unlocks.removeAll { $0.id == id }
    }

    func deleteExpiredViceRoutineUnlocks(asOf now: Date) throws {
        unlocks.removeAll { $0.expiresAt < now }
    }
}

@MainActor
private final class InMemoryDebriefRepository: DebriefRepository {
    var debriefs: [CalendarDebriefRecord] = []

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
        if let index = debriefs.firstIndex(where: { $0.id == (originalID ?? debrief.id) || $0.eventKey == debrief.eventKey }) {
            debriefs[index] = debrief
        } else {
            debriefs.append(debrief)
        }
    }

    func deleteDebrief(withID id: UUID) throws {
        debriefs.removeAll { $0.id == id }
    }
}
