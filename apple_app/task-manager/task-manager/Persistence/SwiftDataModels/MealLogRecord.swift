import Foundation
import SwiftData

@Model
final class MealLogRecord {
    var id: UUID = UUID()
    var timestamp: Date = Date.distantPast
    var summary: String = ""
    var entriesData: String = ""
    var notes: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(log: MealLog) {
        update(from: log)
    }

    var log: MealLog {
        MealLog(
            id: id,
            timestamp: timestamp,
            summary: summary,
            entries: Self.decodeEntries(entriesData),
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from log: MealLog) {
        id = log.id
        timestamp = log.timestamp
        summary = log.summary
        entriesData = Self.encodeEntries(log.entries)
        notes = log.notes
        createdAt = log.createdAt
        updatedAt = log.updatedAt
    }

    private static func encodeEntries(_ entries: [MealEntry]) -> String {
        guard entries.isEmpty == false else {
            return ""
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(entries),
              let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return text
    }

    private static func decodeEntries(_ text: String) -> [MealEntry] {
        guard text.isEmpty == false,
              let data = text.data(using: .utf8),
              let entries = try? JSONDecoder().decode([MealEntry].self, from: data)
        else {
            return []
        }

        return entries
    }
}

@Model
final class FoodCatalogItemRecord {
    var id: UUID = UUID()
    var name: String = ""
    var servingDescription: String = "1 serving"
    var caloriesPerServing: Double?
    var proteinGramsPerServing: Double?
    var carbGramsPerServing: Double?
    var sugarGramsPerServing: Double?
    var fiberGramsPerServing: Double?
    var sodiumMilligramsPerServing: Double?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(item: FoodCatalogItem) {
        update(from: item)
    }

    var item: FoodCatalogItem {
        FoodCatalogItem(
            id: id,
            name: name,
            servingDescription: servingDescription,
            nutritionPerServing: NutritionFacts(
                calories: caloriesPerServing,
                proteinGrams: proteinGramsPerServing,
                carbGrams: carbGramsPerServing,
                sugarGrams: sugarGramsPerServing,
                fiberGrams: fiberGramsPerServing,
                sodiumMilligrams: sodiumMilligramsPerServing
            ),
            source: .custom,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from item: FoodCatalogItem) {
        id = item.id
        name = item.name
        servingDescription = item.servingDescription
        caloriesPerServing = item.nutritionPerServing.calories
        proteinGramsPerServing = item.nutritionPerServing.proteinGrams
        carbGramsPerServing = item.nutritionPerServing.carbGrams
        sugarGramsPerServing = item.nutritionPerServing.sugarGrams
        fiberGramsPerServing = item.nutritionPerServing.fiberGrams
        sodiumMilligramsPerServing = item.nutritionPerServing.sodiumMilligrams
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }
}
