import Foundation
import SwiftData

@MainActor
final class SwiftDataViceRepository: ViceRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        modelContext = modelContainer.mainContext
    }

    func fetchVices(includeArchived: Bool) throws -> [Vice] {
        let allVices = try modelContext.fetch(FetchDescriptor<ViceRecord>())
            .map(\.vice)
            .sortedForVices()

        if includeArchived {
            return allVices
        }

        return allVices.filter { $0.isArchived == false }
    }

    func vice(withID id: UUID) throws -> Vice? {
        try fetchViceRecord(withID: id)?.vice
    }

    func saveVice(_ vice: Vice, replacingViceWithID originalID: UUID?) throws {
        let record =
            try fetchViceRecord(withID: originalID ?? vice.id)
            ?? fetchViceRecord(withID: vice.id)

        if let record {
            record.update(from: vice)
        } else {
            modelContext.insert(ViceRecord(vice: vice))
        }

        try modelContext.save()
    }

    func archiveVice(withID id: UUID, archivedAt: Date) throws {
        guard let record = try fetchViceRecord(withID: id) else {
            return
        }

        var updatedVice = record.vice
        updatedVice.isArchived = true
        updatedVice.updatedAt = archivedAt
        record.update(from: updatedVice)
        try modelContext.save()
    }

    func fetchViceLogs() throws -> [ViceLog] {
        try modelContext.fetch(FetchDescriptor<ViceLogRecord>())
            .map(\.log)
            .sortedForViceLogs()
    }

    func fetchViceLogs(
        for viceID: UUID,
        from startDate: Date,
        to endDate: Date
    ) throws -> [ViceLog] {
        try fetchViceLogs()
            .filter { log in
                log.viceID == viceID && log.timestamp >= startDate && log.timestamp <= endDate
            }
    }

    func saveViceLog(_ log: ViceLog) throws {
        if let existingRecord = try fetchViceLogRecord(withID: log.id) {
            existingRecord.update(from: log)
        } else {
            modelContext.insert(ViceLogRecord(log: log))
        }

        try modelContext.save()
    }

    func deleteViceLog(withID id: UUID) throws {
        guard let record = try fetchViceLogRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchViceSessions() throws -> [ViceSession] {
        try modelContext.fetch(FetchDescriptor<ViceSessionRecord>())
            .map(\.session)
            .sortedForViceSessions()
    }

    func saveViceSession(_ session: ViceSession) throws {
        if let existingRecord = try fetchViceSessionRecord(withID: session.id) {
            existingRecord.update(from: session)
        } else {
            modelContext.insert(ViceSessionRecord(session: session))
        }

        try modelContext.save()
    }

    func deleteViceSession(withID id: UUID) throws {
        guard let record = try fetchViceSessionRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchViceGoals(includeArchived: Bool) throws -> [ViceGoal] {
        let allGoals = try modelContext.fetch(FetchDescriptor<ViceGoalRecord>())
            .map(\.goal)
            .sortedForViceGoals()

        if includeArchived {
            return allGoals
        }

        return allGoals.filter { $0.isArchived == false }
    }

    func saveViceGoal(_ goal: ViceGoal, replacingGoalWithID originalID: UUID?) throws {
        let record =
            try fetchViceGoalRecord(withID: originalID ?? goal.id)
            ?? fetchViceGoalRecord(withID: goal.id)

        if let record {
            record.update(from: goal)
        } else {
            modelContext.insert(ViceGoalRecord(goal: goal))
        }

        try modelContext.save()
    }

    func archiveViceGoal(withID id: UUID, archivedAt: Date) throws {
        guard let record = try fetchViceGoalRecord(withID: id) else {
            return
        }

        var updatedGoal = record.goal
        updatedGoal.archivedAt = archivedAt
        updatedGoal.updatedAt = archivedAt
        record.update(from: updatedGoal)
        try modelContext.save()
    }

    private func fetchViceRecord(withID id: UUID) throws -> ViceRecord? {
        try modelContext.fetch(FetchDescriptor<ViceRecord>())
            .first { $0.id == id }
    }

    private func fetchViceLogRecord(withID id: UUID) throws -> ViceLogRecord? {
        try modelContext.fetch(FetchDescriptor<ViceLogRecord>())
            .first { $0.id == id }
    }

    private func fetchViceSessionRecord(withID id: UUID) throws -> ViceSessionRecord? {
        try modelContext.fetch(FetchDescriptor<ViceSessionRecord>())
            .first { $0.id == id }
    }

    private func fetchViceGoalRecord(withID id: UUID) throws -> ViceGoalRecord? {
        try modelContext.fetch(FetchDescriptor<ViceGoalRecord>())
            .first { $0.id == id }
    }
}

extension Array where Element == Vice {
    func sortedForVices() -> [Vice] {
        sorted { leftVice, rightVice in
            if leftVice.isArchived != rightVice.isArchived {
                return leftVice.isArchived == false
            }

            let comparison = leftVice.name.localizedCaseInsensitiveCompare(rightVice.name)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return leftVice.id.uuidString < rightVice.id.uuidString
        }
    }
}

extension Array where Element == ViceLog {
    func sortedForViceLogs() -> [ViceLog] {
        sorted { leftLog, rightLog in
            if leftLog.timestamp != rightLog.timestamp {
                return leftLog.timestamp > rightLog.timestamp
            }

            return leftLog.id.uuidString < rightLog.id.uuidString
        }
    }
}

extension Array where Element == ViceGoal {
    func sortedForViceGoals() -> [ViceGoal] {
        sorted { lhs, rhs in
            if lhs.isArchived != rhs.isArchived {
                return lhs.isArchived == false
            }

            if lhs.deadline != rhs.deadline {
                return lhs.deadline < rhs.deadline
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
