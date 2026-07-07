import SwiftData

enum ModelContainerFactory {
    static func makeDefaultContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: false)
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    private static func makeContainer(
        isStoredInMemoryOnly: Bool
    ) throws -> ModelContainer {
        let schema = Schema([
            TaskRecord.self,
            ProjectRecord.self,
            CaptureItemRecord.self,
            ProjectItemRecord.self,
            ScheduledBlockRecord.self,
            AppSettingsRecord.self,
            AlertTemplateRecord.self,
            HomeLayoutRecord.self,
            PromiseRecord.self,
            RoutineRecord.self,
            RoutineCompletionLogRecord.self,
            ViceRoutineUnlockRecord.self,
            ShoppingItemRecord.self,
            SleepCheckInRecord.self,
            MealLogRecord.self,
            FoodCatalogItemRecord.self,
            WorkoutLogRecord.self,
            PVTSessionRecord.self,
            PracticePieceRecord.self,
            PracticeSessionRecord.self,
            FitnessExerciseRecord.self,
            WorkoutTemplateRecord.self,
            ExerciseSessionRecord.self,
            FitnessRouteRecord.self,
            PersonMemoryRecord.self,
            PersonTagRecord.self,
            CalendarBlockFocusRecord.self,
            CalendarDebriefRecordModel.self,
            FinanceCategoryRecord.self,
            FinanceTransactionRecord.self,
            ViceRecord.self,
            ViceLogRecord.self,
            ViceSessionRecord.self,
            ViceGoalRecord.self,
        ])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(for: schema, configurations: configuration)
    }
}
