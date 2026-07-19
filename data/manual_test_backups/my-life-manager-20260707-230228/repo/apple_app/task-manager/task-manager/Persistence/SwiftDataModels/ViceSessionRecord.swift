import Foundation
import SwiftData

@Model
final class ViceSessionRecord {
    var id: UUID = UUID()
    var viceID: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var lastHitAt: Date = Date.distantPast
    var hitCount: Int = 1
    var closedAt: Date?

    init(session: ViceSession) {
        update(from: session)
    }

    var session: ViceSession {
        ViceSession(
            id: id,
            viceID: viceID,
            startedAt: startedAt,
            lastHitAt: lastHitAt,
            hitCount: hitCount,
            closedAt: closedAt
        )
    }

    func update(from session: ViceSession) {
        id = session.id
        viceID = session.viceID
        startedAt = session.startedAt
        lastHitAt = session.lastHitAt
        hitCount = session.hitCount
        closedAt = session.closedAt
    }
}
