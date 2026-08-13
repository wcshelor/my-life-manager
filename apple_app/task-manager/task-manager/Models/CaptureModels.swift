import Foundation

nonisolated enum CaptureModuleID: String, CaseIterable, Codable, Hashable, Sendable {
    case tasks
    case shopping
    case musicPractice
    case peopleMemory

    var displayName: String {
        switch self {
        case .tasks:
            return "Tasks"
        case .shopping:
            return "Shopping"
        case .musicPractice:
            return "Music Practice"
        case .peopleMemory:
            return "People"
        }
    }
}

nonisolated enum CaptureReviewPresentationPreference: String, CaseIterable, Codable, Sendable {
    case tiles
    case tabs
}

nonisolated enum CaptureReviewAction: String, CaseIterable, Codable, Sendable {
    case created
    case routed
    case skipped
    case processed
    case archived
    case revisited
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

nonisolated struct CaptureDestination: Identifiable, Equatable, Hashable, Codable, Sendable {
    let moduleID: CaptureModuleID
    let kind: String

    var id: String {
        "\(moduleID.rawValue)-\(kind)"
    }
}

nonisolated enum CaptureFieldKind: String, CaseIterable, Codable, Sendable {
    case singleLineText
    case multiLineText
    case picker
    case projectPicker
    case toggle
    case date
    case tags
}

nonisolated enum CaptureFieldKey: String, CaseIterable, Codable, Hashable, Sendable {
    case title
    case notes
    case projectID
    case taskEstimatedMinutes
    case taskHasDueDate
    case taskDueDate
    case taskPriority
    case taskEnergyLevel
    case taskWorkMode
    case taskGroup
    case taskTags
    case projectItemPressure
    case projectItemHasReviewAfter
    case projectItemReviewAfter
    case shoppingCategory
    case shoppingStoreType
    case shoppingStoreName
    case shoppingUrgency
    case shoppingNecessity
    case practiceComposer
    case practiceCatalogOrOpus
    case practiceInstrument
    case practiceStatus
    case personName
    case personPronunciation
    case personWhereMet
    case personHasMetAt
    case personMetAt
    case personContext
    case personRecognitionCues
    case personConversationHooks
    case personTags
}

nonisolated struct CaptureFieldOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
}

nonisolated struct CaptureFieldDefinition: Identifiable, Equatable, Sendable {
    let key: CaptureFieldKey
    let title: String
    let kind: CaptureFieldKind
    let isRequired: Bool
    let isVisibleByDefault: Bool
    let helperText: String?
    let options: [CaptureFieldOption]

    var id: CaptureFieldKey { key }

    init(
        key: CaptureFieldKey,
        title: String,
        kind: CaptureFieldKind,
        isRequired: Bool = false,
        isVisibleByDefault: Bool = true,
        helperText: String? = nil,
        options: [CaptureFieldOption] = []
    ) {
        self.key = key
        self.title = title
        self.kind = kind
        self.isRequired = isRequired
        self.isVisibleByDefault = isVisibleByDefault
        self.helperText = helperText
        self.options = options
    }
}

nonisolated struct CaptureTemplateFieldPreset: Equatable, Sendable {
    let key: CaptureFieldKey
    let value: String
}

nonisolated struct CaptureTemplateDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let presets: [CaptureTemplateFieldPreset]
    let editableFieldKeys: [CaptureFieldKey]

    func copied(id: String, title: String, summary: String? = nil) -> CaptureTemplateDefinition {
        CaptureTemplateDefinition(
            id: id,
            title: title,
            summary: summary ?? self.summary,
            presets: presets,
            editableFieldKeys: editableFieldKeys
        )
    }
}

nonisolated struct CaptureCustomizationOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let fieldKeys: [CaptureFieldKey]
}

nonisolated struct CaptureIntakeKindManifest: Identifiable, Equatable, Sendable {
    let id: String
    let moduleID: CaptureModuleID
    let displayName: String
    let summary: String
    let systemImage: String
    let fields: [CaptureFieldDefinition]
    let templates: [CaptureTemplateDefinition]
    let defaultTemplateID: String?
    let preferredPresentation: CaptureReviewPresentationPreference
    let customizationOptions: [CaptureCustomizationOption]
}

nonisolated struct CaptureModuleManifest: Identifiable, Equatable, Sendable {
    let moduleID: CaptureModuleID
    let displayName: String
    let summary: String
    let systemImage: String
    let preferredPresentation: CaptureReviewPresentationPreference

    var id: CaptureModuleID { moduleID }
}

nonisolated struct CaptureReviewDraft: Equatable, Sendable {
    var title: String
    var notes: String
    var projectID: UUID?
    var taskEstimatedMinutesText: String
    var taskHasDueDate: Bool
    var taskDueDate: Date
    var taskPriority: PriorityLevel?
    var taskEnergyLevel: EnergyLevel?
    var taskWorkMode: WorkModeKind?
    var taskGroupText: String
    var taskTagsText: String
    var projectItemPressure: ProjectItemPressure?
    var projectItemHasReviewAfter: Bool
    var projectItemReviewAfter: Date
    var shoppingCategory: String
    var shoppingStoreType: String
    var shoppingStoreName: String
    var shoppingUrgency: ShoppingUrgency
    var shoppingNecessity: ShoppingNecessity
    var practiceComposer: String
    var practiceCatalogOrOpus: String
    var practiceInstrument: String
    var practiceStatus: PracticePieceStatus
    var personName: String
    var personPronunciation: String
    var personWhereMet: String
    var personHasMetAt: Bool
    var personMetAt: Date
    var personContext: String
    var personRecognitionCues: String
    var personConversationHooks: String
    var personTagNames: [String]

    init(
        title: String = "",
        notes: String = "",
        projectID: UUID? = nil,
        taskEstimatedMinutesText: String = "",
        taskHasDueDate: Bool = false,
        taskDueDate: Date = .now,
        taskPriority: PriorityLevel? = nil,
        taskEnergyLevel: EnergyLevel? = nil,
        taskWorkMode: WorkModeKind? = nil,
        taskGroupText: String = "",
        taskTagsText: String = "",
        projectItemPressure: ProjectItemPressure? = nil,
        projectItemHasReviewAfter: Bool = false,
        projectItemReviewAfter: Date = .now,
        shoppingCategory: String = "",
        shoppingStoreType: String = "",
        shoppingStoreName: String = "",
        shoppingUrgency: ShoppingUrgency = .nextTrip,
        shoppingNecessity: ShoppingNecessity = .necessary,
        practiceComposer: String = "",
        practiceCatalogOrOpus: String = "",
        practiceInstrument: String = PracticePiece.defaultInstrument,
        practiceStatus: PracticePieceStatus = .learning,
        personName: String = "",
        personPronunciation: String = "",
        personWhereMet: String = "",
        personHasMetAt: Bool = false,
        personMetAt: Date = .now,
        personContext: String = "",
        personRecognitionCues: String = "",
        personConversationHooks: String = "",
        personTagNames: [String] = []
    ) {
        self.title = title
        self.notes = notes
        self.projectID = projectID
        self.taskEstimatedMinutesText = taskEstimatedMinutesText
        self.taskHasDueDate = taskHasDueDate
        self.taskDueDate = taskDueDate
        self.taskPriority = taskPriority
        self.taskEnergyLevel = taskEnergyLevel
        self.taskWorkMode = taskWorkMode
        self.taskGroupText = taskGroupText
        self.taskTagsText = taskTagsText
        self.projectItemPressure = projectItemPressure
        self.projectItemHasReviewAfter = projectItemHasReviewAfter
        self.projectItemReviewAfter = projectItemReviewAfter
        self.shoppingCategory = shoppingCategory
        self.shoppingStoreType = shoppingStoreType
        self.shoppingStoreName = shoppingStoreName
        self.shoppingUrgency = shoppingUrgency
        self.shoppingNecessity = shoppingNecessity
        self.practiceComposer = practiceComposer
        self.practiceCatalogOrOpus = practiceCatalogOrOpus
        self.practiceInstrument = practiceInstrument
        self.practiceStatus = practiceStatus
        self.personName = personName
        self.personPronunciation = personPronunciation
        self.personWhereMet = personWhereMet
        self.personHasMetAt = personHasMetAt
        self.personMetAt = personMetAt
        self.personContext = personContext
        self.personRecognitionCues = personRecognitionCues
        self.personConversationHooks = personConversationHooks
        self.personTagNames = personTagNames
    }

    init(capture: RawCapture) {
        self.init(
            title: capture.title,
            notes: capture.notes ?? "",
            projectID: capture.projectID,
            personName: capture.title
        )
    }

    mutating func applyTemplate(_ template: CaptureTemplateDefinition) {
        for preset in template.presets {
            applyPreset(preset)
        }
    }

    func makeTemplate(
        id: String,
        title: String,
        summary: String,
        editableFieldKeys: [CaptureFieldKey]
    ) -> CaptureTemplateDefinition {
        let presets = editableFieldKeys.compactMap { key -> CaptureTemplateFieldPreset? in
            guard let value = presetValue(for: key) else {
                return nil
            }

            return CaptureTemplateFieldPreset(key: key, value: value)
        }

        return CaptureTemplateDefinition(
            id: id,
            title: title,
            summary: summary,
            presets: presets,
            editableFieldKeys: editableFieldKeys
        )
    }

    var taskFormData: MyTaskFormData {
        MyTaskFormData(
            title: title,
            notesText: notes,
            estimatedMinutesText: taskEstimatedMinutesText,
            hasDueDate: taskHasDueDate,
            dueDate: taskDueDate,
            priority: taskPriority,
            energyLevel: taskEnergyLevel,
            workMode: taskWorkMode,
            projectID: projectID,
            taskGroupText: taskGroupText,
            tagsText: taskTagsText
        )
    }

    var shoppingFormData: ShoppingItemFormData {
        ShoppingItemFormData(
            title: title,
            notes: notes,
            category: shoppingCategory,
            storeType: shoppingStoreType,
            storeName: shoppingStoreName,
            urgency: shoppingUrgency,
            necessity: shoppingNecessity
        )
    }

    func makePracticePiece(
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date
    ) -> PracticePiece? {
        guard PracticePiece.cleanedTitle(from: title) != nil else {
            return nil
        }

        return PracticePiece(
            id: id,
            title: title,
            composer: practiceComposer,
            catalogOrOpus: practiceCatalogOrOpus,
            instrument: practiceInstrument,
            status: practiceStatus,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func makeProjectItem(
        kind: ProjectItemKind,
        createdAt: Date,
        updatedAt: Date,
        source: String?
    ) -> ProjectItem? {
        guard let projectID else {
            return nil
        }

        guard ProjectItem.cleanedTitle(from: title) != nil else {
            return nil
        }

        return ProjectItem(
            projectID: projectID,
            kind: kind,
            title: title,
            notes: notes,
            source: source,
            pressure: projectItemPressure,
            reviewAfter: projectItemHasReviewAfter ? projectItemReviewAfter : nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func makePersonMemory(
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        tagIDs: [UUID]
    ) -> PersonMemory? {
        guard PersonMemory.cleanedName(from: personName) != nil else {
            return nil
        }

        return PersonMemory(
            id: id,
            name: personName,
            pronunciationNote: personPronunciation,
            whereMet: personWhereMet,
            metAt: personHasMetAt ? personMetAt : nil,
            context: personContext,
            recognitionCues: personRecognitionCues,
            conversationHooks: personConversationHooks,
            notes: notes,
            tagIDs: tagIDs,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func normalizedPersonTagNames() -> [String] {
        var seen: Set<String> = []
        return personTagNames.compactMap { rawName in
            guard let cleanedName = PersonTag.cleanedName(from: rawName) else {
                return nil
            }

            let normalizedKey = PersonTag.normalizedKey(for: cleanedName)
            guard seen.insert(normalizedKey).inserted else {
                return nil
            }

            return cleanedName
        }
    }

    private mutating func applyPreset(_ preset: CaptureTemplateFieldPreset) {
        switch preset.key {
        case .title:
            title = preset.value
        case .notes:
            notes = preset.value
        case .projectID:
            projectID = UUID(uuidString: preset.value)
        case .taskEstimatedMinutes:
            taskEstimatedMinutesText = preset.value
        case .taskHasDueDate:
            taskHasDueDate = Self.boolValue(from: preset.value)
        case .taskDueDate:
            if let date = ISO8601DateFormatter().date(from: preset.value) {
                taskDueDate = date
            }
        case .taskPriority:
            taskPriority = PriorityLevel(rawValue: preset.value)
        case .taskEnergyLevel:
            taskEnergyLevel = EnergyLevel(rawValue: preset.value)
        case .taskWorkMode:
            taskWorkMode = WorkModeKind(rawValue: preset.value)
        case .taskGroup:
            taskGroupText = preset.value
        case .taskTags:
            taskTagsText = preset.value
        case .projectItemPressure:
            projectItemPressure = ProjectItemPressure(rawValue: preset.value)
        case .projectItemHasReviewAfter:
            projectItemHasReviewAfter = Self.boolValue(from: preset.value)
        case .projectItemReviewAfter:
            if let date = ISO8601DateFormatter().date(from: preset.value) {
                projectItemReviewAfter = date
            }
        case .shoppingCategory:
            shoppingCategory = preset.value
        case .shoppingStoreType:
            shoppingStoreType = preset.value
        case .shoppingStoreName:
            shoppingStoreName = preset.value
        case .shoppingUrgency:
            shoppingUrgency = ShoppingUrgency(rawValue: preset.value) ?? shoppingUrgency
        case .shoppingNecessity:
            shoppingNecessity = ShoppingNecessity(rawValue: preset.value) ?? shoppingNecessity
        case .practiceComposer:
            practiceComposer = preset.value
        case .practiceCatalogOrOpus:
            practiceCatalogOrOpus = preset.value
        case .practiceInstrument:
            practiceInstrument = preset.value
        case .practiceStatus:
            practiceStatus = PracticePieceStatus(rawValue: preset.value) ?? practiceStatus
        case .personName:
            personName = preset.value
        case .personPronunciation:
            personPronunciation = preset.value
        case .personWhereMet:
            personWhereMet = preset.value
        case .personHasMetAt:
            personHasMetAt = Self.boolValue(from: preset.value)
        case .personMetAt:
            if let date = ISO8601DateFormatter().date(from: preset.value) {
                personMetAt = date
            }
        case .personContext:
            personContext = preset.value
        case .personRecognitionCues:
            personRecognitionCues = preset.value
        case .personConversationHooks:
            personConversationHooks = preset.value
        case .personTags:
            personTagNames = preset.value
                .split(separator: ",")
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
        }
    }

    private func presetValue(for key: CaptureFieldKey) -> String? {
        switch key {
        case .title:
            return title
        case .notes:
            return notes
        case .projectID:
            return projectID?.uuidString
        case .taskEstimatedMinutes:
            return taskEstimatedMinutesText
        case .taskHasDueDate:
            return taskHasDueDate ? "true" : "false"
        case .taskDueDate:
            return ISO8601DateFormatter().string(from: taskDueDate)
        case .taskPriority:
            return taskPriority?.rawValue
        case .taskEnergyLevel:
            return taskEnergyLevel?.rawValue
        case .taskWorkMode:
            return taskWorkMode?.rawValue
        case .taskGroup:
            return taskGroupText
        case .taskTags:
            return taskTagsText
        case .projectItemPressure:
            return projectItemPressure?.rawValue
        case .projectItemHasReviewAfter:
            return projectItemHasReviewAfter ? "true" : "false"
        case .projectItemReviewAfter:
            return ISO8601DateFormatter().string(from: projectItemReviewAfter)
        case .shoppingCategory:
            return shoppingCategory
        case .shoppingStoreType:
            return shoppingStoreType
        case .shoppingStoreName:
            return shoppingStoreName
        case .shoppingUrgency:
            return shoppingUrgency.rawValue
        case .shoppingNecessity:
            return shoppingNecessity.rawValue
        case .practiceComposer:
            return practiceComposer
        case .practiceCatalogOrOpus:
            return practiceCatalogOrOpus
        case .practiceInstrument:
            return practiceInstrument
        case .practiceStatus:
            return practiceStatus.rawValue
        case .personName:
            return personName
        case .personPronunciation:
            return personPronunciation
        case .personWhereMet:
            return personWhereMet
        case .personHasMetAt:
            return personHasMetAt ? "true" : "false"
        case .personMetAt:
            return ISO8601DateFormatter().string(from: personMetAt)
        case .personContext:
            return personContext
        case .personRecognitionCues:
            return personRecognitionCues
        case .personConversationHooks:
            return personConversationHooks
        case .personTags:
            return personTagNames.joined(separator: ", ")
        }
    }

    private static func boolValue(from value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "y", "on":
            return true
        default:
            return false
        }
    }
}

nonisolated struct CaptureReviewKindOption: Identifiable, Equatable, Sendable {
    let destination: CaptureDestination
    let moduleManifest: CaptureModuleManifest
    let kindManifest: CaptureIntakeKindManifest
    let initialDraft: CaptureReviewDraft

    var id: String { destination.id }
}

nonisolated struct CaptureReviewModuleOption: Identifiable, Equatable, Sendable {
    let manifest: CaptureModuleManifest
    let kinds: [CaptureReviewKindOption]

    var id: CaptureModuleID { manifest.moduleID }
}

nonisolated struct CaptureProcessingResult: Equatable, Sendable {
    let destination: CaptureDestination
    let resolvedRecordType: String
    let resolvedRecordID: UUID?
}
