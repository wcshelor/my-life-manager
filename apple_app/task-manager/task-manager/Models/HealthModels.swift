import Foundation

nonisolated enum HealthContextTag: String, CaseIterable, Codable, Sendable {
    case caffeine
    case alcohol
    case cannabis
    case lateMeal
    case heavyMeal
    case workout
    case stress
    case screenTime

    var displayName: String {
        switch self {
        case .caffeine:
            return "Caffeine"
        case .alcohol:
            return "Alcohol"
        case .cannabis:
            return "Cannabis"
        case .lateMeal:
            return "Late Meal"
        case .heavyMeal:
            return "Heavy Meal"
        case .workout:
            return "Workout"
        case .stress:
            return "Stress"
        case .screenTime:
            return "Screen Time"
        }
    }
}

nonisolated enum FoodCatalogSource: String, Codable, Sendable {
    case builtIn
    case custom
}

nonisolated struct NutritionFacts: Equatable, Codable, Sendable {
    var calories: Double?
    var proteinGrams: Double?
    var carbGrams: Double?
    var sugarGrams: Double?
    var fiberGrams: Double?
    var sodiumMilligrams: Double?

    init(
        calories: Double? = nil,
        proteinGrams: Double? = nil,
        carbGrams: Double? = nil,
        sugarGrams: Double? = nil,
        fiberGrams: Double? = nil,
        sodiumMilligrams: Double? = nil
    ) {
        self.calories = Self.cleanedAmount(calories)
        self.proteinGrams = Self.cleanedAmount(proteinGrams)
        self.carbGrams = Self.cleanedAmount(carbGrams)
        self.sugarGrams = Self.cleanedAmount(sugarGrams)
        self.fiberGrams = Self.cleanedAmount(fiberGrams)
        self.sodiumMilligrams = Self.cleanedAmount(sodiumMilligrams)
    }

    var hasAnyValue: Bool {
        calories != nil
            || proteinGrams != nil
            || carbGrams != nil
            || sugarGrams != nil
            || fiberGrams != nil
            || sodiumMilligrams != nil
    }

    func scaled(by multiplier: Double) -> NutritionFacts {
        let cleanedMultiplier = max(0, multiplier)
        return NutritionFacts(
            calories: calories.map { $0 * cleanedMultiplier },
            proteinGrams: proteinGrams.map { $0 * cleanedMultiplier },
            carbGrams: carbGrams.map { $0 * cleanedMultiplier },
            sugarGrams: sugarGrams.map { $0 * cleanedMultiplier },
            fiberGrams: fiberGrams.map { $0 * cleanedMultiplier },
            sodiumMilligrams: sodiumMilligrams.map { $0 * cleanedMultiplier }
        )
    }

    func adding(_ other: NutritionFacts) -> NutritionFacts {
        NutritionFacts(
            calories: Self.sum(calories, other.calories),
            proteinGrams: Self.sum(proteinGrams, other.proteinGrams),
            carbGrams: Self.sum(carbGrams, other.carbGrams),
            sugarGrams: Self.sum(sugarGrams, other.sugarGrams),
            fiberGrams: Self.sum(fiberGrams, other.fiberGrams),
            sodiumMilligrams: Self.sum(sodiumMilligrams, other.sodiumMilligrams)
        )
    }

    static var empty: NutritionFacts {
        NutritionFacts()
    }

    private static func cleanedAmount(_ amount: Double?) -> Double? {
        guard let amount else {
            return nil
        }

        return max(0, amount)
    }

    private static func sum(_ left: Double?, _ right: Double?) -> Double? {
        switch (left, right) {
        case let (left?, right?):
            return left + right
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }
}

nonisolated struct FoodCatalogItem: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var servingDescription: String
    var nutritionPerServing: NutritionFacts
    var source: FoodCatalogSource
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        servingDescription: String = "1 serving",
        nutritionPerServing: NutritionFacts = .empty,
        source: FoodCatalogSource = .custom,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.servingDescription = Self.cleanedServingDescription(from: servingDescription) ?? "1 serving"
        self.nutritionPerServing = nutritionPerServing
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    static func cleanedName(from rawName: String) -> String? {
        let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedName.isEmpty ? nil : cleanedName
    }

    static func cleanedServingDescription(from rawDescription: String) -> String? {
        let cleanedDescription = rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedDescription.isEmpty ? nil : cleanedDescription
    }

    var normalizedSearchText: String {
        [name, servingDescription]
            .joined(separator: " ")
            .normalizedFoodSearchText
    }
}

nonisolated struct MealEntry: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var foodCatalogItemID: UUID?
    var foodName: String
    var servingDescription: String
    var servings: Double
    var nutritionPerServing: NutritionFacts
    var source: FoodCatalogSource?
    var note: String?

    init(
        id: UUID = UUID(),
        foodCatalogItemID: UUID? = nil,
        foodName: String,
        servingDescription: String = "1 serving",
        servings: Double = 1,
        nutritionPerServing: NutritionFacts = .empty,
        source: FoodCatalogSource? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.foodCatalogItemID = foodCatalogItemID
        self.foodName = FoodCatalogItem.cleanedName(from: foodName) ?? foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.servingDescription = FoodCatalogItem.cleanedServingDescription(from: servingDescription) ?? "1 serving"
        self.servings = Self.cleanedServings(servings)
        self.nutritionPerServing = nutritionPerServing
        self.source = source
        self.note = MyTask.cleanedOptionalText(from: note)
    }

    init(food: FoodCatalogItem, servings: Double = 1, note: String? = nil) {
        self.init(
            foodCatalogItemID: food.id,
            foodName: food.name,
            servingDescription: food.servingDescription,
            servings: servings,
            nutritionPerServing: food.nutritionPerServing,
            source: food.source,
            note: note
        )
    }

    var totalNutrition: NutritionFacts {
        nutritionPerServing.scaled(by: servings)
    }

    static func cleanedServings(_ servings: Double) -> Double {
        guard servings.isFinite, servings > 0 else {
            return 1
        }

        return servings
    }
}

nonisolated enum WorkoutType: String, CaseIterable, Codable, Sendable {
    case strength
    case cardio
    case mobility
    case walk
    case sport
    case other

    var displayName: String {
        rawValue.capitalized
    }
}

nonisolated struct SleepCheckIn: Identifiable, Equatable, Sendable {
    let id: UUID
    var day: Date
    var sleepDurationMinutes: Int?
    var sleepQualityRating: Int?
    var tirednessRating: Int?
    var energyRating: Int?
    var contextTags: [HealthContextTag]
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        day: Date,
        sleepDurationMinutes: Int? = nil,
        sleepQualityRating: Int? = nil,
        tirednessRating: Int? = nil,
        energyRating: Int? = nil,
        contextTags: [HealthContextTag] = [],
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.day = calendar.startOfDay(for: day)
        self.sleepDurationMinutes = Self.cleanedDuration(sleepDurationMinutes)
        self.sleepQualityRating = Self.cleanedRating(sleepQualityRating)
        self.tirednessRating = Self.cleanedRating(tirednessRating)
        self.energyRating = Self.cleanedRating(energyRating)
        self.contextTags = Self.cleanedTags(contextTags)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func isForSameDay(as date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, inSameDayAs: date)
    }

    static func cleanedRating(_ rating: Int?) -> Int? {
        rating.map { min(5, max(1, $0)) }
    }

    static func cleanedDuration(_ duration: Int?) -> Int? {
        duration.map { max(0, $0) }
    }

    static func cleanedTags(_ tags: [HealthContextTag]) -> [HealthContextTag] {
        let tagSet = Set(tags)
        return HealthContextTag.allCases.filter { tagSet.contains($0) }
    }
}

nonisolated struct MealLog: Identifiable, Equatable, Sendable {
    let id: UUID
    var timestamp: Date
    var summary: String
    var entries: [MealEntry]
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        summary: String = "",
        entries: [MealEntry] = [],
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.entries = entries
        self.summary = Self.cleanedSummary(from: summary)
            ?? Self.derivedSummary(from: entries)
            ?? summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(newSummary: String, timestamp: Date = .now, notes: String? = nil) {
        guard let cleanedSummary = Self.cleanedSummary(from: newSummary) else {
            return nil
        }

        self.init(
            timestamp: timestamp,
            summary: cleanedSummary,
            entries: [],
            notes: notes,
            createdAt: timestamp
        )
    }

    static func cleanedSummary(from rawSummary: String) -> String? {
        let cleanedSummary = rawSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedSummary.isEmpty ? nil : cleanedSummary
    }

    static func derivedSummary(from entries: [MealEntry]) -> String? {
        let names = entries
            .map(\.foodName)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard names.isEmpty == false else {
            return nil
        }

        return names.joined(separator: ", ")
    }

    var totalNutrition: NutritionFacts? {
        guard entries.isEmpty == false else {
            return nil
        }

        let total = entries
            .map(\.totalNutrition)
            .reduce(NutritionFacts.empty) { $0.adding($1) }
        return total.hasAnyValue ? total : nil
    }

    var totalCalories: Double? {
        totalNutrition?.calories
    }

    var totalProteinGrams: Double? {
        totalNutrition?.proteinGrams
    }

    var totalCarbGrams: Double? {
        totalNutrition?.carbGrams
    }

    var totalSugarGrams: Double? {
        totalNutrition?.sugarGrams
    }

    var totalFiberGrams: Double? {
        totalNutrition?.fiberGrams
    }

    var debriefReminderAt: Date {
        timestamp.addingTimeInterval(3 * 60 * 60)
    }
}

nonisolated struct WorkoutLog: Identifiable, Equatable, Sendable {
    let id: UUID
    var timestamp: Date
    var workoutType: WorkoutType
    var durationMinutes: Int?
    var intensityRating: Int?
    var energyBeforeRating: Int?
    var energyAfterRating: Int?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        workoutType: WorkoutType = .other,
        durationMinutes: Int? = nil,
        intensityRating: Int? = nil,
        energyBeforeRating: Int? = nil,
        energyAfterRating: Int? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.workoutType = workoutType
        self.durationMinutes = SleepCheckIn.cleanedDuration(durationMinutes)
        self.intensityRating = SleepCheckIn.cleanedRating(intensityRating)
        self.energyBeforeRating = SleepCheckIn.cleanedRating(energyBeforeRating)
        self.energyAfterRating = SleepCheckIn.cleanedRating(energyAfterRating)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

nonisolated struct PVTSession: Identifiable, Equatable, Sendable {
    static let lapseThresholdMilliseconds = 500

    let id: UUID
    var startedAt: Date
    var durationSeconds: Int
    var reactionTimesMilliseconds: [Int]
    var falseStartCount: Int
    var missCount: Int
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        durationSeconds: Int = 60,
        reactionTimesMilliseconds: [Int] = [],
        falseStartCount: Int = 0,
        missCount: Int = 0,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.reactionTimesMilliseconds = Self.cleanedReactionTimes(reactionTimesMilliseconds)
        self.falseStartCount = max(0, falseStartCount)
        self.missCount = max(0, missCount)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var responseCount: Int {
        reactionTimesMilliseconds.count
    }

    var averageReactionMilliseconds: Double? {
        reactionTimesMilliseconds.average
    }

    var medianReactionMilliseconds: Double? {
        reactionTimesMilliseconds.median
    }

    var lapseCount: Int {
        reactionTimesMilliseconds.filter { $0 >= Self.lapseThresholdMilliseconds }.count
    }

    func isForSameDay(as date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(startedAt, inSameDayAs: date)
    }

    static func cleanedReactionTimes(_ reactionTimes: [Int]) -> [Int] {
        reactionTimes.filter { $0 >= 0 }
    }
}

nonisolated struct HealthTrendSummary: Equatable, Sendable {
    let sleepPVT: SleepPVTTrendSummary
    let nutrition: NutritionTrendSummary
    let workouts: WorkoutTrendSummary

    init(
        sleepCheckIns: [SleepCheckIn],
        pvtSessions: [PVTSession],
        mealLogs: [MealLog],
        workoutLogs: [WorkoutLog],
        now: Date,
        calendar: Calendar
    ) {
        sleepPVT = SleepPVTTrendSummary(
            sleepCheckIns: sleepCheckIns,
            pvtSessions: pvtSessions,
            now: now,
            calendar: calendar
        )
        nutrition = NutritionTrendSummary(
            mealLogs: mealLogs,
            now: now,
            calendar: calendar
        )
        workouts = WorkoutTrendSummary(
            workoutLogs: workoutLogs,
            now: now,
            calendar: calendar
        )
    }
}

nonisolated struct SleepPVTTrendSummary: Equatable, Sendable {
    let current7Days: SleepPVTTrendWindow
    let previous7Days: SleepPVTTrendWindow
    let current30Days: SleepPVTTrendWindow

    init(
        sleepCheckIns: [SleepCheckIn],
        pvtSessions: [PVTSession],
        now: Date,
        calendar: Calendar
    ) {
        let latestPVTSessions = pvtSessions.latestSessionPerDay(calendar: calendar)
        current7Days = SleepPVTTrendWindow(
            sleepCheckIns: sleepCheckIns.filter { $0.day.isInCurrentWindow(days: 7, endingAt: now, calendar: calendar) },
            pvtSessions: latestPVTSessions.filter { $0.startedAt.isInCurrentWindow(days: 7, endingAt: now, calendar: calendar) }
        )
        previous7Days = SleepPVTTrendWindow(
            sleepCheckIns: sleepCheckIns.filter { $0.day.isInPreviousWindow(days: 7, endingAt: now, calendar: calendar) },
            pvtSessions: latestPVTSessions.filter { $0.startedAt.isInPreviousWindow(days: 7, endingAt: now, calendar: calendar) }
        )
        current30Days = SleepPVTTrendWindow(
            sleepCheckIns: sleepCheckIns.filter { $0.day.isInCurrentWindow(days: 30, endingAt: now, calendar: calendar) },
            pvtSessions: latestPVTSessions.filter { $0.startedAt.isInCurrentWindow(days: 30, endingAt: now, calendar: calendar) }
        )
    }
}

nonisolated struct SleepPVTTrendWindow: Equatable, Sendable {
    let daysLogged: Int
    let averageSleepDurationMinutes: Double?
    let averageSleepQualityRating: Double?
    let averageEnergyRating: Double?
    let pvtDaysLogged: Int
    let averagePVTMedianMilliseconds: Double?
    let averagePVTLapseCount: Double?

    init(sleepCheckIns: [SleepCheckIn], pvtSessions: [PVTSession]) {
        daysLogged = sleepCheckIns.count
        averageSleepDurationMinutes = sleepCheckIns.compactMap(\.sleepDurationMinutes).average
        averageSleepQualityRating = sleepCheckIns.compactMap(\.sleepQualityRating).average
        averageEnergyRating = sleepCheckIns.compactMap(\.energyRating).average
        pvtDaysLogged = pvtSessions.count
        averagePVTMedianMilliseconds = pvtSessions.compactMap(\.medianReactionMilliseconds).average
        averagePVTLapseCount = pvtSessions.map(\.lapseCount).average
    }
}

nonisolated struct NutritionTrendSummary: Equatable, Sendable {
    let current7Days: NutritionTrendWindow
    let previous7Days: NutritionTrendWindow
    let current30Days: NutritionTrendWindow

    init(mealLogs: [MealLog], now: Date, calendar: Calendar) {
        current7Days = NutritionTrendWindow(
            mealLogs: mealLogs.filter { $0.timestamp.isInCurrentWindow(days: 7, endingAt: now, calendar: calendar) }
        )
        previous7Days = NutritionTrendWindow(
            mealLogs: mealLogs.filter { $0.timestamp.isInPreviousWindow(days: 7, endingAt: now, calendar: calendar) }
        )
        current30Days = NutritionTrendWindow(
            mealLogs: mealLogs.filter { $0.timestamp.isInCurrentWindow(days: 30, endingAt: now, calendar: calendar) }
        )
    }
}

nonisolated struct NutritionTrendWindow: Equatable, Sendable {
    let mealCount: Int
    let mealEntryCount: Int
    let totalCalories: Double?
    let totalProteinGrams: Double?
    let totalCarbGrams: Double?
    let totalSugarGrams: Double?
    let totalFiberGrams: Double?

    init(mealLogs: [MealLog]) {
        mealCount = mealLogs.count
        mealEntryCount = mealLogs.reduce(0) { $0 + $1.entries.count }
        totalCalories = mealLogs.compactMap(\.totalCalories).sum
        totalProteinGrams = mealLogs.compactMap(\.totalProteinGrams).sum
        totalCarbGrams = mealLogs.compactMap(\.totalCarbGrams).sum
        totalSugarGrams = mealLogs.compactMap(\.totalSugarGrams).sum
        totalFiberGrams = mealLogs.compactMap(\.totalFiberGrams).sum
    }
}

nonisolated struct WorkoutTrendSummary: Equatable, Sendable {
    let current7Days: WorkoutTrendWindow
    let previous7Days: WorkoutTrendWindow
    let current30Days: WorkoutTrendWindow

    init(workoutLogs: [WorkoutLog], now: Date, calendar: Calendar) {
        current7Days = WorkoutTrendWindow(
            workoutLogs: workoutLogs.filter { $0.timestamp.isInCurrentWindow(days: 7, endingAt: now, calendar: calendar) }
        )
        previous7Days = WorkoutTrendWindow(
            workoutLogs: workoutLogs.filter { $0.timestamp.isInPreviousWindow(days: 7, endingAt: now, calendar: calendar) }
        )
        current30Days = WorkoutTrendWindow(
            workoutLogs: workoutLogs.filter { $0.timestamp.isInCurrentWindow(days: 30, endingAt: now, calendar: calendar) }
        )
    }
}

nonisolated struct WorkoutTrendWindow: Equatable, Sendable {
    let workoutCount: Int
    let totalDurationMinutes: Int
    let workoutTypeCounts: [WorkoutType: Int]
    let averageIntensityRating: Double?
    let averageEnergyDelta: Double?

    init(workoutLogs: [WorkoutLog]) {
        workoutCount = workoutLogs.count
        totalDurationMinutes = workoutLogs.compactMap(\.durationMinutes).reduce(0, +)
        workoutTypeCounts = Dictionary(grouping: workoutLogs, by: \.workoutType)
            .mapValues(\.count)
        averageIntensityRating = workoutLogs.compactMap(\.intensityRating).average
        averageEnergyDelta = workoutLogs.compactMap { log in
            guard let before = log.energyBeforeRating, let after = log.energyAfterRating else {
                return nil
            }

            return after - before
        }
        .average
    }
}

extension Array where Element == MealLog {
    nonisolated func sortedForHealthHistory() -> [MealLog] {
        sorted { leftLog, rightLog in
            if leftLog.timestamp != rightLog.timestamp {
                return leftLog.timestamp > rightLog.timestamp
            }

            return leftLog.id.uuidString < rightLog.id.uuidString
        }
    }
}

extension Array where Element == PVTSession {
    nonisolated func sortedForHealthHistory() -> [PVTSession] {
        sorted { leftSession, rightSession in
            if leftSession.startedAt != rightSession.startedAt {
                return leftSession.startedAt > rightSession.startedAt
            }

            return leftSession.id.uuidString < rightSession.id.uuidString
        }
    }

    nonisolated func latestSessionPerDay(calendar: Calendar) -> [PVTSession] {
        var sessionsByDay: [Date: PVTSession] = [:]

        for session in sortedForHealthHistory() {
            let day = calendar.startOfDay(for: session.startedAt)
            if sessionsByDay[day] == nil {
                sessionsByDay[day] = session
            }
        }

        return Array(sessionsByDay.values).sortedForHealthHistory()
    }
}

private extension Array where Element == Int {
    nonisolated var average: Double? {
        guard isEmpty == false else {
            return nil
        }

        return Double(reduce(0, +)) / Double(count)
    }

    nonisolated var median: Double? {
        guard isEmpty == false else {
            return nil
        }

        let sortedValues = sorted()
        let middleIndex = sortedValues.count / 2

        if sortedValues.count.isMultiple(of: 2) {
            return Double(sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2
        }

        return Double(sortedValues[middleIndex])
    }
}

private extension Array where Element == Double {
    nonisolated var sum: Double? {
        guard isEmpty == false else {
            return nil
        }

        return reduce(0, +)
    }
}

extension String {
    nonisolated var normalizedFoodSearchText: String {
        let lowered = lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }

            return " "
        }

        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

private extension Array where Element == Double {
    nonisolated var average: Double? {
        guard isEmpty == false else {
            return nil
        }

        return reduce(0, +) / Double(count)
    }
}

private extension Date {
    nonisolated func isInCurrentWindow(days: Int, endingAt endDate: Date, calendar: Calendar) -> Bool {
        isInWindow(days: days, endingAt: endDate, offsetDays: 0, calendar: calendar)
    }

    nonisolated func isInPreviousWindow(days: Int, endingAt endDate: Date, calendar: Calendar) -> Bool {
        isInWindow(days: days, endingAt: endDate, offsetDays: days, calendar: calendar)
    }

    nonisolated func isInWindow(days: Int, endingAt endDate: Date, offsetDays: Int, calendar: Calendar) -> Bool {
        guard days > 0,
              let windowEnd = calendar.date(
                byAdding: .day,
                value: -offsetDays + 1,
                to: calendar.startOfDay(for: endDate)
              ),
              let windowStart = calendar.date(byAdding: .day, value: -days, to: windowEnd)
        else {
            return false
        }

        return self >= windowStart && self < windowEnd
    }
}

extension Array where Element == WorkoutLog {
    nonisolated func sortedForHealthHistory() -> [WorkoutLog] {
        sorted { leftLog, rightLog in
            if leftLog.timestamp != rightLog.timestamp {
                return leftLog.timestamp > rightLog.timestamp
            }

            return leftLog.id.uuidString < rightLog.id.uuidString
        }
    }
}
