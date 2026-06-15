import Foundation
import Testing
@testable import task_manager

struct HealthModelTests {
    @Test func sleepCheckInCleansAndClampsValues() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!

        let checkIn = SleepCheckIn(
            day: date,
            sleepDurationMinutes: -15,
            sleepQualityRating: 8,
            tirednessRating: 0,
            energyRating: 3,
            contextTags: [.stress, .caffeine, .stress],
            notes: "  Woke up twice  ",
            calendar: calendar
        )

        #expect(checkIn.day == calendar.startOfDay(for: date))
        #expect(checkIn.sleepDurationMinutes == 0)
        #expect(checkIn.sleepQualityRating == 5)
        #expect(checkIn.tirednessRating == 1)
        #expect(checkIn.energyRating == 3)
        #expect(checkIn.contextTags == [.caffeine, .stress])
        #expect(checkIn.notes == "Woke up twice")
        #expect(checkIn.isForSameDay(as: date, calendar: calendar))
    }

    @Test func mealLogCleansSummaryAndSortsNewestFirst() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let base = Date(timeIntervalSince1970: 1_000)
        let oats = FoodCatalogItem(
            name: "Oatmeal",
            servingDescription: "1 bowl",
            nutritionPerServing: NutritionFacts(calories: 150, proteinGrams: 5, carbGrams: 27, sugarGrams: 1, fiberGrams: 4)
        )
        let berries = FoodCatalogItem(
            name: "Blueberries",
            servingDescription: "1 cup",
            nutritionPerServing: NutritionFacts(calories: 85, proteinGrams: 1, carbGrams: 21, sugarGrams: 15, fiberGrams: 3.6)
        )
        let older = MealLog(
            id: secondID,
            timestamp: base,
            summary: "  ",
            entries: [
                MealEntry(food: oats),
                MealEntry(food: berries, servings: 0.5)
            ],
            notes: "  good  "
        )
        let newer = MealLog(
            id: firstID,
            timestamp: base.addingTimeInterval(60),
            summary: "Smoothie"
        )

        #expect(older.summary == "Oatmeal, Blueberries")
        #expect(older.notes == "good")
        #expect(older.totalCalories == 192.5)
        #expect(older.totalProteinGrams == 5.5)
        #expect(older.totalCarbGrams == 37.5)
        #expect(older.totalSugarGrams == 8.5)
        #expect(((older.totalFiberGrams ?? 0) * 10).rounded() == 58)
        #expect(MealLog(newSummary: "  ") == nil)
        #expect([older, newer].sortedForHealthHistory().map(\.id) == [firstID, secondID])
    }

    @Test func foodCatalogItemAndMealEntryCleanValues() {
        let customFood = FoodCatalogItem(
            name: "  Carrots + Peas  ",
            servingDescription: "  1 bowl  ",
            nutritionPerServing: NutritionFacts(
                calories: 110,
                proteinGrams: 4.5,
                carbGrams: 18,
                sugarGrams: 8,
                fiberGrams: 6,
                sodiumMilligrams: -40
            )
        )
        let entry = MealEntry(food: customFood, servings: -2, note: "  frozen mix  ")

        #expect(customFood.name == "Carrots + Peas")
        #expect(customFood.servingDescription == "1 bowl")
        #expect(customFood.nutritionPerServing.sodiumMilligrams == 0)
        #expect(entry.servings == 1)
        #expect(entry.note == "frozen mix")
        #expect(entry.totalNutrition.calories == 110)
        #expect(entry.totalNutrition.fiberGrams == 6)
    }

    @Test func workoutLogClampsDurationAndSortsNewestFirst() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let base = Date(timeIntervalSince1970: 1_000)
        let older = WorkoutLog(
            id: secondID,
            timestamp: base,
            workoutType: .strength,
            durationMinutes: -20,
            intensityRating: 9,
            energyBeforeRating: 0,
            energyAfterRating: 4,
            notes: "  Deadlifts  "
        )
        let newer = WorkoutLog(
            id: firstID,
            timestamp: base.addingTimeInterval(60),
            workoutType: .walk
        )

        #expect(older.durationMinutes == 0)
        #expect(older.intensityRating == 5)
        #expect(older.energyBeforeRating == 1)
        #expect(older.energyAfterRating == 4)
        #expect(older.notes == "Deadlifts")
        #expect([older, newer].sortedForHealthHistory().map(\.id) == [firstID, secondID])
    }

    @Test func pvtSessionCleansValuesAndComputesMetrics() {
        let session = PVTSession(
            durationSeconds: -30,
            reactionTimesMilliseconds: [400, -20, 500, 200],
            falseStartCount: -2,
            missCount: -1,
            notes: "  distracted  "
        )

        #expect(session.durationSeconds == 0)
        #expect(session.reactionTimesMilliseconds == [400, 500, 200])
        #expect(session.falseStartCount == 0)
        #expect(session.missCount == 0)
        #expect(session.notes == "distracted")
        #expect(session.responseCount == 3)
        #expect(session.averageReactionMilliseconds == 1_100.0 / 3.0)
        #expect(session.medianReactionMilliseconds == 400)
        #expect(session.lapseCount == 1)
    }

    @Test func pvtSessionsSortAndKeepLatestSessionPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: morning)!
        let morningSession = PVTSession(id: secondID, startedAt: morning, reactionTimesMilliseconds: [350])
        let afternoonSession = PVTSession(id: firstID, startedAt: afternoon, reactionTimesMilliseconds: [300])
        let yesterdaySession = PVTSession(id: thirdID, startedAt: yesterday, reactionTimesMilliseconds: [400])

        #expect(
            [morningSession, yesterdaySession, afternoonSession]
                .sortedForHealthHistory()
                .map(\.id) == [firstID, secondID, thirdID]
        )
        #expect(
            [morningSession, yesterdaySession, afternoonSession]
                .latestSessionPerDay(calendar: calendar)
                .map(\.id) == [firstID, thirdID]
        )
    }

    @Test func healthTrendSummaryUsesLatestPVTSessionPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 18))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!
        let morningSession = PVTSession(startedAt: morning, reactionTimesMilliseconds: [500, 600, 700])
        let afternoonSession = PVTSession(startedAt: afternoon, reactionTimesMilliseconds: [200, 300, 400])
        let summary = HealthTrendSummary(
            sleepCheckIns: [],
            pvtSessions: [morningSession, afternoonSession],
            mealLogs: [],
            workoutLogs: [],
            now: now,
            calendar: calendar
        )

        #expect(summary.sleepPVT.current7Days.pvtDaysLogged == 1)
        #expect(summary.sleepPVT.current7Days.averagePVTMedianMilliseconds == 300)
    }

    @Test func nutritionTrendSummaryAggregatesMealEntryNutrition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 18))!
        let meal = MealLog(
            timestamp: now,
            entries: [
                MealEntry(
                    foodName: "Pork schnitzel",
                    servings: 1,
                    nutritionPerServing: NutritionFacts(calories: 320, proteinGrams: 24, carbGrams: 18, sugarGrams: 1, fiberGrams: 1)
                ),
                MealEntry(
                    foodName: "Fried potatoes",
                    servings: 1,
                    nutritionPerServing: NutritionFacts(calories: 280, proteinGrams: 4, carbGrams: 32, sugarGrams: 1, fiberGrams: 3)
                ),
                MealEntry(
                    foodName: "Carrots + peas",
                    servings: 1,
                    nutritionPerServing: NutritionFacts(calories: 110, proteinGrams: 5, carbGrams: 18, sugarGrams: 8, fiberGrams: 6)
                )
            ]
        )

        let summary = NutritionTrendSummary(mealLogs: [meal], now: now, calendar: calendar)

        #expect(summary.current7Days.mealCount == 1)
        #expect(summary.current7Days.mealEntryCount == 3)
        #expect(summary.current7Days.totalCalories == 710)
        #expect(summary.current7Days.totalProteinGrams == 33)
        #expect(summary.current7Days.totalCarbGrams == 68)
        #expect(summary.current7Days.totalSugarGrams == 10)
        #expect(summary.current7Days.totalFiberGrams == 10)
    }
}
