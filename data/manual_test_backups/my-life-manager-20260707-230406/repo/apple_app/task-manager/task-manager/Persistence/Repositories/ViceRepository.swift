import Foundation

@MainActor
protocol ViceRepository {
    func fetchVices(includeArchived: Bool) throws -> [Vice]
    func vice(withID id: UUID) throws -> Vice?
    func saveVice(_ vice: Vice, replacingViceWithID originalID: UUID?) throws
    func archiveVice(withID id: UUID, archivedAt: Date) throws

    func fetchViceLogs() throws -> [ViceLog]
    func fetchViceLogs(
        for viceID: UUID,
        from startDate: Date,
        to endDate: Date
    ) throws -> [ViceLog]
    func saveViceLog(_ log: ViceLog) throws
    func deleteViceLog(withID id: UUID) throws

    func fetchViceSessions() throws -> [ViceSession]
    func saveViceSession(_ session: ViceSession) throws
    func deleteViceSession(withID id: UUID) throws

    func fetchViceGoals(includeArchived: Bool) throws -> [ViceGoal]
    func saveViceGoal(_ goal: ViceGoal, replacingGoalWithID originalID: UUID?) throws
    func archiveViceGoal(withID id: UUID, archivedAt: Date) throws
}
