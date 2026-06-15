import Foundation

nonisolated enum CaptureModuleID: String, CaseIterable, Codable, Hashable, Sendable {
    case tasks
    case shopping
    case musicPractice

    var displayName: String {
        switch self {
        case .tasks:
            return "Tasks"
        case .shopping:
            return "Shopping"
        case .musicPractice:
            return "Music Practice"
        }
    }
}

nonisolated struct RawCapture: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var projectID: UUID?
    var source: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        projectID: UUID? = nil,
        source: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.projectID = projectID
        self.source = source
        self.createdAt = createdAt
    }

    init(capture: CaptureItem) {
        self.init(
            id: capture.id,
            title: capture.title,
            notes: capture.notes,
            projectID: capture.projectID,
            source: capture.source,
            createdAt: capture.createdAt
        )
    }
}

nonisolated struct CaptureDestination: Identifiable, Equatable, Hashable, Sendable {
    let moduleID: CaptureModuleID
    let kind: String

    var id: String {
        "\(moduleID.rawValue)-\(kind)"
    }
}

nonisolated struct CaptureCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let rawCaptureID: UUID
    let moduleID: CaptureModuleID
    let destination: CaptureDestination
    let title: String
    let subtitle: String
    let primaryActionTitle: String
    let taskFormData: MyTaskFormData?
    let shoppingFormData: ShoppingItemFormData?
    let practicePiece: PracticePiece?
}

nonisolated struct CaptureCandidateGroup: Identifiable, Equatable, Sendable {
    let id: CaptureModuleID
    let title: String
    let candidates: [CaptureCandidate]
}

