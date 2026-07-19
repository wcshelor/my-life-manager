import Foundation
import SwiftData

@MainActor
final class SwiftDataHealthRepository: HealthRepository {
    private static let builtInFoodCatalogItems = [
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0001")!,
            name: "Eggs",
            servingDescription: "2 eggs",
            nutritionPerServing: NutritionFacts(calories: 140, proteinGrams: 12, carbGrams: 1, sugarGrams: 1, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0002")!,
            name: "Oatmeal",
            servingDescription: "1 bowl",
            nutritionPerServing: NutritionFacts(calories: 150, proteinGrams: 5, carbGrams: 27, sugarGrams: 1, fiberGrams: 4),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0003")!,
            name: "Greek yogurt",
            servingDescription: "1 cup",
            nutritionPerServing: NutritionFacts(calories: 130, proteinGrams: 17, carbGrams: 6, sugarGrams: 6, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0004")!,
            name: "Milk",
            servingDescription: "1 cup",
            nutritionPerServing: NutritionFacts(calories: 120, proteinGrams: 8, carbGrams: 12, sugarGrams: 12, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0005")!,
            name: "Banana",
            servingDescription: "1 banana",
            nutritionPerServing: NutritionFacts(calories: 105, proteinGrams: 1.3, carbGrams: 27, sugarGrams: 14, fiberGrams: 3.1),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0006")!,
            name: "Apple",
            servingDescription: "1 apple",
            nutritionPerServing: NutritionFacts(calories: 95, proteinGrams: 0.5, carbGrams: 25, sugarGrams: 19, fiberGrams: 4.4),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0007")!,
            name: "Blueberries",
            servingDescription: "1 cup",
            nutritionPerServing: NutritionFacts(calories: 85, proteinGrams: 1.1, carbGrams: 21, sugarGrams: 15, fiberGrams: 3.6),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0008")!,
            name: "Chicken breast",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 180, proteinGrams: 35, carbGrams: 0, sugarGrams: 0, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0009")!,
            name: "Ground beef",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 250, proteinGrams: 24, carbGrams: 0, sugarGrams: 0, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0010")!,
            name: "Salmon",
            servingDescription: "1 fillet",
            nutritionPerServing: NutritionFacts(calories: 240, proteinGrams: 25, carbGrams: 0, sugarGrams: 0, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0011")!,
            name: "Pork schnitzel",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 320, proteinGrams: 24, carbGrams: 18, sugarGrams: 1, fiberGrams: 1),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0012")!,
            name: "Ham sandwich",
            servingDescription: "1 sandwich",
            nutritionPerServing: NutritionFacts(calories: 310, proteinGrams: 18, carbGrams: 33, sugarGrams: 5, fiberGrams: 3),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0013")!,
            name: "Rice",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 200, proteinGrams: 4, carbGrams: 45, sugarGrams: 0, fiberGrams: 1),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0014")!,
            name: "Pasta",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 220, proteinGrams: 8, carbGrams: 43, sugarGrams: 2, fiberGrams: 2.5),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0015")!,
            name: "Bread",
            servingDescription: "2 slices",
            nutritionPerServing: NutritionFacts(calories: 160, proteinGrams: 6, carbGrams: 28, sugarGrams: 4, fiberGrams: 2),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0016")!,
            name: "Potatoes",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 160, proteinGrams: 4, carbGrams: 37, sugarGrams: 2, fiberGrams: 4),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0017")!,
            name: "Fried potatoes",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 280, proteinGrams: 4, carbGrams: 32, sugarGrams: 1, fiberGrams: 3),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0018")!,
            name: "Sweet potatoes",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 180, proteinGrams: 4, carbGrams: 41, sugarGrams: 13, fiberGrams: 6),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0019")!,
            name: "Carrots + peas",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 110, proteinGrams: 5, carbGrams: 18, sugarGrams: 8, fiberGrams: 6),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0020")!,
            name: "Broccoli",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 55, proteinGrams: 3.7, carbGrams: 11, sugarGrams: 2.2, fiberGrams: 5.1),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0021")!,
            name: "Mixed salad",
            servingDescription: "1 bowl",
            nutritionPerServing: NutritionFacts(calories: 45, proteinGrams: 2, carbGrams: 8, sugarGrams: 4, fiberGrams: 3),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0022")!,
            name: "Black beans",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 120, proteinGrams: 8, carbGrams: 21, sugarGrams: 0.5, fiberGrams: 8),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0023")!,
            name: "Lentils",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 180, proteinGrams: 12, carbGrams: 32, sugarGrams: 3, fiberGrams: 14),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0024")!,
            name: "Tofu",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 140, proteinGrams: 15, carbGrams: 4, sugarGrams: 1, fiberGrams: 2),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0025")!,
            name: "Cheddar cheese",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 115, proteinGrams: 7, carbGrams: 1, sugarGrams: 0, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0026")!,
            name: "Cottage cheese",
            servingDescription: "1 cup",
            nutritionPerServing: NutritionFacts(calories: 180, proteinGrams: 24, carbGrams: 8, sugarGrams: 6, fiberGrams: 0),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0027")!,
            name: "Peanut butter",
            servingDescription: "2 tbsp",
            nutritionPerServing: NutritionFacts(calories: 190, proteinGrams: 7, carbGrams: 7, sugarGrams: 3, fiberGrams: 2),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0028")!,
            name: "Pizza",
            servingDescription: "2 slices",
            nutritionPerServing: NutritionFacts(calories: 540, proteinGrams: 24, carbGrams: 60, sugarGrams: 8, fiberGrams: 4),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0029")!,
            name: "Burger",
            servingDescription: "1 burger",
            nutritionPerServing: NutritionFacts(calories: 520, proteinGrams: 27, carbGrams: 38, sugarGrams: 7, fiberGrams: 2),
            source: .builtIn
        ),
        FoodCatalogItem(
            id: UUID(uuidString: "C43F2A07-6BB0-4B25-B0E5-33B5212A0030")!,
            name: "Chicken curry",
            servingDescription: "1 serving",
            nutritionPerServing: NutritionFacts(calories: 340, proteinGrams: 24, carbGrams: 18, sugarGrams: 5, fiberGrams: 3),
            source: .builtIn
        )
    ]

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func searchFoodCatalogItems(matching query: String, limit: Int) throws -> [FoodCatalogItem] {
        let normalizedQuery = query.normalizedFoodSearchText
        let customItems = try fetchCustomFoodCatalogItems()
        let items = mergeFoodCatalogItems(customItems: customItems)
        let maxLimit = max(0, limit)
        guard maxLimit > 0 else {
            return []
        }

        let scoredItems = items.compactMap { item -> (FoodCatalogItem, Int)? in
            guard let score = foodCatalogSearchScore(for: item, normalizedQuery: normalizedQuery) else {
                return nil
            }

            return (item, score)
        }

        return scoredItems
            .sorted { left, right in
                if left.1 != right.1 {
                    return left.1 > right.1
                }

                if left.0.source != right.0.source {
                    return left.0.source == .custom
                }

                if left.0.updatedAt != right.0.updatedAt {
                    return left.0.updatedAt > right.0.updatedAt
                }

                return left.0.name.localizedCaseInsensitiveCompare(right.0.name) == .orderedAscending
            }
            .prefix(maxLimit)
            .map(\.0)
    }

    func fetchCustomFoodCatalogItems() throws -> [FoodCatalogItem] {
        try fetchAllFoodCatalogRecords()
            .map(\.item)
            .sorted { left, right in
                if left.updatedAt != right.updatedAt {
                    return left.updatedAt > right.updatedAt
                }

                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
    }

    func saveFoodCatalogItem(_ item: FoodCatalogItem) throws {
        let normalizedItem = FoodCatalogItem(
            id: item.id,
            name: item.name,
            servingDescription: item.servingDescription,
            nutritionPerServing: item.nutritionPerServing,
            source: .custom,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
        if let record = try fetchFoodCatalogRecord(withID: normalizedItem.id) {
            record.update(from: normalizedItem)
        } else {
            modelContext.insert(FoodCatalogItemRecord(item: normalizedItem))
        }

        try modelContext.save()
    }

    func deleteFoodCatalogItem(withID id: UUID) throws {
        guard let record = try fetchFoodCatalogRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchSleepCheckIns(limit: Int) throws -> [SleepCheckIn] {
        Array(
            try fetchAllSleepRecords()
                .map(\.checkIn)
                .sorted { leftCheckIn, rightCheckIn in
                    if leftCheckIn.day != rightCheckIn.day {
                        return leftCheckIn.day > rightCheckIn.day
                    }

                    return leftCheckIn.id.uuidString < rightCheckIn.id.uuidString
                }
                .prefix(max(0, limit))
        )
    }

    func fetchSleepCheckIn(on date: Date, calendar: Calendar) throws -> SleepCheckIn? {
        let dayStart = calendar.startOfDay(for: date)
        return try fetchAllSleepRecords()
            .map(\.checkIn)
            .first { checkIn in
                calendar.isDate(checkIn.day, inSameDayAs: dayStart)
            }
    }

    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID?) throws {
        let record =
            try originalID.flatMap(fetchSleepRecord(withID:))
            ?? fetchSleepRecord(withID: checkIn.id)
            ?? fetchSleepRecord(on: checkIn.day, calendar: .current)

        if let record {
            record.update(from: checkIn)
        } else {
            modelContext.insert(SleepCheckInRecord(checkIn: checkIn))
        }

        try modelContext.save()
    }

    func fetchMealLogs(on date: Date, calendar: Calendar) throws -> [MealLog] {
        try fetchAllMealRecords()
            .map(\.log)
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentMealLogs(limit: Int) throws -> [MealLog] {
        Array(
            try fetchAllMealRecords()
                .map(\.log)
                .sortedForHealthHistory()
                .prefix(max(0, limit))
        )
    }

    func mealLog(withID id: UUID) throws -> MealLog? {
        try fetchMealRecord(withID: id)?.log
    }

    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID?) throws {
        let record =
            try originalID.flatMap(fetchMealRecord(withID:))
            ?? fetchMealRecord(withID: log.id)

        if let record {
            record.update(from: log)
        } else {
            modelContext.insert(MealLogRecord(log: log))
        }

        try modelContext.save()
    }

    func deleteMealLog(withID id: UUID) throws {
        guard let record = try fetchMealRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchWorkoutLogs(on date: Date, calendar: Calendar) throws -> [WorkoutLog] {
        try fetchAllWorkoutRecords()
            .map(\.log)
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentWorkoutLogs(limit: Int) throws -> [WorkoutLog] {
        Array(
            try fetchAllWorkoutRecords()
                .map(\.log)
                .sortedForHealthHistory()
                .prefix(max(0, limit))
        )
    }

    func workoutLog(withID id: UUID) throws -> WorkoutLog? {
        try fetchWorkoutRecord(withID: id)?.log
    }

    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID?) throws {
        let record =
            try originalID.flatMap(fetchWorkoutRecord(withID:))
            ?? fetchWorkoutRecord(withID: log.id)

        if let record {
            record.update(from: log)
        } else {
            modelContext.insert(WorkoutLogRecord(log: log))
        }

        try modelContext.save()
    }

    func deleteWorkoutLog(withID id: UUID) throws {
        guard let record = try fetchWorkoutRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchPVTSessions(on date: Date, calendar: Calendar) throws -> [PVTSession] {
        try fetchAllPVTRecords()
            .map(\.session)
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentPVTSessions(limit: Int) throws -> [PVTSession] {
        Array(
            try fetchAllPVTRecords()
                .map(\.session)
                .sortedForHealthHistory()
                .prefix(max(0, limit))
        )
    }

    func savePVTSession(_ session: PVTSession) throws {
        if let record = try fetchPVTRecord(withID: session.id) {
            record.update(from: session)
        } else {
            modelContext.insert(PVTSessionRecord(session: session))
        }

        try modelContext.save()
    }

    private func fetchAllSleepRecords() throws -> [SleepCheckInRecord] {
        try modelContext.fetch(FetchDescriptor<SleepCheckInRecord>())
    }

    private func fetchSleepRecord(withID id: UUID) throws -> SleepCheckInRecord? {
        try fetchAllSleepRecords().first { $0.id == id }
    }

    private func fetchSleepRecord(on date: Date, calendar: Calendar) throws -> SleepCheckInRecord? {
        try fetchAllSleepRecords().first { record in
            calendar.isDate(record.day, inSameDayAs: date)
        }
    }

    private func fetchAllMealRecords() throws -> [MealLogRecord] {
        try modelContext.fetch(FetchDescriptor<MealLogRecord>())
    }

    private func fetchMealRecord(withID id: UUID) throws -> MealLogRecord? {
        try fetchAllMealRecords().first { $0.id == id }
    }

    private func fetchAllWorkoutRecords() throws -> [WorkoutLogRecord] {
        try modelContext.fetch(FetchDescriptor<WorkoutLogRecord>())
    }

    private func fetchWorkoutRecord(withID id: UUID) throws -> WorkoutLogRecord? {
        try fetchAllWorkoutRecords().first { $0.id == id }
    }

    private func fetchAllPVTRecords() throws -> [PVTSessionRecord] {
        try modelContext.fetch(FetchDescriptor<PVTSessionRecord>())
    }

    private func fetchPVTRecord(withID id: UUID) throws -> PVTSessionRecord? {
        try fetchAllPVTRecords().first { $0.id == id }
    }

    private func fetchAllFoodCatalogRecords() throws -> [FoodCatalogItemRecord] {
        try modelContext.fetch(FetchDescriptor<FoodCatalogItemRecord>())
    }

    private func fetchFoodCatalogRecord(withID id: UUID) throws -> FoodCatalogItemRecord? {
        try fetchAllFoodCatalogRecords().first { $0.id == id }
    }

    private func mergeFoodCatalogItems(customItems: [FoodCatalogItem]) -> [FoodCatalogItem] {
        let customNames = Set(customItems.map { $0.name.normalizedFoodSearchText })
        let builtInItems = Self.builtInFoodCatalogItems.filter { customNames.contains($0.name.normalizedFoodSearchText) == false }
        return customItems + builtInItems
    }

    private func foodCatalogSearchScore(for item: FoodCatalogItem, normalizedQuery: String) -> Int? {
        if normalizedQuery.isEmpty {
            return item.source == .custom ? 100 : 80
        }

        let normalizedName = item.name.normalizedFoodSearchText
        let normalizedServing = item.servingDescription.normalizedFoodSearchText
        let combinedText = item.normalizedSearchText

        if normalizedName == normalizedQuery {
            return item.source == .custom ? 1_200 : 1_100
        }

        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        guard queryTokens.isEmpty == false else {
            return item.source == .custom ? 100 : 80
        }

        var score = 0
        if normalizedName.hasPrefix(normalizedQuery) {
            score += 900
        } else if combinedText.contains(normalizedQuery) {
            score += 500
        }

        let nameTokens = Set(normalizedName.split(separator: " ").map(String.init))
        let servingTokens = Set(normalizedServing.split(separator: " ").map(String.init))

        for token in queryTokens {
            if nameTokens.contains(token) {
                score += 180
            } else if nameTokens.contains(where: { $0.hasPrefix(token) }) {
                score += 120
            } else if servingTokens.contains(token) {
                score += 60
            } else if combinedText.contains(token) {
                score += 40
            } else {
                return nil
            }
        }

        if item.source == .custom {
            score += 25
        }

        return score > 0 ? score : nil
    }
}
