import Foundation
import SwiftData

@MainActor
final class SwiftDataAlertRepository: AlertRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchTemplates() throws -> [AlertTemplate] {
        try fetchAllRecords()
            .map(\.template)
            .sorted { left, right in
                if left.createdAt != right.createdAt {
                    return left.createdAt < right.createdAt
                }

                return left.id.uuidString < right.id.uuidString
            }
    }

    func template(withID id: UUID) throws -> AlertTemplate? {
        try fetchRecord(withID: id)?.template
    }

    func saveTemplate(_ template: AlertTemplate, replacingTemplateWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? template.id)
            ?? fetchRecord(withID: template.id)

        if let record {
            record.update(from: template)
        } else {
            modelContext.insert(AlertTemplateRecord(template: template))
        }

        try modelContext.save()
    }

    func deleteTemplate(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [AlertTemplateRecord] {
        try modelContext.fetch(FetchDescriptor<AlertTemplateRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> AlertTemplateRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}
