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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
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
        let viewModel = VicesViewModel(
            viceRepository: repository,
            debriefRepository: debriefRepository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)

        #expect(viewModel.logs.count == 1)
        #expect(repository.sessions.count == 1)
        #expect(repository.sessions.first?.hitCount == 1)
    }
}

@MainActor
private final class InMemoryViceRepository: ViceRepository {
    var vices: [Vice]
    var logs: [ViceLog]
    var sessions: [ViceSession]

    init(vices: [Vice], logs: [ViceLog], sessions: [ViceSession] = []) {
        self.vices = vices
        self.logs = logs
        self.sessions = sessions
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
