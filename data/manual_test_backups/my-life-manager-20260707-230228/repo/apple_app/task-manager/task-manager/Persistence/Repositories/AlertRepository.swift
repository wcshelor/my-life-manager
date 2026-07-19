import Foundation

@MainActor
protocol AlertRepository {
    func fetchTemplates() throws -> [AlertTemplate]
    func template(withID id: UUID) throws -> AlertTemplate?
    func saveTemplate(_ template: AlertTemplate, replacingTemplateWithID originalID: UUID?) throws
    func deleteTemplate(withID id: UUID) throws
}
