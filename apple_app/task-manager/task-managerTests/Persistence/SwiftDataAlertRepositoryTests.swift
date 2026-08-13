import Foundation
import SwiftData
import Testing
@testable import task_manager

struct SwiftDataAlertRepositoryTests {
    @Test @MainActor func alertRepositoryRoundTripsAlertTemplate() throws {
        let repository = try makeRepository()
        let template = makeTemplate()

        try repository.saveTemplate(template, replacingTemplateWithID: nil)

        #expect(try repository.template(withID: template.id) == template)
    }

    @Test @MainActor func alertRepositoryUpdatesTemplateInPlace() throws {
        let repository = try makeRepository()
        let original = makeTemplate()
        let originalRoutineID = try #require(original.routineID)
        let edited = AlertTemplate(
            id: original.id,
            title: "Night Banner",
            target: .openRoutine(originalRoutineID),
            trigger: .fixedTime(AlertFixedTimeTrigger(hour: 21, minute: 0)),
            urgency: .timeSensitive,
            privacyMode: .titleOnly,
            isEnabled: false,
            snoozeMinutes: 10,
            maxSnoozes: 1,
            createdAt: original.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveTemplate(original, replacingTemplateWithID: nil)
        try repository.saveTemplate(edited, replacingTemplateWithID: original.id)

        #expect(try repository.template(withID: original.id) == edited)
    }

    @Test @MainActor func alertRepositoryDeletesTemplate() throws {
        let repository = try makeRepository()
        let template = makeTemplate()

        try repository.saveTemplate(template, replacingTemplateWithID: nil)
        try repository.deleteTemplate(withID: template.id)

        #expect(try repository.template(withID: template.id) == nil)
        #expect(try repository.fetchTemplates().isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataAlertRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataAlertRepository(modelContainer: container)
    }

    private func makeTemplate() -> AlertTemplate {
        let routineID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174200")!
        return AlertTemplate(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174201")!,
            title: "Morning Banner",
            target: .openRoutine(routineID),
            trigger: .fixedTime(AlertFixedTimeTrigger(hour: 7, minute: 30)),
            urgency: .normal,
            privacyMode: .full,
            isEnabled: true,
            snoozeMinutes: 15,
            maxSnoozes: 2,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }
}
