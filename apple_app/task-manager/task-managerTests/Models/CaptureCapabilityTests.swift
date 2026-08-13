import Foundation
import Testing
@testable import task_manager

struct CaptureCapabilityTests {
    @Test func registryBuildsTaskModuleWithMultipleKinds() {
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174321")
        let capture = RawCapture(
            title: "Finish report",
            notes: "Send the draft",
            projectID: projectID
        )
        let registry = makeRegistry()

        let modules = registry.moduleOptions(for: capture)
        let taskModule = modules.first { $0.manifest.moduleID == .tasks }

        #expect(taskModule?.kinds.map(\.kindManifest.id) == ["task", "project-maybe", "project-note"])
        #expect(taskModule?.kinds.first?.initialDraft.title == "Finish report")
        #expect(taskModule?.kinds.first?.initialDraft.notes == "Send the draft")
        #expect(taskModule?.kinds.first?.initialDraft.projectID == projectID)
        #expect(taskModule?.kinds.first?.kindManifest.defaultTemplateID == "follow_up")
    }

    @Test func registrySeedsShoppingManifestWithEditablePresets() {
        let capture = RawCapture(title: "Milk", notes: "2 bottles")
        let registry = makeRegistry()

        let shoppingKind = registry
            .moduleOptions(for: capture)
            .first { $0.manifest.moduleID == .shopping }?
            .kinds
            .first

        #expect(shoppingKind?.kindManifest.id == "shopping-item")
        #expect(shoppingKind?.initialDraft.title == "Milk")
        #expect(shoppingKind?.initialDraft.notes == "2 bottles")
        #expect(shoppingKind?.kindManifest.templates.map(\.id) == ["groceries", "household", "online"])
        #expect(shoppingKind?.kindManifest.customizationOptions.first?.fieldKeys == [.shoppingStoreType, .shoppingStoreName])
    }

    @Test func registryIncludesPeopleModuleAndTagCustomization() {
        let capture = RawCapture(title: "Sarah", notes: "Met at pottery class")
        let registry = makeRegistry()

        let peopleKind = registry
            .moduleOptions(for: capture)
            .first { $0.manifest.moduleID == .peopleMemory }?
            .kinds
            .first

        #expect(peopleKind?.kindManifest.id == "person-memory")
        #expect(peopleKind?.initialDraft.personName == "Sarah")
        #expect(peopleKind?.kindManifest.fields.contains { $0.key == .personTags } == true)
        #expect(peopleKind?.kindManifest.customizationOptions.map(\.id) == ["people_detail", "people_tags"])
    }

    @Test func registryDefaultsCaptureIntakeToTabsPresentation() {
        let capture = RawCapture(title: "Finish report")
        let registry = makeRegistry()

        let module = registry.moduleOptions(for: capture).first { $0.manifest.moduleID == .tasks }

        #expect(module?.manifest.preferredPresentation == .tabs)
        #expect(module?.kinds.allSatisfy { $0.kindManifest.preferredPresentation == .tabs } == true)
    }

    @Test func taskFormDataNormalizesDateOnlyDueDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 14, minute: 30))!
        let formData = MyTaskFormData(title: "Read", hasDueDate: true, dueDate: dueDate)

        #expect(formData.normalizedDueDate(keepingExactTime: false, calendar: calendar) == calendar.startOfDay(for: dueDate))
    }

    @Test func taskFormDataPreservesExactTimeWhenEnabled() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 14, minute: 30))!
        let formData = MyTaskFormData(title: "Read", hasDueDate: true, dueDate: dueDate)

        #expect(formData.normalizedDueDate(keepingExactTime: true, calendar: calendar) == dueDate)
    }

    @MainActor
    private func makeRegistry() -> CaptureIntakeRegistry {
        CaptureIntakeRegistry.standard(
            taskRepository: NoopTaskRepository(),
            projectItemRepository: NoopProjectItemRepository(),
            shoppingRepository: NoopShoppingRepository(),
            musicPracticeRepository: NoopMusicPracticeRepository(),
            peopleMemoryRepository: NoopPeopleMemoryRepository()
        )
    }
}

@MainActor
private struct NoopTaskRepository: TaskRepository {
    func fetchTasks() throws -> [MyTask] { [] }
    func task(withID id: UUID) throws -> MyTask? { nil }
    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {}
    func deleteTask(withID id: UUID) throws {}
}

@MainActor
private struct NoopProjectItemRepository: ProjectItemRepository {
    func fetchProjectItems(includeArchived: Bool) throws -> [ProjectItem] { [] }
    func fetchProjectItems(for projectID: UUID, includeArchived: Bool) throws -> [ProjectItem] { [] }
    func projectItem(withID id: UUID) throws -> ProjectItem? { nil }
    func saveProjectItem(_ item: ProjectItem, replacingProjectItemWithID originalID: UUID?) throws {}
    func archiveProjectItem(withID id: UUID, archivedAt: Date) throws {}
    func deleteProjectItem(withID id: UUID) throws {}
}

@MainActor
private struct NoopShoppingRepository: ShoppingRepository {
    func fetchShoppingItems(includeHistory: Bool) throws -> [ShoppingItem] { [] }
    func fetchActiveShoppingItems() throws -> [ShoppingItem] { [] }
    func fetchShoppingHistory() throws -> [ShoppingItem] { [] }
    func shoppingItem(withID id: UUID) throws -> ShoppingItem? { nil }
    func saveShoppingItem(_ item: ShoppingItem, replacingItemWithID originalID: UUID?) throws {}
    func updateShoppingItemStatus(withID id: UUID, status: ShoppingItemStatus, at date: Date) throws {}
    func deleteShoppingItem(withID id: UUID) throws {}
}

@MainActor
private struct NoopMusicPracticeRepository: MusicPracticeRepository {
    func fetchPracticePieces(includeArchived: Bool) throws -> [PracticePiece] { [] }
    func practicePiece(withID id: UUID) throws -> PracticePiece? { nil }
    func savePracticePiece(_ piece: PracticePiece, replacingPieceWithID originalID: UUID?) throws {}
    func fetchPracticeSessions(limit: Int) throws -> [PracticeSession] { [] }
    func fetchPracticeSessions(from startDate: Date, to endDate: Date) throws -> [PracticeSession] { [] }
    func practiceSession(withID id: UUID) throws -> PracticeSession? { nil }
    func savePracticeSession(_ session: PracticeSession, replacingSessionWithID originalID: UUID?) throws {}
    func deletePracticeSession(withID id: UUID) throws {}
}

@MainActor
private struct NoopPeopleMemoryRepository: PeopleMemoryRepository {
    func fetchPeople() throws -> [PersonMemory] { [] }
    func person(withID id: UUID) throws -> PersonMemory? { nil }
    func savePerson(_ person: PersonMemory, replacingPersonWithID originalID: UUID?) throws {}
    func deletePerson(withID id: UUID) throws {}
    func fetchTags() throws -> [PersonTag] { [] }
    func tag(withID id: UUID) throws -> PersonTag? { nil }
    func tag(withNormalizedKey normalizedKey: String) throws -> PersonTag? { nil }
    func saveTag(_ tag: PersonTag, replacingTagWithID originalID: UUID?) throws {}
    func deleteTag(withID id: UUID) throws {}
}
