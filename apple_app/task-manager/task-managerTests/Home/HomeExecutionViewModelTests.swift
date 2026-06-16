import Foundation
import Testing
@testable import task_manager

@MainActor
struct HomeExecutionViewModelTests {
    private final class MemoryAppUpdateReminderStore: AppUpdateReminderStore {
        private(set) var record: AppUpdateReminderRecord?

        func loadRecord() -> AppUpdateReminderRecord? {
            record
        }

        func saveRecord(_ record: AppUpdateReminderRecord) {
            self.record = record
        }
    }

    private struct StubAppBuildMetadataProvider: AppBuildMetadataProviding {
        let appVersion: String
        let buildNumber: String
    }

    private final class RecordingAppUpdateReminderTracker: AppUpdateReminderTracking {
        private(set) var refreshCallCount = 0
        var summary: HomeAppUpdateReminderSummary?

        init(summary: HomeAppUpdateReminderSummary? = nil) {
            self.summary = summary
        }

        func refresh(now: Date, calendar: Calendar) -> HomeAppUpdateReminderSummary? {
            refreshCallCount += 1
            return summary
        }
    }

    @Test func todayViewModelLoadsAppRefreshReminderSummary() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let calendar = Calendar(identifier: .gregorian)
        let summary = HomeAppUpdateReminderSummary(
            appVersion: "1.0.0",
            buildNumber: "42",
            lastUpdatedAt: now.addingTimeInterval(-3 * 86_400),
            now: now,
            calendar: calendar
        )
        let tracker = RecordingAppUpdateReminderTracker(summary: summary)
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            appUpdateReminderTracker: tracker,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.appUpdateReminderSummary == summary)
        #expect(tracker.refreshCallCount == 1)
    }

    @Test func appRefreshReminderSummaryCalculatesCountdown() {
        let calendar = Calendar(identifier: .gregorian)
        let lastUpdatedAt = Date(timeIntervalSince1970: 1_710_000_000)
        let now = calendar.date(byAdding: .day, value: 5, to: lastUpdatedAt)!
        let summary = HomeAppUpdateReminderSummary(
            appVersion: "1.0.0",
            buildNumber: "42",
            lastUpdatedAt: lastUpdatedAt,
            now: now,
            calendar: calendar
        )

        #expect(summary.daysSinceUpdate == 5)
        #expect(summary.daysUntilSuggestedRefresh == 2)
        #expect(summary.countdownLabel == "2d left")
        #expect(summary.detail.contains("build 42"))
    }

    @Test func appRefreshReminderTrackerRecordsNewBuilds() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let store = MemoryAppUpdateReminderStore()
        let tracker = LiveAppUpdateReminderTracker(
            store: store,
            metadataProvider: StubAppBuildMetadataProvider(appVersion: "1.0.0", buildNumber: "42")
        )

        let firstSummary = tracker.refresh(now: now, calendar: calendar)

        #expect(firstSummary?.buildNumber == "42")
        #expect(store.record?.lastUpdatedAt == now)

        let later = now.addingTimeInterval(2 * 86_400)
        let updatedTracker = LiveAppUpdateReminderTracker(
            store: store,
            metadataProvider: StubAppBuildMetadataProvider(appVersion: "1.0.0", buildNumber: "43")
        )
        let updatedSummary = updatedTracker.refresh(now: later, calendar: calendar)

        #expect(updatedSummary?.buildNumber == "43")
        #expect(store.record?.buildNumber == "43")
        #expect(store.record?.lastUpdatedAt == later)
    }

    @Test func todayViewModelAggregatesActivePromisesAndRoutines() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let promise = Promise(
            title: "No weed until 6 PM",
            startAt: now.addingTimeInterval(-60),
            checkInAt: now.addingTimeInterval(60)
        )
        let item = RoutineItem(title: "Plan day", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        let log = RoutineCompletionLog(
            routineID: routine.id,
            date: Calendar(identifier: .gregorian).startOfDay(for: now),
            completedItemIDs: [item.id]
        )
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(promises: [promise]),
            routineRepository: FakeRoutineRepository(routines: [routine], logs: [log]),
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.activePromises == [promise])
        #expect(viewModel.routines == [routine])
        #expect(viewModel.routineProgress.count == 1)
        #expect(viewModel.routineProgress.first?.completedCount == 1)
    }

    @Test func todayViewModelLoadsPeopleMemorySummaryCounts() {
        let now = Date(timeIntervalSince1970: 10_000)
        let duePerson = PersonMemory(
            name: "Riley",
            whereMet: "Workshop",
            nextReviewAt: now.addingTimeInterval(-60)
        )
        let savedPerson = PersonMemory(name: "Morgan", whereMet: "Cafe")
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            peopleMemoryRepository: FakePeopleMemoryRepository(people: [savedPerson, duePerson]),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.peopleMemorySummary.totalCount == 2)
        #expect(viewModel.peopleMemorySummary.dueCount == 1)
        #expect(viewModel.peopleMemorySummary.detail == "1 due")
        #expect(HomePeopleMemorySummary(people: [savedPerson], now: now).detail == "1 saved")
        #expect(HomePeopleMemorySummary(people: [], now: now).detail == "No people yet")
    }

    @Test func todayViewModelLoadsVicesSummary() {
        let now = Date(timeIntervalSince1970: 10_000)
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let todaysLog = ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-120))
        let olderLog = ViceLog(
            viceID: vice.id,
            timestamp: now.addingTimeInterval(-90_000)
        )
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            viceRepository: FakeViceRepository(
                vices: [vice],
                logs: [todaysLog, olderLog]
            ),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.vicesSummary.activeViceCount == 1)
        #expect(viewModel.vicesSummary.totalTodayCount == 1)
        #expect(viewModel.vicesSummary.detail == "1 logged today")
    }

    @Test func todayViewModelUsesStableWelcomeMessageAcrossRepeatedLoads() {
        let now = Date(timeIntervalSince1970: 10_000)
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            nowProvider: { now }
        )

        viewModel.load()
        let firstMessage = viewModel.welcomeMessage
        viewModel.load()

        #expect(firstMessage == viewModel.welcomeMessage)
        #expect(firstMessage.isEmpty == false)
    }

    @Test func todayViewModelRepeatsMostRecentActiveViceLogFromHome() {
        let now = Date(timeIntervalSince1970: 50_000)
        let archivedVice = Vice(name: "Archived", unitLabel: "Hits", isArchived: true)
        let activeVice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let otherActiveVice = Vice(name: "Coffee", unitLabel: "Cups")
        let repository = FakeViceRepository(
            vices: [archivedVice, activeVice, otherActiveVice],
            logs: [
                ViceLog(viceID: archivedVice.id, timestamp: now.addingTimeInterval(-30)),
                ViceLog(viceID: otherActiveVice.id, timestamp: now.addingTimeInterval(-60)),
                ViceLog(viceID: activeVice.id, timestamp: now.addingTimeInterval(-120))
            ]
        )
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            viceRepository: repository,
            nowProvider: { now }
        )

        viewModel.load()
        let feedback = viewModel.repeatMostRecentViceLog()

        #expect(feedback.kind == .success)
        #expect(feedback.message == "Logged Coffee.")
        #expect(repository.logs.count == 4)
        #expect(repository.logs.last?.viceID == otherActiveVice.id)
        #expect(repository.sessions.count == 1)
        #expect(repository.sessions.first?.viceID == otherActiveVice.id)
        #expect(repository.sessions.first?.hitCount == 1)
        #expect(viewModel.vicesSummary.totalTodayCount == 4)
    }

    @Test func todayViewModelShowsWarningWhenNoRecentViceLogExists() {
        let now = Date(timeIntervalSince1970: 60_000)
        let activeVice = Vice(name: "Coffee", unitLabel: "Cups")
        let repository = FakeViceRepository(vices: [activeVice], logs: [])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            viceRepository: repository,
            nowProvider: { now }
        )

        viewModel.load()
        let feedback = viewModel.repeatMostRecentViceLog()

        #expect(feedback.kind == .warning)
        #expect(feedback.message == "No recent vice to repeat yet.")
        #expect(repository.logs.isEmpty)
        #expect(repository.sessions.isEmpty)
        #expect(viewModel.vicesSummary.totalTodayCount == 0)
    }

    @Test func todayViewModelResolvesPromiseAndUpdatesHistoryCounts() {
        let now = Date(timeIntervalSince1970: 1_000)
        let promiseRepository = FakePromiseRepository(promises: [
            Promise(title: "Stay present", startAt: now, checkInAt: now)
        ])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: promiseRepository,
            routineRepository: FakeRoutineRepository(),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.resolvePromise(
            withID: promiseRepository.promises[0].id,
            outcome: .kept,
            reflection: "Did it"
        )

        #expect(viewModel.activePromises.isEmpty)
        #expect(viewModel.keptCount == 1)
        #expect(viewModel.missedCount == 0)
    }

    @Test func todayViewModelUpdatesRoutineItemCompletion() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let item = RoutineItem(title: "Plan day", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.setRoutineItem(routineID: routine.id, itemID: item.id, state: .completed)

        #expect(viewModel.routineProgress.first?.completedCount == 1)
    }

    @Test func todayViewModelUpdatesRoutineItemSkippedState() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let item = RoutineItem(title: "Plan day", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.setRoutineItem(routineID: routine.id, itemID: item.id, state: .skipped)

        #expect(viewModel.routineProgress.first?.skippedCount == 1)
        #expect(viewModel.progress(for: routine.id)?.isComplete == true)
    }

    @Test func todayViewModelSavesQuickAddedTask() {
        let taskRepository = FakeTaskRepository()
        let viewModel = HomeExecutionViewModel(
            taskRepository: taskRepository,
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository()
        )
        let task = MyTask(title: "Send invoice", taskGroup: "Admin")

        viewModel.loadIfNeeded()
        viewModel.saveTask(task)

        #expect(taskRepository.tasks == [task])
        #expect(viewModel.tasks == [task])
        #expect(viewModel.taskGroups == ["Admin"])
        #expect(viewModel.reservedTaskIDs == [task.id])
    }

    @Test func todayViewModelLoadsInboxAndPinnedProjectSummaries() {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = Project(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            name: "Master's Thesis",
            isPinned: true
        )
        let capture = CaptureItem(
            title: "Ask advisor",
            projectID: project.id,
            createdAt: now.addingTimeInterval(-3_600)
        )
        let task = MyTask(title: "Draft outline", dueDate: now.addingTimeInterval(86_400), projectID: project.id)
        let completedTask = MyTask(
            title: "Submit intro",
            status: .completed,
            dueDate: now.addingTimeInterval(-86_400),
            projectID: project.id
        )
        let item = ProjectItem(projectID: project.id, kind: .maybe, title: "Explore method")
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(tasks: [task, completedTask]),
            projectRepository: FakeProjectRepository(projects: [project]),
            captureRepository: FakeCaptureRepository(captures: [capture]),
            projectItemRepository: FakeProjectItemRepository(items: [item]),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.inboxSummary.count == 1)
        #expect(viewModel.inboxSummary.projectTaggedCount == 1)
        #expect(viewModel.inboxSummary.oldestAgeLabel == "1h")
        #expect(viewModel.pinnedProjectSummaries.count == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.activeTaskCount == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.completedTaskCount == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.progressSummary == "1/2 tasks complete")
        #expect(viewModel.pinnedProjectSummaries.first?.projectItemCount == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.nextTask == task)
    }

    @Test func inboxReviewViewModelConvertsCaptureToTaskAndProjectItem() {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = Project(name: "Posso")
        let taskRepository = FakeTaskRepository()
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "Fix onboarding", projectID: project.id),
            CaptureItem(title: "Explore pricing", projectID: project.id)
        ])
        let projectItemRepository = FakeProjectItemRepository()
        let viewModel = InboxReviewViewModel(
            taskRepository: taskRepository,
            projectRepository: FakeProjectRepository(projects: [project]),
            captureRepository: captureRepository,
            projectItemRepository: projectItemRepository,
            shoppingRepository: FakeShoppingRepository(),
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )

        viewModel.load()
        let taskConversionSucceeded = viewModel.convertCurrentCaptureToTask(
            MyTaskFormData(title: "Fix onboarding", projectID: project.id)
        )

        #expect(taskConversionSucceeded == true)
        #expect(taskRepository.tasks.count == 1)
        #expect(taskRepository.tasks.first?.projectID == project.id)
        #expect(captureRepository.captures.first?.processedAt == now)

        let projectItemConversionSucceeded = viewModel.convertCurrentCaptureToProjectItem(
            kind: .maybe,
            title: "Explore pricing",
            notes: nil,
            projectID: project.id,
            source: nil,
            pressure: .useful,
            reviewAfter: nil
        )

        #expect(projectItemConversionSucceeded == true)
        #expect(projectItemRepository.items.count == 1)
        #expect(projectItemRepository.items.first?.kind == .maybe)
        #expect(projectItemRepository.items.first?.projectID == project.id)
    }

    @Test func inboxReviewViewModelConvertsCaptureToShoppingItem() {
        let now = Date(timeIntervalSince1970: 10_000)
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "Coffee filters", notes: "Size 4")
        ])
        let shoppingRepository = FakeShoppingRepository()
        let viewModel = InboxReviewViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            captureRepository: captureRepository,
            projectItemRepository: FakeProjectItemRepository(),
            shoppingRepository: shoppingRepository,
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )

        viewModel.load()
        let conversionSucceeded = viewModel.convertCurrentCaptureToShoppingItem(
            ShoppingItemFormData(
                title: "Coffee filters",
                notes: "Size 4",
                category: "Household",
                storeType: "Grocery",
                storeName: "Rewe",
                urgency: .needSoon,
                necessity: .necessary
            )
        )

        #expect(conversionSucceeded == true)
        #expect(shoppingRepository.items.count == 1)
        #expect(shoppingRepository.items.first?.title == "Coffee filters")
        #expect(shoppingRepository.items.first?.notes == "Size 4")
        #expect(shoppingRepository.items.first?.category == "Household")
        #expect(shoppingRepository.items.first?.storeType == "Grocery")
        #expect(shoppingRepository.items.first?.storeName == "Rewe")
        #expect(shoppingRepository.items.first?.urgency == .needSoon)
        #expect(shoppingRepository.items.first?.necessity == .necessary)
        #expect(shoppingRepository.items.first?.status == .needed)
        #expect(shoppingRepository.items.first?.createdAt == now)
        #expect(captureRepository.captures.first?.processedAt == now)
        #expect(viewModel.captures.isEmpty)
    }

    @Test func inboxReviewViewModelConvertsCaptureToPracticePiece() {
        let now = Date(timeIntervalSince1970: 10_000)
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "Prelude in C", notes: "Hands separate")
        ])
        let musicRepository = FakeMusicPracticeRepository()
        let viewModel = InboxReviewViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            captureRepository: captureRepository,
            projectItemRepository: FakeProjectItemRepository(),
            shoppingRepository: FakeShoppingRepository(),
            musicPracticeRepository: musicRepository,
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )

        viewModel.load()
        let conversionSucceeded = viewModel.convertCurrentCaptureToPracticePiece(
            PracticePiece(title: "Prelude in C", notes: "Hands separate")
        )

        #expect(conversionSucceeded == true)
        #expect(musicRepository.pieces.count == 1)
        #expect(musicRepository.pieces.first?.title == "Prelude in C")
        #expect(musicRepository.pieces.first?.notes == "Hands separate")
        #expect(captureRepository.captures.first?.processedAt == now)
    }

    @Test func inboxReviewViewModelTempSkipMovesCurrentCaptureToBackOfDeck() {
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "First"),
            CaptureItem(title: "Second"),
            CaptureItem(title: "Third")
        ])
        let viewModel = InboxReviewViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            captureRepository: captureRepository,
            projectItemRepository: FakeProjectItemRepository(),
            shoppingRepository: FakeShoppingRepository(),
            initialCaptures: [],
            initialProjects: []
        )

        viewModel.load()
        let skipped = viewModel.tempSkipCurrentCapture()

        #expect(skipped == true)
        #expect(viewModel.captures.map(\.title) == ["Second", "Third", "First"])
        #expect(viewModel.currentCapture?.title == "Second")
    }

    @Test func inboxReviewShoppingConversionFailureKeepsCapturePending() {
        let now = Date(timeIntervalSince1970: 10_000)
        let capture = CaptureItem(title: "Milk")
        let captureRepository = FakeCaptureRepository(captures: [capture])
        let shoppingRepository = FakeShoppingRepository()
        shoppingRepository.shouldThrow = true
        let viewModel = InboxReviewViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(),
            captureRepository: captureRepository,
            projectItemRepository: FakeProjectItemRepository(),
            shoppingRepository: shoppingRepository,
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )

        viewModel.load()
        let conversionSucceeded = viewModel.convertCurrentCaptureToShoppingItem(
            ShoppingItemFormData(title: "Milk")
        )

        #expect(conversionSucceeded == false)
        #expect(shoppingRepository.items.isEmpty)
        #expect(captureRepository.captures.first?.processedAt == nil)
        #expect(viewModel.currentCapture == capture)
        #expect(viewModel.errorMessage?.contains("Unable to create shopping item") == true)
    }

    @Test func inboxReviewMutationsRemovePendingCaptures() {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = Project(name: "Posso")
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "Fix onboarding", projectID: project.id),
            CaptureItem(title: "Archive me")
        ])
        let viewModel = InboxReviewViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(projects: [project]),
            captureRepository: captureRepository,
            projectItemRepository: FakeProjectItemRepository(),
            shoppingRepository: FakeShoppingRepository(),
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )

        viewModel.load()
        #expect(viewModel.captures.count == 2)

        #expect(
            viewModel.convertCurrentCaptureToTask(
                MyTaskFormData(title: "Fix onboarding", projectID: project.id)
            ) == true
        )
        #expect(viewModel.captures.count == 1)
        #expect(viewModel.currentCapture?.title == "Archive me")

        #expect(viewModel.archiveCurrentCapture() == true)
        #expect(viewModel.captures.isEmpty)
    }

    @Test func parentRefreshCallbackIsInvokedAfterReviewMutation() {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = Project(name: "Posso")
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "Fix onboarding", projectID: project.id)
        ])
        let viewModel = InboxReviewViewModel(
            taskRepository: FakeTaskRepository(),
            projectRepository: FakeProjectRepository(projects: [project]),
            captureRepository: captureRepository,
            projectItemRepository: FakeProjectItemRepository(),
            shoppingRepository: FakeShoppingRepository(),
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )
        var callbackCount = 0

        viewModel.load()

        if viewModel.convertCurrentCaptureToTask(
            MyTaskFormData(title: "Fix onboarding", projectID: project.id)
        ) {
            callbackCount += 1
        }

        #expect(callbackCount == 1)
    }

    @Test func todayViewModelExposesCurrentRoutineItemAndAdvances() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.progress(for: routine.id)?.currentItem == firstItem)
        #expect(viewModel.progress(for: routine.id)?.actionLabel == "Start")

        viewModel.completeCurrentRoutineItem(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.currentItem == secondItem)
        #expect(viewModel.progress(for: routine.id)?.actionLabel == "Continue")

        viewModel.completeCurrentRoutineItem(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.isComplete == true)
        #expect(viewModel.progress(for: routine.id)?.actionLabel == "Review")
    }

    @Test func todayViewModelUndoRevertsLastCompletedRoutineStep() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.completeCurrentRoutineItem(routineID: routine.id)
        viewModel.undoLastRoutineAction(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.currentItem == firstItem)
        #expect(viewModel.progress(for: routine.id)?.completedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.skippedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.isComplete == false)
    }

    @Test func todayViewModelUndoRevertsLastSkippedRoutineStep() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.setRoutineItem(routineID: routine.id, itemID: firstItem.id, state: .skipped)

        #expect(viewModel.progress(for: routine.id)?.currentItem == secondItem)

        viewModel.undoLastRoutineAction(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.currentItem == firstItem)
        #expect(viewModel.progress(for: routine.id)?.completedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.skippedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.isComplete == false)
    }

    @Test func todayViewModelUndoRoutineActionDoesNothingWithoutTodayProgress() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let item = RoutineItem(title: "Open curtains", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.undoLastRoutineAction(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.currentItem == item)
        #expect(viewModel.progress(for: routine.id)?.completedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.skippedCount == 0)
    }

    @Test func todayViewModelDoesNotCarryYesterdayRoutineProgressIntoToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 9))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let yesterdayLog = RoutineCompletionLog(
            routineID: routine.id,
            date: yesterday,
            completedItemIDs: [firstItem.id]
        )
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(routines: [routine], logs: [yesterdayLog]),
            calendar: calendar,
            nowProvider: { today }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.progress(for: routine.id)?.completedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.currentItem == firstItem)
    }

    @Test func todayViewModelLoadsCalendarOverviewWhenAccessIsGranted() async {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: now)
        let event = CalendarEventSnapshot(
            identifier: "workout",
            calendarIdentifier: nil,
            title: "Workout",
            start: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
            end: calendar.date(byAdding: .hour, value: 10, to: startOfDay)!,
            isAllDay: false,
            calendarTitle: "Personal"
        )
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(status: .fullAccessGranted),
            calendarReader: FakeCalendarReader(events: [event]),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.calendarOverview?.events == [event])
        #expect(viewModel.calendarOverview?.nextEvent == event)
        #expect(viewModel.calendarPermissionStatus == .fullAccessGranted)
    }

    @Test func todayViewModelLoadsHealthSummary() {
        let now = Date(timeIntervalSince1970: 1_000)
        let checkIn = SleepCheckIn(day: now, energyRating: 4)
        let meal = MealLog(timestamp: now, summary: "Oats")
        let workout = WorkoutLog(timestamp: now, workoutType: .walk)
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            healthRepository: FakeHomeHealthRepository(
                sleepCheckIns: [checkIn],
                mealLogs: [meal],
                workoutLogs: [workout]
            ),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.healthSummary.sleepCheckIn == checkIn)
        #expect(viewModel.healthSummary.todaysMealLogs == [meal])
        #expect(viewModel.healthSummary.recentWorkoutLogs == [workout])
        #expect(viewModel.healthSummary.detail == "Energy 4/5 · 1 meal")
    }

    @Test func todayViewModelLoadsFitnessSummary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 12))!
        let exercise = FitnessExercise(
            name: "Bench",
            tag: .push,
            trackingStyle: .strengthSets,
            weightUnit: .pounds
        )
        let template = WorkoutTemplate(name: "Push Day", exerciseIDs: [exercise.id])
        let session = ExerciseSession(
            exerciseID: exercise.id,
            performedAt: now,
            strengthSets: [StrengthSet(reps: 5, weight: 185)]
        )
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            fitnessRepository: FakeHomeFitnessRepository(
                exercises: [exercise],
                templates: [template],
                sessions: [session]
            ),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.fitnessSummary.value == "Today")
        #expect(viewModel.fitnessSummary.detail.contains("Last") == true)
    }
}

@MainActor
private final class FakeTaskRepository: TaskRepository {
    var tasks: [MyTask]

    init(tasks: [MyTask] = []) {
        self.tasks = tasks
    }

    func fetchTasks() throws -> [MyTask] {
        tasks
    }

    func task(withID id: UUID) throws -> MyTask? {
        tasks.first { $0.id == id }
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {
        let targetID = originalID ?? task.id

        if let index = tasks.firstIndex(where: { $0.id == targetID || $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    func deleteTask(withID id: UUID) throws {
        tasks.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeProjectRepository: ProjectRepository {
    var projects: [Project]

    init(projects: [Project] = []) {
        self.projects = projects
    }

    func fetchProjects(includeArchived: Bool) throws -> [Project] {
        projects.filter { includeArchived || $0.isArchived == false }
    }

    func project(withID id: UUID) throws -> Project? {
        projects.first { $0.id == id }
    }

    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) throws {
        let targetID = originalID ?? project.id
        if let index = projects.firstIndex(where: { $0.id == targetID || $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }

    func archiveProject(withID id: UUID, archivedAt: Date) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            return
        }
        projects[index].isArchived = true
        projects[index].updatedAt = archivedAt
    }

    func deleteProject(withID id: UUID) throws {
        projects.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeCaptureRepository: CaptureRepository {
    var captures: [CaptureItem]

    init(captures: [CaptureItem] = []) {
        self.captures = captures
    }

    func fetchCaptures(includeProcessed: Bool, includeArchived: Bool) throws -> [CaptureItem] {
        captures.filter { capture in
            (includeProcessed || capture.processedAt == nil)
                && (includeArchived || capture.archivedAt == nil)
        }
    }

    func capture(withID id: UUID) throws -> CaptureItem? {
        captures.first { $0.id == id }
    }

    func saveCapture(_ capture: CaptureItem, replacingCaptureWithID originalID: UUID?) throws {
        let targetID = originalID ?? capture.id
        if let index = captures.firstIndex(where: { $0.id == targetID || $0.id == capture.id }) {
            captures[index] = capture
        } else {
            captures.append(capture)
        }
    }

    func deleteCapture(withID id: UUID) throws {
        captures.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeProjectItemRepository: ProjectItemRepository {
    var items: [ProjectItem]

    init(items: [ProjectItem] = []) {
        self.items = items
    }

    func fetchProjectItems(includeArchived: Bool) throws -> [ProjectItem] {
        items.filter { includeArchived || $0.isArchived == false }
    }

    func fetchProjectItems(for projectID: UUID, includeArchived: Bool) throws -> [ProjectItem] {
        try fetchProjectItems(includeArchived: includeArchived).filter { $0.projectID == projectID }
    }

    func projectItem(withID id: UUID) throws -> ProjectItem? {
        items.first { $0.id == id }
    }

    func saveProjectItem(_ item: ProjectItem, replacingProjectItemWithID originalID: UUID?) throws {
        let targetID = originalID ?? item.id
        if let index = items.firstIndex(where: { $0.id == targetID || $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func archiveProjectItem(withID id: UUID, archivedAt: Date) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].isArchived = true
        items[index].updatedAt = archivedAt
    }

    func deleteProjectItem(withID id: UUID) throws {
        items.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeShoppingRepository: ShoppingRepository {
    enum FakeError: LocalizedError {
        case failed

        var errorDescription: String? {
            "failed"
        }
    }

    var items: [ShoppingItem]
    var shouldThrow = false

    init(items: [ShoppingItem] = []) {
        self.items = items
    }

    func fetchShoppingItems(includeHistory: Bool) throws -> [ShoppingItem] {
        if shouldThrow {
            throw FakeError.failed
        }

        if includeHistory {
            return items.sortedForShoppingTrips()
        }

        return items.filter(\.isActive).sortedForShoppingTrips()
    }

    func fetchActiveShoppingItems() throws -> [ShoppingItem] {
        try fetchShoppingItems(includeHistory: false)
    }

    func fetchShoppingHistory() throws -> [ShoppingItem] {
        if shouldThrow {
            throw FakeError.failed
        }

        return items
            .filter { $0.isActive == false }
            .sorted { leftItem, rightItem in
                (leftItem.completedAt ?? leftItem.updatedAt) > (rightItem.completedAt ?? rightItem.updatedAt)
            }
    }

    func shoppingItem(withID id: UUID) throws -> ShoppingItem? {
        if shouldThrow {
            throw FakeError.failed
        }

        return items.first { $0.id == id }
    }

    func saveShoppingItem(_ item: ShoppingItem, replacingItemWithID originalID: UUID?) throws {
        if shouldThrow {
            throw FakeError.failed
        }

        let targetID = originalID ?? item.id
        if let index = items.firstIndex(where: { $0.id == targetID || $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func updateShoppingItemStatus(
        withID id: UUID,
        status: ShoppingItemStatus,
        at date: Date
    ) throws {
        if shouldThrow {
            throw FakeError.failed
        }

        guard let item = items.first(where: { $0.id == id }) else {
            return
        }

        try saveShoppingItem(
            item.updatingStatus(status, at: date),
            replacingItemWithID: id
        )
    }

    func deleteShoppingItem(withID id: UUID) throws {
        if shouldThrow {
            throw FakeError.failed
        }

        items.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeMusicPracticeRepository: MusicPracticeRepository {
    private(set) var pieces: [PracticePiece] = []

    func fetchPracticePieces(includeArchived: Bool) throws -> [PracticePiece] {
        includeArchived ? pieces : pieces.filter { $0.isArchived == false }
    }

    func practicePiece(withID id: UUID) throws -> PracticePiece? {
        pieces.first { $0.id == id }
    }

    func savePracticePiece(_ piece: PracticePiece, replacingPieceWithID originalID: UUID?) throws {
        if let originalID, let index = pieces.firstIndex(where: { $0.id == originalID }) {
            pieces[index] = piece
        } else if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
            pieces[index] = piece
        } else {
            pieces.append(piece)
        }
    }

    func fetchPracticeSessions(limit: Int) throws -> [PracticeSession] { [] }

    func fetchPracticeSessions(from startDate: Date, to endDate: Date) throws -> [PracticeSession] { [] }

    func practiceSession(withID id: UUID) throws -> PracticeSession? { nil }

    func savePracticeSession(_ session: PracticeSession, replacingSessionWithID originalID: UUID?) throws {}

    func deletePracticeSession(withID id: UUID) throws {}
}

@MainActor
private final class FakePromiseRepository: PromiseRepository {
    var promises: [Promise]

    init(promises: [Promise] = []) {
        self.promises = promises
    }

    func fetchPromises() throws -> [Promise] {
        promises
    }

    func fetchActivePromises(at date: Date) throws -> [Promise] {
        promises.filter { $0.isPresent(at: date) }
    }

    func fetchDuePromises(at date: Date) throws -> [Promise] {
        promises.filter { $0.isDueForCheckIn(at: date) }
    }

    func fetchPromiseHistory() throws -> [Promise] {
        promises.filter { $0.status == .resolved }
    }

    func promise(withID id: UUID) throws -> Promise? {
        promises.first { $0.id == id }
    }

    func savePromise(_ promise: Promise, replacingPromiseWithID originalID: UUID?) throws {
        let targetID = originalID ?? promise.id

        if let index = promises.firstIndex(where: { $0.id == targetID || $0.id == promise.id }) {
            promises[index] = promise
        } else {
            promises.append(promise)
        }
    }

    func resolvePromise(
        withID id: UUID,
        outcome: PromiseOutcome,
        reflection: String?,
        resolvedAt: Date
    ) throws {
        guard let promise = promises.first(where: { $0.id == id }) else {
            return
        }

        try savePromise(
            promise.resolved(outcome: outcome, reflection: reflection, resolvedAt: resolvedAt),
            replacingPromiseWithID: id
        )
    }

    func deletePromise(withID id: UUID) throws {
        promises.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeRoutineRepository: RoutineRepository {
    var routines: [Routine]
    var logs: [RoutineCompletionLog]

    init(routines: [Routine] = [], logs: [RoutineCompletionLog] = []) {
        self.routines = routines
        self.logs = logs
    }

    func fetchRoutines() throws -> [Routine] {
        routines
    }

    func fetchActiveRoutines(on date: Date, calendar: Calendar) throws -> [Routine] {
        routines.filter { $0.isActive(on: date, calendar: calendar) }
    }

    func routine(withID id: UUID) throws -> Routine? {
        routines.first { $0.id == id }
    }

    func saveRoutine(_ routine: Routine, replacingRoutineWithID originalID: UUID?) throws {
        let targetID = originalID ?? routine.id

        if let index = routines.firstIndex(where: { $0.id == targetID || $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    func deleteRoutine(withID id: UUID) throws {
        routines.removeAll { $0.id == id }
    }

    func fetchCompletionLog(
        for routineID: UUID,
        on date: Date,
        calendar: Calendar
    ) throws -> RoutineCompletionLog? {
        logs.first { log in
            log.routineID == routineID && calendar.isDate(log.date, inSameDayAs: date)
        }
    }

    func fetchCompletionLogs(on date: Date, calendar: Calendar) throws -> [RoutineCompletionLog] {
        logs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func saveCompletionLog(_ log: RoutineCompletionLog, replacingLogWithID originalID: UUID?) throws {
        let targetID = originalID ?? log.id

        if let index = logs.firstIndex(where: { $0.id == targetID || $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
    }
}

@MainActor
private final class FakeHomeHealthRepository: HealthRepository {
    var sleepCheckIns: [SleepCheckIn]
    var foodCatalogItems: [FoodCatalogItem]
    var mealLogs: [MealLog]
    var workoutLogs: [WorkoutLog]

    init(
        sleepCheckIns: [SleepCheckIn] = [],
        foodCatalogItems: [FoodCatalogItem] = [],
        mealLogs: [MealLog] = [],
        workoutLogs: [WorkoutLog] = []
    ) {
        self.sleepCheckIns = sleepCheckIns
        self.foodCatalogItems = foodCatalogItems
        self.mealLogs = mealLogs
        self.workoutLogs = workoutLogs
    }

    func fetchSleepCheckIns(limit: Int) throws -> [SleepCheckIn] {
        Array(sleepCheckIns.prefix(max(0, limit)))
    }

    func fetchSleepCheckIn(on date: Date, calendar: Calendar) throws -> SleepCheckIn? {
        sleepCheckIns.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID?) throws {
        sleepCheckIns.append(checkIn)
    }

    func searchFoodCatalogItems(matching query: String, limit: Int) throws -> [FoodCatalogItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = normalizedQuery.isEmpty
            ? foodCatalogItems
            : foodCatalogItems.filter { $0.name.lowercased().contains(normalizedQuery) }
        return Array(filtered.prefix(max(0, limit)))
    }

    func fetchCustomFoodCatalogItems() throws -> [FoodCatalogItem] {
        foodCatalogItems
    }

    func saveFoodCatalogItem(_ item: FoodCatalogItem) throws {
        if let index = foodCatalogItems.firstIndex(where: { $0.id == item.id }) {
            foodCatalogItems[index] = item
        } else {
            foodCatalogItems.append(item)
        }
    }

    func deleteFoodCatalogItem(withID id: UUID) throws {
        foodCatalogItems.removeAll { $0.id == id }
    }

    func fetchMealLogs(on date: Date, calendar: Calendar) throws -> [MealLog] {
        mealLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.sortedForHealthHistory()
    }

    func fetchRecentMealLogs(limit: Int) throws -> [MealLog] {
        Array(mealLogs.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func mealLog(withID id: UUID) throws -> MealLog? {
        mealLogs.first { $0.id == id }
    }

    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID?) throws {
        mealLogs.append(log)
    }

    func deleteMealLog(withID id: UUID) throws {
        mealLogs.removeAll { $0.id == id }
    }

    func fetchWorkoutLogs(on date: Date, calendar: Calendar) throws -> [WorkoutLog] {
        workoutLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.sortedForHealthHistory()
    }

    func fetchRecentWorkoutLogs(limit: Int) throws -> [WorkoutLog] {
        Array(workoutLogs.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func workoutLog(withID id: UUID) throws -> WorkoutLog? {
        workoutLogs.first { $0.id == id }
    }

    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID?) throws {
        workoutLogs.append(log)
    }

    func deleteWorkoutLog(withID id: UUID) throws {
        workoutLogs.removeAll { $0.id == id }
    }

    func fetchPVTSessions(on date: Date, calendar: Calendar) throws -> [PVTSession] {
        []
    }

    func fetchRecentPVTSessions(limit: Int) throws -> [PVTSession] {
        []
    }

    func savePVTSession(_ session: PVTSession) throws {}
}

@MainActor
private final class FakeHomeFitnessRepository: FitnessRepository {
    var exercises: [FitnessExercise]
    var templates: [WorkoutTemplate]
    var sessions: [ExerciseSession]

    init(
        exercises: [FitnessExercise] = [],
        templates: [WorkoutTemplate] = [],
        sessions: [ExerciseSession] = []
    ) {
        self.exercises = exercises
        self.templates = templates
        self.sessions = sessions
    }

    func fetchExercises() throws -> [FitnessExercise] {
        exercises
    }

    func exercise(withID id: UUID) throws -> FitnessExercise? {
        exercises.first { $0.id == id }
    }

    func saveExercise(_ exercise: FitnessExercise, replacingExerciseWithID originalID: UUID?) throws {}

    func fetchWorkoutTemplates() throws -> [WorkoutTemplate] {
        templates
    }

    func workoutTemplate(withID id: UUID) throws -> WorkoutTemplate? {
        templates.first { $0.id == id }
    }

    func saveWorkoutTemplate(_ template: WorkoutTemplate, replacingWorkoutTemplateWithID originalID: UUID?) throws {}

    func deleteWorkoutTemplate(withID id: UUID) throws {}

    func fetchExerciseSessions() throws -> [ExerciseSession] {
        sessions.sortedForExerciseHistory()
    }

    func exerciseSession(withID id: UUID) throws -> ExerciseSession? {
        sessions.first { $0.id == id }
    }

    func saveExerciseSession(_ session: ExerciseSession, replacingExerciseSessionWithID originalID: UUID?) throws {}

    func deleteExerciseSession(withID id: UUID) throws {}
}

@MainActor
private final class FakeViceRepository: ViceRepository {
    var vices: [Vice]
    var logs: [ViceLog]
    var sessions: [ViceSession]

    init(
        vices: [Vice] = [],
        logs: [ViceLog] = [],
        sessions: [ViceSession] = []
    ) {
        self.vices = vices
        self.logs = logs
        self.sessions = sessions
    }

    func fetchVices(includeArchived: Bool) throws -> [Vice] {
        if includeArchived {
            return vices
        }

        return vices.filter { $0.isArchived == false }
    }

    func vice(withID id: UUID) throws -> Vice? {
        vices.first { $0.id == id }
    }

    func saveVice(_ vice: Vice, replacingViceWithID originalID: UUID?) throws {
        let targetID = originalID ?? vice.id
        if let index = vices.firstIndex(where: { $0.id == targetID || $0.id == vice.id }) {
            vices[index] = vice
        } else {
            vices.append(vice)
        }
    }

    func archiveVice(withID id: UUID, archivedAt: Date) throws {
        guard let index = vices.firstIndex(where: { $0.id == id }) else {
            return
        }

        vices[index].isArchived = true
        vices[index].updatedAt = archivedAt
    }

    func fetchViceLogs() throws -> [ViceLog] {
        logs.sortedForViceLogs()
    }

    func fetchViceLogs(
        for viceID: UUID,
        from startDate: Date,
        to endDate: Date
    ) throws -> [ViceLog] {
        logs.filter { log in
            log.viceID == viceID && log.timestamp >= startDate && log.timestamp <= endDate
        }
    }

    func saveViceLog(_ log: ViceLog) throws {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
    }

    func deleteViceLog(withID id: UUID) throws {
        logs.removeAll { $0.id == id }
    }

    func fetchViceSessions() throws -> [ViceSession] {
        sessions.sortedForViceSessions()
    }

    func saveViceSession(_ session: ViceSession) throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else if let index = sessions.firstIndex(where: { $0.viceID == session.viceID && $0.isActive(at: session.lastHitAt) }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func deleteViceSession(withID id: UUID) throws {
        sessions.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeCalendarPermissionProvider: CalendarPermissionProviding {
    let status: CalendarPermissionStatus

    init(status: CalendarPermissionStatus) {
        self.status = status
    }

    func currentStatus() -> CalendarPermissionStatus {
        status
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        status
    }
}

@MainActor
private final class FakeCalendarReader: CalendarReading {
    let events: [CalendarEventSnapshot]

    init(events: [CalendarEventSnapshot]) {
        self.events = events
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        events.filter { event in
            event.end > window.start && event.start < window.end
        }
    }
}
