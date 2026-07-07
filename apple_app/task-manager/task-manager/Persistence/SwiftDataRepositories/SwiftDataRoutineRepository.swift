import Foundation
import SwiftData

@MainActor
final class SwiftDataRoutineRepository: RoutineRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchRoutines() throws -> [Routine] {
        try fetchAllRoutineRecords()
            .map(\.routine)
            .sorted { leftRoutine, rightRoutine in
                if leftRoutine.createdAt != rightRoutine.createdAt {
                    return leftRoutine.createdAt < rightRoutine.createdAt
                }

                return leftRoutine.id.uuidString < rightRoutine.id.uuidString
            }
    }

    func fetchActiveRoutines(on date: Date, calendar: Calendar) throws -> [Routine] {
        try fetchRoutines().filter { $0.isActive(on: date, calendar: calendar) }
    }

    func routine(withID id: UUID) throws -> Routine? {
        try fetchRoutineRecord(withID: id)?.routine
    }

    func saveRoutine(_ routine: Routine, replacingRoutineWithID originalID: UUID?) throws {
        let record =
            try fetchRoutineRecord(withID: originalID ?? routine.id)
            ?? fetchRoutineRecord(withID: routine.id)

        if let record {
            record.update(from: routine)
        } else {
            modelContext.insert(RoutineRecord(routine: routine))
        }

        try modelContext.save()
    }

    func deleteRoutine(withID id: UUID) throws {
        guard let record = try fetchRoutineRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchCompletionLog(
        for routineID: UUID,
        on date: Date,
        calendar: Calendar
    ) throws -> RoutineCompletionLog? {
        let dayStart = calendar.startOfDay(for: date)
        return try fetchAllLogRecords()
            .map(\.log)
            .first { log in
                log.routineID == routineID && calendar.isDate(log.date, inSameDayAs: dayStart)
            }
    }

    func fetchCompletionLogs(on date: Date, calendar: Calendar) throws -> [RoutineCompletionLog] {
        let dayStart = calendar.startOfDay(for: date)
        return try fetchAllLogRecords()
            .map(\.log)
            .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
            .sorted { leftLog, rightLog in
                if leftLog.updatedAt != rightLog.updatedAt {
                    return leftLog.updatedAt < rightLog.updatedAt
                }

                return leftLog.id.uuidString < rightLog.id.uuidString
            }
    }

    func saveCompletionLog(_ log: RoutineCompletionLog, replacingLogWithID originalID: UUID?) throws {
        let record =
            try fetchLogRecord(withID: originalID ?? log.id)
            ?? fetchLogRecord(withID: log.id)

        if let record {
            record.update(from: log)
        } else {
            modelContext.insert(RoutineCompletionLogRecord(log: log))
        }

        try modelContext.save()
    }

    func fetchViceRoutineUnlock(
        for viceID: UUID,
        routineID: UUID
    ) throws -> ViceRoutineUnlock? {
        try fetchAllUnlockRecords()
            .map(\.unlock)
            .sorted { $0.updatedAt > $1.updatedAt }
            .first { $0.viceID == viceID && $0.routineID == routineID }
    }

    func saveViceRoutineUnlock(_ unlock: ViceRoutineUnlock, replacingUnlockWithID originalID: UUID?) throws {
        let record =
            try fetchUnlockRecord(withID: originalID ?? unlock.id)
            ?? fetchUnlockRecord(withID: unlock.id)
            ?? fetchUnlockRecord(viceID: unlock.viceID, routineID: unlock.routineID)

        if let record {
            record.update(from: unlock)
        } else {
            modelContext.insert(ViceRoutineUnlockRecord(unlock: unlock))
        }

        try modelContext.save()
    }

    func deleteViceRoutineUnlock(withID id: UUID) throws {
        guard let record = try fetchUnlockRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func deleteExpiredViceRoutineUnlocks(asOf now: Date) throws {
        let expired = try fetchAllUnlockRecords()
            .filter { $0.expiresAt < now }
        guard expired.isEmpty == false else {
            return
        }

        for record in expired {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func fetchAllRoutineRecords() throws -> [RoutineRecord] {
        try modelContext.fetch(FetchDescriptor<RoutineRecord>())
    }

    private func fetchRoutineRecord(withID id: UUID) throws -> RoutineRecord? {
        try fetchAllRoutineRecords().first { $0.id == id }
    }

    private func fetchAllLogRecords() throws -> [RoutineCompletionLogRecord] {
        try modelContext.fetch(FetchDescriptor<RoutineCompletionLogRecord>())
    }

    private func fetchLogRecord(withID id: UUID) throws -> RoutineCompletionLogRecord? {
        try fetchAllLogRecords().first { $0.id == id }
    }

    private func fetchAllUnlockRecords() throws -> [ViceRoutineUnlockRecord] {
        try modelContext.fetch(FetchDescriptor<ViceRoutineUnlockRecord>())
    }

    private func fetchUnlockRecord(withID id: UUID) throws -> ViceRoutineUnlockRecord? {
        try fetchAllUnlockRecords().first { $0.id == id }
    }

    private func fetchUnlockRecord(viceID: UUID, routineID: UUID) throws -> ViceRoutineUnlockRecord? {
        try fetchAllUnlockRecords().first { $0.viceID == viceID && $0.routineID == routineID }
    }
}
