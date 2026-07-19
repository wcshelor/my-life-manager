import Foundation

nonisolated protocol CaptureCapabilityProviding: Sendable {
    var moduleID: CaptureModuleID { get }
    var displayName: String { get }

    func captureCandidates(for capture: RawCapture) -> [CaptureCandidate]
}

nonisolated struct CaptureCapabilityRegistry: Sendable {
    let providers: [any CaptureCapabilityProviding]

    init(providers: [any CaptureCapabilityProviding]) {
        self.providers = providers
    }

    static var standard: CaptureCapabilityRegistry {
        CaptureCapabilityRegistry(providers: [
            TaskCaptureCapability(),
            ShoppingCaptureCapability(),
            MusicPracticeCaptureCapability(),
        ])
    }

    func captureCandidateGroups(for capture: RawCapture) -> [CaptureCandidateGroup] {
        providers.compactMap { provider in
            let candidates = provider.captureCandidates(for: capture)
            guard candidates.isEmpty == false else {
                return nil
            }

            return CaptureCandidateGroup(
                id: provider.moduleID,
                title: provider.displayName,
                candidates: candidates
            )
        }
    }
}

nonisolated struct TaskCaptureCapability: CaptureCapabilityProviding {
    let moduleID: CaptureModuleID = .tasks
    let displayName = CaptureModuleID.tasks.displayName

    func captureCandidates(for capture: RawCapture) -> [CaptureCandidate] {
        guard MyTask.cleanedTitle(from: capture.title) != nil else {
            return []
        }

        let formData = MyTaskFormData(
            title: capture.title,
            notesText: capture.notes ?? "",
            projectID: capture.projectID
        )

        return [
            CaptureCandidate(
                id: capture.id,
                rawCaptureID: capture.id,
                moduleID: moduleID,
                destination: CaptureDestination(moduleID: moduleID, kind: "task"),
                title: capture.title,
                subtitle: capture.notes ?? "Task",
                primaryActionTitle: "Review Task",
                taskFormData: formData,
                shoppingFormData: nil,
                practicePiece: nil
            )
        ]
    }
}

nonisolated struct ShoppingCaptureCapability: CaptureCapabilityProviding {
    let moduleID: CaptureModuleID = .shopping
    let displayName = CaptureModuleID.shopping.displayName

    func captureCandidates(for capture: RawCapture) -> [CaptureCandidate] {
        guard ShoppingItem.cleanedTitle(from: capture.title) != nil else {
            return []
        }

        let formData = ShoppingItemFormData(
            title: capture.title,
            notes: capture.notes ?? ""
        )

        return [
            CaptureCandidate(
                id: capture.id,
                rawCaptureID: capture.id,
                moduleID: moduleID,
                destination: CaptureDestination(moduleID: moduleID, kind: "shopping-item"),
                title: capture.title,
                subtitle: capture.notes ?? "Shopping item",
                primaryActionTitle: "Save Shopping Item",
                taskFormData: nil,
                shoppingFormData: formData,
                practicePiece: nil
            )
        ]
    }
}

nonisolated struct MusicPracticeCaptureCapability: CaptureCapabilityProviding {
    let moduleID: CaptureModuleID = .musicPractice
    let displayName = CaptureModuleID.musicPractice.displayName

    func captureCandidates(for capture: RawCapture) -> [CaptureCandidate] {
        guard PracticePiece.cleanedTitle(from: capture.title) != nil else {
            return []
        }

        let piece = PracticePiece(
            title: capture.title,
            notes: capture.notes
        )

        return [
            CaptureCandidate(
                id: capture.id,
                rawCaptureID: capture.id,
                moduleID: moduleID,
                destination: CaptureDestination(moduleID: moduleID, kind: "practice-piece"),
                title: capture.title,
                subtitle: capture.notes ?? "Music practice piece",
                primaryActionTitle: "Save Practice Piece",
                taskFormData: nil,
                shoppingFormData: nil,
                practicePiece: piece
            )
        ]
    }
}

