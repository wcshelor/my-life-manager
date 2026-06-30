import Foundation
import SwiftData

@Model
final class ViceGoalRecord {
    var id: UUID = UUID()
    var viceID: UUID = UUID()
    var maxOccurrences: Int = 1
    var startDate: Date = Date.distantPast
    var deadline: Date = Date.distantPast
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var archivedAt: Date?

    init(goal: ViceGoal) {
        update(from: goal)
    }

    var goal: ViceGoal {
        ViceGoal(
            id: id,
            viceID: viceID,
            maxOccurrences: maxOccurrences,
            startDate: startDate,
            deadline: deadline,
            createdAt: createdAt,
            updatedAt: updatedAt,
            archivedAt: archivedAt
        )
    }

    func update(from goal: ViceGoal) {
        id = goal.id
        viceID = goal.viceID
        maxOccurrences = goal.maxOccurrences
        startDate = goal.startDate
        deadline = goal.deadline
        createdAt = goal.createdAt
        updatedAt = goal.updatedAt
        archivedAt = goal.archivedAt
    }
}
