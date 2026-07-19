import Foundation
import SwiftData

@Model
final class ViceRoutineUnlockRecord {
    var id: UUID = UUID()
    var viceID: UUID = UUID()
    var routineID: UUID = UUID()
    var completedAt: Date = Date.distantPast
    var expiresAt: Date = Date.distantPast
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(unlock: ViceRoutineUnlock) {
        update(from: unlock)
    }

    var unlock: ViceRoutineUnlock {
        ViceRoutineUnlock(
            id: id,
            viceID: viceID,
            routineID: routineID,
            completedAt: completedAt,
            expiresAt: expiresAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from unlock: ViceRoutineUnlock) {
        id = unlock.id
        viceID = unlock.viceID
        routineID = unlock.routineID
        completedAt = unlock.completedAt
        expiresAt = unlock.expiresAt
        createdAt = unlock.createdAt
        updatedAt = unlock.updatedAt
    }
}
