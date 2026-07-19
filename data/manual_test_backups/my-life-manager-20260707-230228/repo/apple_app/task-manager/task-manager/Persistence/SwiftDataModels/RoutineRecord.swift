import Foundation
import SwiftData

@Model
final class RoutineRecord {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String?
    var kindRawValue: String = RoutineKind.standard.rawValue
    var viceID: UUID?
    var activeWeekdayRawValues: String = ""
    var itemsData: Data = Data()
    var stepLinksData: Data = Data()
    var isArchived: Bool = false
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(routine: Routine) {
        update(from: routine)
    }

    var routine: Routine {
        Routine(
            id: id,
            name: name,
            notes: notes,
            kind: RoutineKind(rawValue: kindRawValue) ?? .standard,
            viceID: viceID,
            activeWeekdays: Self.decodeWeekdays(activeWeekdayRawValues),
            items: Self.decodeItems(itemsData),
            stepLinks: Self.decodeStepLinks(stepLinksData),
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from routine: Routine) {
        id = routine.id
        name = routine.name
        notes = routine.notes
        kindRawValue = routine.kind.rawValue
        viceID = routine.viceID
        activeWeekdayRawValues = Self.encodeWeekdays(routine.activeWeekdays)
        itemsData = Self.encodeItems(routine.items)
        stepLinksData = Self.encodeStepLinks(routine.stepLinks)
        isArchived = routine.isArchived
        createdAt = routine.createdAt
        updatedAt = routine.updatedAt
    }

    private static func encodeWeekdays(_ weekdays: [RoutineWeekday]) -> String {
        weekdays.map { String($0.rawValue) }.joined(separator: ",")
    }

    private static func decodeWeekdays(_ rawValue: String) -> [RoutineWeekday] {
        rawValue
            .split(separator: ",")
            .compactMap { Int($0).flatMap(RoutineWeekday.init(rawValue:)) }
    }

    private static func encodeItems(_ items: [RoutineItem]) -> Data {
        (try? JSONEncoder().encode(items)) ?? Data()
    }

    private static func decodeItems(_ data: Data) -> [RoutineItem] {
        (try? JSONDecoder().decode([RoutineItem].self, from: data)) ?? []
    }

    private static func encodeStepLinks(_ links: [RoutineStepLink]) -> Data {
        (try? JSONEncoder().encode(links)) ?? Data()
    }

    private static func decodeStepLinks(_ data: Data) -> [RoutineStepLink] {
        (try? JSONDecoder().decode([RoutineStepLink].self, from: data)) ?? []
    }
}
