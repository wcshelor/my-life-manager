import Foundation

@MainActor
protocol CaptureIntakeKindProviding {
    var moduleManifest: CaptureModuleManifest { get }
    var kindManifest: CaptureIntakeKindManifest { get }

    func draft(for capture: RawCapture) -> CaptureReviewDraft?
    func validationMessage(for draft: CaptureReviewDraft) -> String?
    func persist(
        draft: CaptureReviewDraft,
        from capture: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult
}

@MainActor
struct CaptureIntakeRegistry {
    let providers: [any CaptureIntakeKindProviding]

    init(providers: [any CaptureIntakeKindProviding]) {
        self.providers = providers
    }

    static func standard(
        taskRepository: any TaskRepository,
        projectItemRepository: any ProjectItemRepository,
        shoppingRepository: any ShoppingRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        peopleMemoryRepository: any PeopleMemoryRepository
    ) -> CaptureIntakeRegistry {
        let taskModuleManifest = CaptureModuleManifest(
            moduleID: .tasks,
            displayName: CaptureModuleID.tasks.displayName,
            summary: "Turn a sticky note into a task or a project-owned backlog item.",
            systemImage: "checklist",
            preferredPresentation: .tabs
        )
        let shoppingModuleManifest = CaptureModuleManifest(
            moduleID: .shopping,
            displayName: CaptureModuleID.shopping.displayName,
            summary: "Send it to the shopping list with trip-ready details.",
            systemImage: "cart.fill",
            preferredPresentation: .tabs
        )
        let musicModuleManifest = CaptureModuleManifest(
            moduleID: .musicPractice,
            displayName: CaptureModuleID.musicPractice.displayName,
            summary: "Save it as a practice piece with the right status and notes.",
            systemImage: "music.note.list",
            preferredPresentation: .tabs
        )
        let peopleModuleManifest = CaptureModuleManifest(
            moduleID: .peopleMemory,
            displayName: CaptureModuleID.peopleMemory.displayName,
            summary: "Save a person quickly, then add the memory cues that matter.",
            systemImage: "person.crop.rectangle.stack.fill",
            preferredPresentation: .tabs
        )

        return CaptureIntakeRegistry(providers: [
            TaskCaptureKindProvider(
                taskRepository: taskRepository,
                moduleManifest: taskModuleManifest
            ),
            ProjectIdeaCaptureKindProvider(
                projectItemRepository: projectItemRepository,
                moduleManifest: taskModuleManifest
            ),
            ProjectNoteCaptureKindProvider(
                projectItemRepository: projectItemRepository,
                moduleManifest: taskModuleManifest
            ),
            ShoppingCaptureKindProvider(
                shoppingRepository: shoppingRepository,
                moduleManifest: shoppingModuleManifest
            ),
            MusicPracticeCaptureKindProvider(
                musicPracticeRepository: musicPracticeRepository,
                moduleManifest: musicModuleManifest
            ),
            PeopleMemoryCaptureKindProvider(
                peopleMemoryRepository: peopleMemoryRepository,
                moduleManifest: peopleModuleManifest
            ),
        ])
    }

    func moduleOptions(for capture: RawCapture) -> [CaptureReviewModuleOption] {
        var orderedModules: [CaptureModuleManifest] = []
        var kindsByModule: [CaptureModuleID: [CaptureReviewKindOption]] = [:]

        for provider in providers {
            guard let draft = provider.draft(for: capture) else {
                continue
            }

            if kindsByModule[provider.moduleManifest.moduleID] == nil {
                orderedModules.append(provider.moduleManifest)
            }

            let destination = CaptureDestination(
                moduleID: provider.moduleManifest.moduleID,
                kind: provider.kindManifest.id
            )
            kindsByModule[provider.moduleManifest.moduleID, default: []].append(
                CaptureReviewKindOption(
                    destination: destination,
                    moduleManifest: provider.moduleManifest,
                    kindManifest: provider.kindManifest,
                    initialDraft: draft
                )
            )
        }

        return orderedModules.compactMap { moduleManifest in
            guard let kinds = kindsByModule[moduleManifest.moduleID], kinds.isEmpty == false else {
                return nil
            }

            return CaptureReviewModuleOption(manifest: moduleManifest, kinds: kinds)
        }
    }

    func provider(for destination: CaptureDestination) -> (any CaptureIntakeKindProviding)? {
        providers.first {
            $0.moduleManifest.moduleID == destination.moduleID
                && $0.kindManifest.id == destination.kind
        }
    }
}

@MainActor
private struct TaskCaptureKindProvider: CaptureIntakeKindProviding {
    let taskRepository: any TaskRepository
    let moduleManifest: CaptureModuleManifest

    let kindManifest = CaptureIntakeKindManifest(
        id: "task",
        moduleID: .tasks,
        displayName: "Task",
        summary: "Use this when the note is a concrete next action.",
        systemImage: "checkmark.circle",
        fields: [
            CaptureFieldDefinition(key: .title, title: "Task", kind: .singleLineText, isRequired: true),
            CaptureFieldDefinition(key: .notes, title: "Notes", kind: .multiLineText),
            CaptureFieldDefinition(key: .projectID, title: "Project", kind: .projectPicker),
            CaptureFieldDefinition(
                key: .taskEstimatedMinutes,
                title: "Estimated Minutes",
                kind: .singleLineText,
                isVisibleByDefault: false,
                helperText: "Use 15-minute steps when you know the rough size."
            ),
            CaptureFieldDefinition(key: .taskHasDueDate, title: "Add Due Date", kind: .toggle, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .taskDueDate, title: "Due Date", kind: .date, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .taskPriority, title: "Priority", kind: .picker, isVisibleByDefault: false, options: priorityOptions),
            CaptureFieldDefinition(key: .taskEnergyLevel, title: "Energy", kind: .picker, isVisibleByDefault: false, options: energyOptions),
            CaptureFieldDefinition(key: .taskWorkMode, title: "Work Mode", kind: .picker, isVisibleByDefault: false, options: workModeOptions),
            CaptureFieldDefinition(key: .taskGroup, title: "Task Group", kind: .singleLineText, isVisibleByDefault: false),
            CaptureFieldDefinition(
                key: .taskTags,
                title: "Tags",
                kind: .singleLineText,
                isVisibleByDefault: false,
                helperText: "Comma-separated"
            ),
        ],
        templates: [
            CaptureTemplateDefinition(
                id: "follow_up",
                title: "Follow Up",
                summary: "Good for outreach, replies, and admin loops.",
                presets: [
                    CaptureTemplateFieldPreset(key: .taskPriority, value: PriorityLevel.medium.rawValue),
                    CaptureTemplateFieldPreset(key: .taskWorkMode, value: WorkModeKind.shallowAdmin.rawValue),
                    CaptureTemplateFieldPreset(key: .taskGroup, value: "Follow Up"),
                ],
                editableFieldKeys: [.title, .notes, .taskPriority, .taskWorkMode, .taskGroup]
            ),
            CaptureTemplateDefinition(
                id: "errand",
                title: "Errand",
                summary: "Useful for practical out-of-the-house tasks.",
                presets: [
                    CaptureTemplateFieldPreset(key: .taskWorkMode, value: WorkModeKind.errand.rawValue),
                    CaptureTemplateFieldPreset(key: .taskGroup, value: "Errands"),
                ],
                editableFieldKeys: [.title, .notes, .projectID, .taskWorkMode, .taskGroup]
            ),
            CaptureTemplateDefinition(
                id: "deep_work",
                title: "Deep Work",
                summary: "Use when the note should become focused work later.",
                presets: [
                    CaptureTemplateFieldPreset(key: .taskEstimatedMinutes, value: "60"),
                    CaptureTemplateFieldPreset(key: .taskPriority, value: PriorityLevel.high.rawValue),
                    CaptureTemplateFieldPreset(key: .taskWorkMode, value: WorkModeKind.deepWork.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .taskEstimatedMinutes, .taskPriority, .taskWorkMode]
            ),
        ],
        defaultTemplateID: "follow_up",
        preferredPresentation: .tabs,
        customizationOptions: [
            CaptureCustomizationOption(
                id: "task_scheduling",
                title: "Scheduling",
                fieldKeys: [.taskEstimatedMinutes, .taskHasDueDate, .taskDueDate, .taskPriority, .taskEnergyLevel, .taskWorkMode]
            ),
            CaptureCustomizationOption(
                id: "task_organization",
                title: "Organization",
                fieldKeys: [.projectID, .taskGroup, .taskTags]
            ),
        ]
    )

    func draft(for capture: RawCapture) -> CaptureReviewDraft? {
        guard MyTask.cleanedTitle(from: capture.title) != nil else {
            return nil
        }

        return CaptureReviewDraft(capture: capture)
    }

    func validationMessage(for draft: CaptureReviewDraft) -> String? {
        draft.taskFormData.validationMessage(reservedTaskIDs: [])
    }

    func persist(
        draft: CaptureReviewDraft,
        from capture: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult {
        guard let task = draft.taskFormData.makeTask(savedAt: date) else {
            throw CapturePersistenceError.validation("Enter a task title.")
        }

        try taskRepository.saveTask(task, replacingTaskWithID: nil)
        return CaptureProcessingResult(
            destination: CaptureDestination(moduleID: .tasks, kind: kindManifest.id),
            resolvedRecordType: "task",
            resolvedRecordID: task.id
        )
    }
}

@MainActor
private struct ProjectIdeaCaptureKindProvider: CaptureIntakeKindProviding {
    let projectItemRepository: any ProjectItemRepository
    let moduleManifest: CaptureModuleManifest

    let kindManifest = CaptureIntakeKindManifest(
        id: "project-maybe",
        moduleID: .tasks,
        displayName: "Project Idea",
        summary: "Keep it with a project when it is not a task yet.",
        systemImage: "lightbulb.fill",
        fields: [
            CaptureFieldDefinition(key: .title, title: "Idea", kind: .singleLineText, isRequired: true),
            CaptureFieldDefinition(key: .notes, title: "Notes", kind: .multiLineText),
            CaptureFieldDefinition(key: .projectID, title: "Project", kind: .projectPicker, isRequired: true),
            CaptureFieldDefinition(key: .projectItemPressure, title: "Pressure", kind: .picker, options: projectPressureOptions),
            CaptureFieldDefinition(key: .projectItemHasReviewAfter, title: "Review Later", kind: .toggle, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .projectItemReviewAfter, title: "Review After", kind: .date, isVisibleByDefault: false),
        ],
        templates: [
            CaptureTemplateDefinition(
                id: "hold",
                title: "Hold For Later",
                summary: "Use for maybes that need a quieter parking spot.",
                presets: [
                    CaptureTemplateFieldPreset(key: .projectItemPressure, value: ProjectItemPressure.shouldDoSometime.rawValue),
                    CaptureTemplateFieldPreset(key: .projectItemHasReviewAfter, value: "true"),
                ],
                editableFieldKeys: [.title, .notes, .projectID, .projectItemPressure, .projectItemReviewAfter]
            ),
            CaptureTemplateDefinition(
                id: "useful",
                title: "Useful Lead",
                summary: "Good for research leads and options worth checking.",
                presets: [
                    CaptureTemplateFieldPreset(key: .projectItemPressure, value: ProjectItemPressure.useful.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .projectID, .projectItemPressure]
            ),
        ],
        defaultTemplateID: "useful",
        preferredPresentation: .tabs,
        customizationOptions: [
            CaptureCustomizationOption(
                id: "project_review",
                title: "Review Timing",
                fieldKeys: [.projectItemHasReviewAfter, .projectItemReviewAfter]
            ),
        ]
    )

    func draft(for capture: RawCapture) -> CaptureReviewDraft? {
        CaptureReviewDraft(capture: capture)
    }

    func validationMessage(for draft: CaptureReviewDraft) -> String? {
        guard ProjectItem.cleanedTitle(from: draft.title) != nil else {
            return "Enter an idea title."
        }

        guard draft.projectID != nil else {
            return "Choose a project."
        }

        return nil
    }

    func persist(
        draft: CaptureReviewDraft,
        from capture: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult {
        guard let item = draft.makeProjectItem(
            kind: .maybe,
            createdAt: date,
            updatedAt: date,
            source: capture.source
        ) else {
            throw CapturePersistenceError.validation("Choose a project and idea title.")
        }

        try projectItemRepository.saveProjectItem(item, replacingProjectItemWithID: nil)
        return CaptureProcessingResult(
            destination: CaptureDestination(moduleID: .tasks, kind: kindManifest.id),
            resolvedRecordType: "projectItem",
            resolvedRecordID: item.id
        )
    }
}

@MainActor
private struct ProjectNoteCaptureKindProvider: CaptureIntakeKindProviding {
    let projectItemRepository: any ProjectItemRepository
    let moduleManifest: CaptureModuleManifest

    let kindManifest = CaptureIntakeKindManifest(
        id: "project-note",
        moduleID: .tasks,
        displayName: "Project Note",
        summary: "Save it as context instead of an action item.",
        systemImage: "note.text",
        fields: [
            CaptureFieldDefinition(key: .title, title: "Note", kind: .singleLineText, isRequired: true),
            CaptureFieldDefinition(key: .notes, title: "Detail", kind: .multiLineText),
            CaptureFieldDefinition(key: .projectID, title: "Project", kind: .projectPicker, isRequired: true),
        ],
        templates: [
            CaptureTemplateDefinition(
                id: "meeting_note",
                title: "Meeting Note",
                summary: "A lightweight note worth keeping with the project.",
                presets: [],
                editableFieldKeys: [.title, .notes, .projectID]
            )
        ],
        defaultTemplateID: "meeting_note",
        preferredPresentation: .tabs,
        customizationOptions: []
    )

    func draft(for capture: RawCapture) -> CaptureReviewDraft? {
        CaptureReviewDraft(capture: capture)
    }

    func validationMessage(for draft: CaptureReviewDraft) -> String? {
        guard ProjectItem.cleanedTitle(from: draft.title) != nil else {
            return "Enter a note title."
        }

        guard draft.projectID != nil else {
            return "Choose a project."
        }

        return nil
    }

    func persist(
        draft: CaptureReviewDraft,
        from capture: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult {
        guard let item = draft.makeProjectItem(
            kind: .note,
            createdAt: date,
            updatedAt: date,
            source: capture.source
        ) else {
            throw CapturePersistenceError.validation("Choose a project and note title.")
        }

        try projectItemRepository.saveProjectItem(item, replacingProjectItemWithID: nil)
        return CaptureProcessingResult(
            destination: CaptureDestination(moduleID: .tasks, kind: kindManifest.id),
            resolvedRecordType: "projectItem",
            resolvedRecordID: item.id
        )
    }
}

@MainActor
private struct ShoppingCaptureKindProvider: CaptureIntakeKindProviding {
    let shoppingRepository: any ShoppingRepository
    let moduleManifest: CaptureModuleManifest

    let kindManifest = CaptureIntakeKindManifest(
        id: "shopping-item",
        moduleID: .shopping,
        displayName: "Shopping Item",
        summary: "Turn the note into a practical shopping item.",
        systemImage: "cart.badge.plus",
        fields: [
            CaptureFieldDefinition(key: .title, title: "Item", kind: .singleLineText, isRequired: true),
            CaptureFieldDefinition(key: .notes, title: "Notes", kind: .multiLineText),
            CaptureFieldDefinition(key: .shoppingCategory, title: "Category", kind: .singleLineText, options: shoppingCategoryOptions),
            CaptureFieldDefinition(key: .shoppingUrgency, title: "Urgency", kind: .picker, options: shoppingUrgencyOptions),
            CaptureFieldDefinition(key: .shoppingNecessity, title: "Necessity", kind: .picker, options: shoppingNecessityOptions),
            CaptureFieldDefinition(key: .shoppingStoreType, title: "Store Type", kind: .singleLineText, isVisibleByDefault: false, options: shoppingStoreTypeOptions),
            CaptureFieldDefinition(key: .shoppingStoreName, title: "Store Name", kind: .singleLineText, isVisibleByDefault: false, options: shoppingStoreNameOptions),
        ],
        templates: [
            CaptureTemplateDefinition(
                id: "groceries",
                title: "Groceries",
                summary: "Useful for regular food shopping.",
                presets: [
                    CaptureTemplateFieldPreset(key: .shoppingCategory, value: "Groceries"),
                    CaptureTemplateFieldPreset(key: .shoppingStoreType, value: "Grocery"),
                    CaptureTemplateFieldPreset(key: .shoppingUrgency, value: ShoppingUrgency.needSoon.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .shoppingCategory, .shoppingStoreType, .shoppingUrgency]
            ),
            CaptureTemplateDefinition(
                id: "household",
                title: "Household",
                summary: "For home supplies and practical restocks.",
                presets: [
                    CaptureTemplateFieldPreset(key: .shoppingCategory, value: "Household"),
                    CaptureTemplateFieldPreset(key: .shoppingNecessity, value: ShoppingNecessity.necessary.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .shoppingCategory, .shoppingNecessity]
            ),
            CaptureTemplateDefinition(
                id: "online",
                title: "Online",
                summary: "Use when it should sit on the list until an online order.",
                presets: [
                    CaptureTemplateFieldPreset(key: .shoppingStoreType, value: "Online"),
                    CaptureTemplateFieldPreset(key: .shoppingUrgency, value: ShoppingUrgency.someday.rawValue),
                    CaptureTemplateFieldPreset(key: .shoppingNecessity, value: ShoppingNecessity.optional.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .shoppingStoreType, .shoppingUrgency, .shoppingNecessity]
            ),
        ],
        defaultTemplateID: "groceries",
        preferredPresentation: .tabs,
        customizationOptions: [
            CaptureCustomizationOption(
                id: "shopping_store_details",
                title: "Store Details",
                fieldKeys: [.shoppingStoreType, .shoppingStoreName]
            ),
        ]
    )

    func draft(for capture: RawCapture) -> CaptureReviewDraft? {
        guard ShoppingItem.cleanedTitle(from: capture.title) != nil else {
            return nil
        }

        return CaptureReviewDraft(capture: capture)
    }

    func validationMessage(for draft: CaptureReviewDraft) -> String? {
        draft.shoppingFormData.makeItem(createdAt: .now, updatedAt: .now) == nil
            ? "Enter a shopping item title."
            : nil
    }

    func persist(
        draft: CaptureReviewDraft,
        from _: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult {
        guard let item = draft.shoppingFormData.makeItem(createdAt: date, updatedAt: date) else {
            throw CapturePersistenceError.validation("Enter a shopping item title.")
        }

        try shoppingRepository.saveShoppingItem(item, replacingItemWithID: nil)
        return CaptureProcessingResult(
            destination: CaptureDestination(moduleID: .shopping, kind: kindManifest.id),
            resolvedRecordType: "shoppingItem",
            resolvedRecordID: item.id
        )
    }
}

@MainActor
private struct MusicPracticeCaptureKindProvider: CaptureIntakeKindProviding {
    let musicPracticeRepository: any MusicPracticeRepository
    let moduleManifest: CaptureModuleManifest

    let kindManifest = CaptureIntakeKindManifest(
        id: "practice-piece",
        moduleID: .musicPractice,
        displayName: "Practice Piece",
        summary: "Save it into the piece list with the right practice defaults.",
        systemImage: "music.note",
        fields: [
            CaptureFieldDefinition(key: .title, title: "Piece", kind: .singleLineText, isRequired: true),
            CaptureFieldDefinition(key: .notes, title: "Notes", kind: .multiLineText),
            CaptureFieldDefinition(key: .practiceComposer, title: "Composer / Artist", kind: .singleLineText),
            CaptureFieldDefinition(key: .practiceCatalogOrOpus, title: "Catalog / Opus", kind: .singleLineText, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .practiceInstrument, title: "Instrument", kind: .singleLineText),
            CaptureFieldDefinition(key: .practiceStatus, title: "Status", kind: .picker, options: practiceStatusOptions),
        ],
        templates: [
            CaptureTemplateDefinition(
                id: "learning",
                title: "Learning",
                summary: "For brand-new or active repertoire.",
                presets: [
                    CaptureTemplateFieldPreset(key: .practiceStatus, value: PracticePieceStatus.learning.rawValue),
                    CaptureTemplateFieldPreset(key: .practiceInstrument, value: PracticePiece.defaultInstrument),
                ],
                editableFieldKeys: [.title, .notes, .practiceComposer, .practiceInstrument, .practiceStatus]
            ),
            CaptureTemplateDefinition(
                id: "maintenance",
                title: "Maintenance",
                summary: "Use when it belongs in the keep-it-fresh bucket.",
                presets: [
                    CaptureTemplateFieldPreset(key: .practiceStatus, value: PracticePieceStatus.maintaining.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .practiceComposer, .practiceStatus]
            ),
            CaptureTemplateDefinition(
                id: "polish",
                title: "Polish",
                summary: "For pieces that are close and need refinement.",
                presets: [
                    CaptureTemplateFieldPreset(key: .practiceStatus, value: PracticePieceStatus.polishing.rawValue),
                ],
                editableFieldKeys: [.title, .notes, .practiceComposer, .practiceStatus]
            ),
        ],
        defaultTemplateID: "learning",
        preferredPresentation: .tabs,
        customizationOptions: [
            CaptureCustomizationOption(
                id: "practice_catalog",
                title: "Catalog Details",
                fieldKeys: [.practiceCatalogOrOpus]
            )
        ]
    )

    func draft(for capture: RawCapture) -> CaptureReviewDraft? {
        guard PracticePiece.cleanedTitle(from: capture.title) != nil else {
            return nil
        }

        return CaptureReviewDraft(capture: capture)
    }

    func validationMessage(for draft: CaptureReviewDraft) -> String? {
        draft.makePracticePiece(createdAt: .now, updatedAt: .now) == nil
            ? "Enter a piece title."
            : nil
    }

    func persist(
        draft: CaptureReviewDraft,
        from _: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult {
        guard let piece = draft.makePracticePiece(createdAt: date, updatedAt: date) else {
            throw CapturePersistenceError.validation("Enter a piece title.")
        }

        try musicPracticeRepository.savePracticePiece(piece, replacingPieceWithID: nil)
        return CaptureProcessingResult(
            destination: CaptureDestination(moduleID: .musicPractice, kind: kindManifest.id),
            resolvedRecordType: "practicePiece",
            resolvedRecordID: piece.id
        )
    }
}

@MainActor
private struct PeopleMemoryCaptureKindProvider: CaptureIntakeKindProviding {
    let peopleMemoryRepository: any PeopleMemoryRepository
    let moduleManifest: CaptureModuleManifest

    let kindManifest = CaptureIntakeKindManifest(
        id: "person-memory",
        moduleID: .peopleMemory,
        displayName: "Person",
        summary: "Use this when the note is really about remembering someone.",
        systemImage: "person.fill.badge.plus",
        fields: [
            CaptureFieldDefinition(key: .personName, title: "Name", kind: .singleLineText, isRequired: true),
            CaptureFieldDefinition(key: .personWhereMet, title: "Where Met", kind: .singleLineText),
            CaptureFieldDefinition(key: .personContext, title: "Context", kind: .multiLineText),
            CaptureFieldDefinition(key: .personRecognitionCues, title: "Recognition Cues", kind: .multiLineText),
            CaptureFieldDefinition(key: .notes, title: "Notes", kind: .multiLineText, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .personPronunciation, title: "Pronunciation", kind: .singleLineText, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .personConversationHooks, title: "Conversation Hooks", kind: .multiLineText, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .personHasMetAt, title: "Set When Met", kind: .toggle, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .personMetAt, title: "When Met", kind: .date, isVisibleByDefault: false),
            CaptureFieldDefinition(key: .personTags, title: "Tags", kind: .tags, isVisibleByDefault: false),
        ],
        templates: [
            CaptureTemplateDefinition(
                id: "classmate",
                title: "Classmate",
                summary: "Sets a light school context and starter tag.",
                presets: [
                    CaptureTemplateFieldPreset(key: .personContext, value: "Class"),
                    CaptureTemplateFieldPreset(key: .personTags, value: "School"),
                ],
                editableFieldKeys: [.personName, .personWhereMet, .personContext, .personRecognitionCues, .personTags]
            ),
            CaptureTemplateDefinition(
                id: "neighbor",
                title: "Neighbor",
                summary: "Useful when the note came from a local interaction.",
                presets: [
                    CaptureTemplateFieldPreset(key: .personContext, value: "Neighborhood"),
                    CaptureTemplateFieldPreset(key: .personTags, value: "Neighbor"),
                ],
                editableFieldKeys: [.personName, .personWhereMet, .personContext, .personRecognitionCues, .personTags]
            ),
            CaptureTemplateDefinition(
                id: "conference",
                title: "Conference",
                summary: "Good for quick event-based people notes.",
                presets: [
                    CaptureTemplateFieldPreset(key: .personContext, value: "Conference"),
                    CaptureTemplateFieldPreset(key: .personTags, value: "Conference"),
                ],
                editableFieldKeys: [.personName, .personWhereMet, .personContext, .personRecognitionCues, .personTags]
            ),
        ],
        defaultTemplateID: "classmate",
        preferredPresentation: .tabs,
        customizationOptions: [
            CaptureCustomizationOption(
                id: "people_detail",
                title: "More Detail",
                fieldKeys: [.notes, .personPronunciation, .personConversationHooks, .personHasMetAt, .personMetAt]
            ),
            CaptureCustomizationOption(
                id: "people_tags",
                title: "Tags",
                fieldKeys: [.personTags]
            ),
        ]
    )

    func draft(for capture: RawCapture) -> CaptureReviewDraft? {
        guard PersonMemory.cleanedName(from: capture.title) != nil else {
            return nil
        }

        return CaptureReviewDraft(capture: capture)
    }

    func validationMessage(for draft: CaptureReviewDraft) -> String? {
        PersonMemory.cleanedName(from: draft.personName) == nil
            ? "Enter a person's name."
            : nil
    }

    func persist(
        draft: CaptureReviewDraft,
        from _: CaptureItem,
        at date: Date
    ) throws -> CaptureProcessingResult {
        let tags = try saveTags(named: draft.normalizedPersonTagNames(), at: date)
        guard let person = draft.makePersonMemory(createdAt: date, updatedAt: date, tagIDs: tags.map(\.id)) else {
            throw CapturePersistenceError.validation("Enter a person's name.")
        }

        try peopleMemoryRepository.savePerson(person, replacingPersonWithID: nil)
        return CaptureProcessingResult(
            destination: CaptureDestination(moduleID: .peopleMemory, kind: kindManifest.id),
            resolvedRecordType: "personMemory",
            resolvedRecordID: person.id
        )
    }

    private func saveTags(named names: [String], at date: Date) throws -> [PersonTag] {
        var savedTags: [PersonTag] = []
        var seenKeys: Set<String> = []

        for name in names {
            guard let cleanedName = PersonTag.cleanedName(from: name) else {
                continue
            }

            let key = PersonTag.normalizedKey(for: cleanedName)
            guard seenKeys.insert(key).inserted else {
                continue
            }

            if let existingTag = try peopleMemoryRepository.tag(withNormalizedKey: key) {
                savedTags.append(existingTag)
                continue
            }

            let tag = PersonTag(name: cleanedName, createdAt: date)
            try peopleMemoryRepository.saveTag(tag, replacingTagWithID: nil)
            savedTags.append(tag)
        }

        return savedTags.sortedForPersonTags()
    }
}

private enum CapturePersistenceError: LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        }
    }
}

private let priorityOptions = PriorityLevel.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let energyOptions = EnergyLevel.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let workModeOptions = WorkModeKind.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let projectPressureOptions = ProjectItemPressure.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let shoppingUrgencyOptions = ShoppingUrgency.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let shoppingNecessityOptions = ShoppingNecessity.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let practiceStatusOptions = PracticePieceStatus.allCases.map {
    CaptureFieldOption(id: $0.rawValue, title: $0.displayName)
}
private let shoppingCategoryOptions = ShoppingItemFieldSuggestions.categories.map {
    CaptureFieldOption(id: $0, title: $0)
}
private let shoppingStoreTypeOptions = ShoppingItemFieldSuggestions.storeTypes.map {
    CaptureFieldOption(id: $0, title: $0)
}
private let shoppingStoreNameOptions = ShoppingItemFieldSuggestions.storeNames.map {
    CaptureFieldOption(id: $0, title: $0)
}
