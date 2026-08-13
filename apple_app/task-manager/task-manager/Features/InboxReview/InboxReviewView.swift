import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

private enum InboxReviewPreferenceStore {
    private static let tabsOrderKey = "inbox-review.tabs-order"
    private static let projectsOrderKey = "inbox-review.projects-order"
    private static let templatesOrderKey = "inbox-review.template-order"
    private static let customTemplatesStorageKey = "inbox-review.custom-templates"

    static func orderedModuleIDs(for options: [CaptureReviewModuleOption]) -> [CaptureReviewModuleOption] {
        let storedOrder = array(for: tabsOrderKey)
        let map = Dictionary(uniqueKeysWithValues: options.map { ($0.manifest.moduleID.rawValue, $0) })

        let ordered = storedOrder.compactMap { map[$0] }
        let remaining = options.filter { storedOrder.contains($0.manifest.moduleID.rawValue) == false }
        return ordered + remaining
    }

    static func orderedTemplates(
        for destination: CaptureDestination,
        projectID: UUID?,
        templates: [CaptureTemplateDefinition]
    ) -> [CaptureTemplateDefinition] {
        let orderKey = Self.templateOrderKey(for: destination, projectID: projectID)
        let storedOrder = array(for: orderKey)
        let map = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        let ordered = storedOrder.compactMap { map[$0] }
        let remaining = templates.filter { storedOrder.contains($0.id) == false }
        return ordered + remaining
    }

    static func saveModuleOrder(_ moduleIDs: [CaptureModuleID]) {
        set(moduleIDs.map(\.rawValue), for: tabsOrderKey)
    }

    static func orderedProjects(_ projects: [Project]) -> [Project] {
        let storedOrder = array(for: projectsOrderKey)
        let map = Dictionary(uniqueKeysWithValues: projects.map { ($0.id.uuidString, $0) })
        let ordered = storedOrder.compactMap { map[$0] }
        let remaining = projects.filter { storedOrder.contains($0.id.uuidString) == false }
        return ordered + remaining
    }

    static func saveProjectOrder(_ projectIDs: [UUID]) {
        set(projectIDs.map(\.uuidString), for: projectsOrderKey)
    }

    static func saveTemplateOrder(
        _ templateIDs: [String],
        for destination: CaptureDestination,
        projectID: UUID?
    ) {
        set(templateIDs, for: Self.templateOrderKey(for: destination, projectID: projectID))
    }

    static func saveCustomTemplates(
        _ templates: [CaptureTemplateDefinition],
        for destination: CaptureDestination,
        projectID: UUID?
    ) {
        let encoded = templates.map { StoredCustomTemplate(template: $0) }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: Self.customTemplatesStorageKey(for: destination, projectID: projectID))
        }
    }

    static func updateCustomTemplate(
        _ template: CaptureTemplateDefinition,
        for destination: CaptureDestination,
        projectID: UUID?,
        replacingTemplateWithID originalID: String?
    ) {
        var templates = customTemplates(for: destination, projectID: projectID)
        let targetID = originalID ?? template.id
        if let index = templates.firstIndex(where: { $0.id == targetID || $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }

        saveCustomTemplates(templates, for: destination, projectID: projectID)
        saveTemplateOrder(templates.map(\.id), for: destination, projectID: projectID)
    }

    static func deleteCustomTemplate(
        withID templateID: String,
        for destination: CaptureDestination,
        projectID: UUID?
    ) {
        let templates = customTemplates(for: destination, projectID: projectID).filter { $0.id != templateID }
        saveCustomTemplates(templates, for: destination, projectID: projectID)
        saveTemplateOrder(templates.map(\.id), for: destination, projectID: projectID)
    }

    static func customTemplates(for destination: CaptureDestination, projectID: UUID?) -> [CaptureTemplateDefinition] {
        guard let data = UserDefaults.standard.data(forKey: Self.customTemplatesStorageKey(for: destination, projectID: projectID)),
              let stored = try? JSONDecoder().decode([StoredCustomTemplate].self, from: data) else {
            return []
        }

        return stored.map(\.template)
    }

    static func createCustomTemplate(
        from template: CaptureTemplateDefinition,
        for destination: CaptureDestination,
        projectID: UUID?
    ) -> CaptureTemplateDefinition {
        let copyIndex = customTemplates(for: destination, projectID: projectID).count + 1
        let newTemplate = template.copied(
            id: "\(template.id)-custom-\(copyIndex)",
            title: "\(template.title) Copy"
        )
        var customTemplates = customTemplates(for: destination, projectID: projectID)
        customTemplates.append(newTemplate)
        saveCustomTemplates(customTemplates, for: destination, projectID: projectID)
        saveTemplateOrder(customTemplates.map(\.id), for: destination, projectID: projectID)
        return newTemplate
    }

    private static func customTemplatesStorageKey(for destination: CaptureDestination, projectID: UUID?) -> String {
        "\(Self.customTemplatesStorageKey).\(destination.id).\(projectScopeID(projectID))"
    }

    private static func templateOrderKey(for destination: CaptureDestination, projectID: UUID?) -> String {
        "\(Self.templatesOrderKey).\(destination.id).\(projectScopeID(projectID))"
    }

    private static func projectScopeID(_ projectID: UUID?) -> String {
        projectID?.uuidString ?? "unscoped"
    }

    private static func array(for key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private static func set(_ values: [String], for key: String) {
        UserDefaults.standard.set(values, forKey: key)
    }
}

private struct InboxReviewTemplateEditorDraft: Identifiable {
    let id: String
    var template: CaptureTemplateDefinition
    let originalID: String?
    let destination: CaptureDestination
    let projectID: UUID?

    init(
        template: CaptureTemplateDefinition,
        originalID: String?,
        destination: CaptureDestination,
        projectID: UUID?
    ) {
        self.id = originalID ?? template.id
        self.template = template
        self.originalID = originalID
        self.destination = destination
        self.projectID = projectID
    }
}

private extension CaptureTemplateDefinition {
    var isCustomTemplate: Bool {
        id.contains("-custom-")
    }
}

private struct StoredCustomTemplate: Codable {
    var id: String
    var title: String
    var summary: String
    var presets: [StoredPreset]
    var editableFieldKeys: [CaptureFieldKey]

    init(template: CaptureTemplateDefinition) {
        id = template.id
        title = template.title
        summary = template.summary
        presets = template.presets.map { StoredPreset(key: $0.key, value: $0.value) }
        editableFieldKeys = template.editableFieldKeys
    }

    var template: CaptureTemplateDefinition {
        CaptureTemplateDefinition(
            id: id,
            title: title,
            summary: summary,
            presets: presets.map { CaptureTemplateFieldPreset(key: $0.key, value: $0.value) },
            editableFieldKeys: editableFieldKeys
        )
    }
}

private struct StoredPreset: Codable {
    var key: CaptureFieldKey
    var value: String
}

private struct InboxReviewReorderDropDelegate: DropDelegate {
    let targetID: String
    let activeID: String?
    let moveAction: (String, String) -> Void
    let clearAction: () -> Void

    func dropEntered(info: DropInfo) {
        guard let activeID, activeID != targetID else { return }
        moveAction(activeID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        clearAction()
        return true
    }

    func dropExited(info: DropInfo) {
        clearAction()
    }
}

@MainActor
final class InboxReviewViewModel: ObservableObject {
    @Published private(set) var captures: [CaptureItem] = []
    @Published private(set) var reviewHistory: [CaptureItem] = []
    @Published private(set) var projects: [Project] = []
    @Published private(set) var availableTags: [PersonTag] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedDestination: CaptureDestination?
    @Published private(set) var currentDraft = CaptureReviewDraft()
    @Published private(set) var selectedTemplateID: String?

    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let peopleMemoryRepository: any PeopleMemoryRepository
    private let captureRegistry: CaptureIntakeRegistry
    private let nowProvider: @Sendable () -> Date

    private var draftsByDestinationID: [String: CaptureReviewDraft] = [:]
    private var templateIDsByDestinationID: [String: String] = [:]
    private var currentCaptureID: UUID?

    @MainActor
    init(
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        peopleMemoryRepository: any PeopleMemoryRepository,
        captureRegistry: CaptureIntakeRegistry,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.peopleMemoryRepository = peopleMemoryRepository
        self.captureRegistry = captureRegistry
        self.nowProvider = nowProvider
    }

    var currentCapture: CaptureItem? {
        captures.first
    }

    var currentModuleOptions: [CaptureReviewModuleOption] {
        guard let currentCapture else {
            return []
        }

        return captureRegistry.moduleOptions(for: RawCapture(capture: currentCapture))
    }

    var selectedKindOption: CaptureReviewKindOption? {
        guard let selectedDestination else {
            return nil
        }

        return currentModuleOptions
            .flatMap(\.kinds)
            .first { $0.destination == selectedDestination }
    }

    var validationMessage: String? {
        guard let selectedDestination,
              let provider = captureRegistry.provider(for: selectedDestination)
        else {
            return nil
        }

        return provider.validationMessage(for: currentDraft)
    }

    func load() {
        do {
            let allCaptures = try captureRepository.fetchCaptures(
                includeProcessed: true,
                includeArchived: true
            )
            captures = allCaptures.filter(\.isPendingReview)
            reviewHistory = allCaptures
                .filter { $0.isPendingReview == false }
                .sorted { leftCapture, rightCapture in
                    let leftDate = leftCapture.lastReviewedAt ?? leftCapture.archivedAt ?? leftCapture.processedAt ?? leftCapture.updatedAt
                    let rightDate = rightCapture.lastReviewedAt ?? rightCapture.archivedAt ?? rightCapture.processedAt ?? rightCapture.updatedAt
                    if leftDate != rightDate {
                        return leftDate > rightDate
                    }

                    return leftCapture.id.uuidString < rightCapture.id.uuidString
                }
            projects = try projectRepository.fetchProjects(includeArchived: false)
            availableTags = try peopleMemoryRepository.fetchTags()
            errorMessage = nil
            syncSelection()
        } catch {
            errorMessage = "Unable to load inbox: \(error.localizedDescription)"
        }
    }

    func selectModule(_ moduleID: CaptureModuleID) {
        guard let firstKind = currentModuleOptions.first(where: { $0.manifest.moduleID == moduleID })?.kinds.first else {
            return
        }

        selectDestination(firstKind.destination)
    }

    func selectProject(_ projectID: UUID?) {
        guard currentDraft.projectID != projectID else {
            return
        }

        saveCurrentDraft()
        restoreDraft(for: selectedDestination, projectID: projectID)
        currentDraft.projectID = projectID
        saveCurrentDraft()
    }

    func selectDestination(_ destination: CaptureDestination) {
        guard selectedDestination != destination else {
            return
        }

        saveCurrentDraft()
        selectedDestination = destination
        restoreDraft(for: destination, projectID: currentDraft.projectID)
        persistRoutingIfNeeded(for: destination)
    }

    func updateCurrentDraft(_ update: (inout CaptureReviewDraft) -> Void) {
        update(&currentDraft)
        saveCurrentDraft()
    }

    func applyTemplate(_ template: CaptureTemplateDefinition) {
        updateCurrentDraft { draft in
            draft.applyTemplate(template)
        }
        selectedTemplateID = template.id
        if let selectedDestination {
            templateIDsByDestinationID[selectedDestination.id] = template.id
        }
    }

    func persistCurrentSelection() -> Bool {
        guard let capture = currentCapture,
              let destination = selectedDestination,
              let provider = captureRegistry.provider(for: destination)
        else {
            return false
        }

        if let validationMessage {
            errorMessage = validationMessage
            return false
        }

        let now = nowProvider()

        do {
            let result = try provider.persist(draft: currentDraft, from: capture, at: now)
            var updatedCapture = capture
            updatedCapture.markProcessed(
                at: now,
                destination: result.destination,
                resolvedRecordType: result.resolvedRecordType,
                resolvedRecordID: result.resolvedRecordID
            )
            try captureRepository.saveCapture(updatedCapture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID? = nil) -> Bool {
        do {
            try projectRepository.saveProject(project, replacingProjectWithID: originalID)
            projects = try projectRepository.fetchProjects(includeArchived: false)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Unable to save project: \(error.localizedDescription)"
            return false
        }
    }

    func skipCurrentCapture() -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        let now = nowProvider()

        do {
            capture.markSkipped(at: now, destination: selectedDestination)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            if captures.count > 1 {
                let skippedCapture = captures.removeFirst()
                captures.append(skippedCapture)
            }
            errorMessage = nil
            syncSelection(forceDraftReset: captures.count > 1)
            return true
        } catch {
            errorMessage = "Unable to defer sticky note: \(error.localizedDescription)"
            return false
        }
    }

    func archiveCurrentCapture() -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        do {
            capture.archive(at: nowProvider(), destination: selectedDestination)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to archive sticky note: \(error.localizedDescription)"
            return false
        }
    }

    func revisitCapture(_ capture: CaptureItem) -> Bool {
        var reopenedCapture = capture
        reopenedCapture.revisit(at: nowProvider())

        do {
            try captureRepository.saveCapture(reopenedCapture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to reopen sticky note: \(error.localizedDescription)"
            return false
        }
    }

    private func syncSelection(forceDraftReset: Bool = false) {
        guard let currentCapture else {
            currentCaptureID = nil
            selectedDestination = nil
            selectedTemplateID = nil
            currentDraft = CaptureReviewDraft()
            draftsByDestinationID = [:]
            templateIDsByDestinationID = [:]
            return
        }

        if currentCaptureID != currentCapture.id || forceDraftReset {
            currentCaptureID = currentCapture.id
            draftsByDestinationID = [:]
            templateIDsByDestinationID = [:]
            selectedTemplateID = nil
        }

        let moduleOptions = currentModuleOptions
        let availableDestinations = moduleOptions.flatMap(\.kinds).map(\.destination)

        let preferredDestination = preferredDestination(
            for: currentCapture,
            availableDestinations: availableDestinations
        )

        if selectedDestination.map({ availableDestinations.contains($0) }) != true {
            selectedDestination = preferredDestination ?? availableDestinations.first
        } else if let preferredDestination,
                  draftsByDestinationID.isEmpty,
                  selectedDestination != preferredDestination {
            selectedDestination = preferredDestination
        }

        if let selectedDestination {
            restoreDraft(for: selectedDestination, projectID: currentDraft.projectID)
        }
    }

    private func preferredDestination(
        for capture: CaptureItem,
        availableDestinations: [CaptureDestination]
    ) -> CaptureDestination? {
        guard let moduleID = capture.lastReviewedModuleID,
              let kindID = capture.lastReviewedKindID
        else {
            return nil
        }

        let destination = CaptureDestination(moduleID: moduleID, kind: kindID)
        return availableDestinations.contains(destination) ? destination : nil
    }

    private func contextKey(for destination: CaptureDestination, projectID: UUID?) -> String {
        "\(destination.id)::\(projectID?.uuidString ?? "unscoped")"
    }

    private func restoreDraft(for destination: CaptureDestination?, projectID: UUID?) {
        guard let destination else {
            currentDraft = CaptureReviewDraft()
            selectedTemplateID = nil
            return
        }

        let key = contextKey(for: destination, projectID: projectID)
        if let existingDraft = draftsByDestinationID[key] {
            currentDraft = existingDraft
            currentDraft.projectID = projectID
            selectedTemplateID = templateIDsByDestinationID[key]
            return
        }

        guard let kindOption = currentModuleOptions
            .flatMap(\.kinds)
            .first(where: { $0.destination == destination })
        else {
            currentDraft = CaptureReviewDraft()
            return
        }

        var draft = kindOption.initialDraft
        if let defaultTemplateID = kindOption.kindManifest.defaultTemplateID,
           let template = kindOption.kindManifest.templates.first(where: { $0.id == defaultTemplateID }) {
            draft.applyTemplate(template)
            selectedTemplateID = template.id
            templateIDsByDestinationID[key] = template.id
        } else {
            selectedTemplateID = nil
            templateIDsByDestinationID.removeValue(forKey: key)
        }
        draft.projectID = projectID
        currentDraft = draft
        draftsByDestinationID[key] = draft
    }

    private func saveCurrentDraft() {
        guard let selectedDestination else {
            return
        }

        let key = contextKey(for: selectedDestination, projectID: currentDraft.projectID)
        draftsByDestinationID[key] = currentDraft
        if let selectedTemplateID {
            templateIDsByDestinationID[key] = selectedTemplateID
        } else {
            templateIDsByDestinationID.removeValue(forKey: key)
        }
    }

    private func persistRoutingIfNeeded(for destination: CaptureDestination) {
        guard var capture = currentCapture else {
            return
        }

        let alreadySelected =
            capture.lastReviewedModuleID == destination.moduleID
            && capture.lastReviewedKindID == destination.kind
            && capture.lastReviewAction == .routed

        guard alreadySelected == false else {
            return
        }

        do {
            capture.markRouted(to: destination, at: nowProvider())
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            if captures.isEmpty == false {
                captures[0] = capture
            }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save sticky note routing: \(error.localizedDescription)"
        }
    }
}

struct InboxReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: InboxReviewViewModel
    @State private var expandedCustomizationByDestination: [String: Set<String>] = [:]
    @State private var newTagName = ""
    @State private var draggingModuleID: String?
    @State private var draggingProjectID: String?
    @State private var draggingTemplateID: String?
    @State private var presentedTemplateEditor: InboxReviewTemplateEditorDraft?
    @State private var presentedTemplateDeletion: InboxReviewTemplateEditorDraft?
    @State private var isProjectFormPresented = false
    @State private var projectFormDraft: Project?

    let onInboxChanged: () -> Void
    let onDone: () -> Void

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        shoppingRepository: any ShoppingRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        peopleMemoryRepository: any PeopleMemoryRepository,
        onInboxChanged: @escaping () -> Void = {},
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InboxReviewViewModel(
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                peopleMemoryRepository: peopleMemoryRepository,
                captureRegistry: CaptureIntakeRegistry.standard(
                    taskRepository: taskRepository,
                    projectItemRepository: projectItemRepository,
                    shoppingRepository: shoppingRepository,
                    musicPracticeRepository: musicPracticeRepository,
                    peopleMemoryRepository: peopleMemoryRepository
                )
            )
        )
        self.onInboxChanged = onInboxChanged
        self.onDone = onDone
    }

    var body: some View {
        Group {
            if let capture = viewModel.currentCapture {
                activeReviewView(capture)
            } else {
                clearedState
            }
        }
        .navigationTitle("Review Inbox")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onInboxChanged()
                    onDone()
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
        .onChange(of: viewModel.currentCapture?.id) { _, _ in
            newTagName = ""
        }
        .onChange(of: viewModel.selectedDestination?.id) { _, _ in
            newTagName = ""
        }
        .sheet(isPresented: $isProjectFormPresented) {
            NavigationStack {
                InboxReviewProjectFormView(initialProject: projectFormDraft) { project in
                    if viewModel.saveProject(project) {
                        viewModel.selectProject(project.id)
                        isProjectFormPresented = false
                        projectFormDraft = nil
                    }
                }
            }
        }
        .sheet(item: $presentedTemplateEditor) { draft in
            NavigationStack {
                InboxReviewTemplateEditorView(
                    template: draft.template,
                    originalID: draft.originalID,
                    onSave: { updatedTemplate, originalID in
                        InboxReviewPreferenceStore.updateCustomTemplate(
                            updatedTemplate,
                            for: draft.destination,
                            projectID: draft.projectID,
                            replacingTemplateWithID: originalID
                        )
                        presentedTemplateEditor = nil
                    }
                )
            }
        }
        .alert(item: $presentedTemplateDeletion) { draft in
            Alert(
                title: Text("Delete Template?"),
                message: Text("This will remove \"\(draft.template.title)\" from the saved template row for this review context."),
                primaryButton: .destructive(Text("Delete")) {
                    InboxReviewPreferenceStore.deleteCustomTemplate(
                        withID: draft.template.id,
                        for: draft.destination,
                        projectID: draft.projectID
                    )
                    presentedTemplateDeletion = nil
                },
                secondaryButton: .cancel {
                    presentedTemplateDeletion = nil
                }
            )
        }
    }

    private func activeReviewView(_ capture: CaptureItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stickyNoteCard(capture)
                reviewFeedback
                moduleChooser
                projectChooserIfNeeded
                templateAndFormSection
                actionRow
            }
            .padding()
        }
    }

    @ViewBuilder
    private var reviewFeedback: some View {
        if let errorMessage = viewModel.errorMessage {
            feedbackText(errorMessage, color: .red)
        } else if let validationMessage = viewModel.validationMessage {
            feedbackText(validationMessage, color: .secondary)
        }
    }

    @ViewBuilder
    private var projectChooserIfNeeded: some View {
        if let selectedKind = viewModel.selectedKindOption,
           selectedKind.moduleManifest.moduleID == CaptureModuleID.tasks {
            projectChooser
        }
    }

    @ViewBuilder
    private var templateAndFormSection: some View {
        if let selectedKind = viewModel.selectedKindOption {
            let templates = templates(for: selectedKind)
            if templates.isEmpty == false {
                templateSection(
                    templates,
                    destination: selectedKind.destination,
                    projectID: viewModel.currentDraft.projectID
                )
            }

            intakeForm(for: selectedKind)
        }
    }

    private var selectedDestination: CaptureDestination? {
        viewModel.selectedDestination
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                if viewModel.skipCurrentCapture() {
                    onInboxChanged()
                }
            } label: {
                Label("Later", systemImage: "arrow.uturn.backward.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                if viewModel.persistCurrentSelection() {
                    onInboxChanged()
                }
            } label: {
                Label(saveButtonTitle, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedKindOption == nil || viewModel.validationMessage != nil)

            Button(role: .destructive) {
                if viewModel.archiveCurrentCapture() {
                    onInboxChanged()
                }
            } label: {
                Label("Archive", systemImage: "archivebox")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var saveButtonTitle: String {
        if let selectedKind = viewModel.selectedKindOption?.kindManifest.displayName {
            return "Save \(selectedKind)"
        }

        return "Save"
    }

    @ViewBuilder
    private var moduleChooser: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(orderedModuleOptions) { option in
                    Button {
                        viewModel.selectModule(option.manifest.moduleID)
                    } label: {
                        Text(option.manifest.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedDestination?.moduleID == option.manifest.moduleID ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                selectedDestination?.moduleID == option.manifest.moduleID
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(draggingModuleID == option.manifest.moduleID.rawValue ? 0.7 : 1)
                    .scaleEffect(draggingModuleID == option.manifest.moduleID.rawValue ? 0.97 : 1)
                    .animation(.snappy(duration: 0.16), value: draggingModuleID)
                    .onDrag {
                        draggingModuleID = option.manifest.moduleID.rawValue
                        return NSItemProvider(object: option.manifest.moduleID.rawValue as NSString)
                    }
                    .onDrop(
                        of: [UTType.text.identifier],
                        delegate: InboxReviewReorderDropDelegate(
                            targetID: option.manifest.moduleID.rawValue,
                            activeID: draggingModuleID,
                            moveAction: moveModule,
                            clearAction: { draggingModuleID = nil }
                        )
                    )
                }
            }
        }
    }

    private var orderedModuleOptions: [CaptureReviewModuleOption] {
        InboxReviewPreferenceStore.orderedModuleIDs(for: viewModel.currentModuleOptions)
    }

    private var orderedProjects: [Project] {
        InboxReviewPreferenceStore.orderedProjects(viewModel.projects)
    }

    private func templates(for selectedKind: CaptureReviewKindOption) -> [CaptureTemplateDefinition] {
        let customTemplates = InboxReviewPreferenceStore.customTemplates(
            for: selectedKind.destination,
            projectID: viewModel.currentDraft.projectID
        )
        return orderedTemplates(
            for: selectedKind.destination,
            projectID: viewModel.currentDraft.projectID,
            templates: selectedKind.kindManifest.templates + customTemplates
        )
    }

    private func moveModule(_ sourceID: String, _ destinationID: String) {
        guard sourceID != destinationID else { return }

        var reordered = orderedModuleOptions
        guard let sourceIndex = reordered.firstIndex(where: { $0.manifest.moduleID.rawValue == sourceID }),
              let destinationIndex = reordered.firstIndex(where: { $0.manifest.moduleID.rawValue == destinationID })
        else {
            return
        }

        let moved = reordered.remove(at: sourceIndex)
        let insertionIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        reordered.insert(moved, at: insertionIndex)
        InboxReviewPreferenceStore.saveModuleOrder(reordered.map(\.manifest.moduleID))
    }

    private func moveProject(_ sourceID: String, _ destinationID: String) {
        guard sourceID != destinationID else { return }

        var reordered = orderedProjects
        guard let sourceIndex = reordered.firstIndex(where: { $0.id.uuidString == sourceID }),
              let destinationIndex = reordered.firstIndex(where: { $0.id.uuidString == destinationID })
        else {
            return
        }

        let moved = reordered.remove(at: sourceIndex)
        let insertionIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        reordered.insert(moved, at: insertionIndex)
        InboxReviewPreferenceStore.saveProjectOrder(reordered.map(\.id))
    }

    private func selectProject(_ project: Project?) {
        viewModel.selectProject(project?.id)
    }

    private var projectChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectProject(nil)
                    } label: {
                        projectChip(title: "None", isSelected: viewModel.currentDraft.projectID == nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(orderedProjects) { project in
                        Button {
                            selectProject(project)
                        } label: {
                            projectChip(
                                title: project.name,
                                isSelected: viewModel.currentDraft.projectID == project.id
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(draggingProjectID == project.id.uuidString ? 0.7 : 1)
                        .scaleEffect(draggingProjectID == project.id.uuidString ? 0.97 : 1)
                        .animation(.snappy(duration: 0.16), value: draggingProjectID)
                    }

                    Button {
                        projectFormDraft = nil
                        isProjectFormPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Project")
                }
            }
        }
    }

    private func orderedTemplates(
        for destination: CaptureDestination,
        projectID: UUID?,
        templates: [CaptureTemplateDefinition]
    ) -> [CaptureTemplateDefinition] {
        InboxReviewPreferenceStore.orderedTemplates(for: destination, projectID: projectID, templates: templates)
    }

    private func moveTemplate(
        sourceID: String,
        destinationID: String,
        destination: CaptureDestination,
        projectID: UUID?,
        templates: [CaptureTemplateDefinition]
    ) {
        guard sourceID != destinationID else { return }

        var reordered = templates
        guard let sourceIndex = reordered.firstIndex(where: { $0.id == sourceID }),
              let destinationIndex = reordered.firstIndex(where: { $0.id == destinationID })
        else {
            return
        }

        let moved = reordered.remove(at: sourceIndex)
        let insertionIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        reordered.insert(moved, at: insertionIndex)
        InboxReviewPreferenceStore.saveTemplateOrder(reordered.map(\.id), for: destination, projectID: projectID)
    }

    private func templateSection(
        _ templates: [CaptureTemplateDefinition],
        destination: CaptureDestination,
        projectID: UUID?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Templates")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates) { template in
                        templateCard(
                            template,
                            destination: destination,
                            projectID: projectID,
                            templates: templates
                        )
                    }

                    Button {
                        createTemplateCopy(for: destination, projectID: projectID, using: templates)
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .frame(width: 56, height: 84)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func templateCard(
        _ template: CaptureTemplateDefinition,
        destination: CaptureDestination,
        projectID: UUID?,
        templates: [CaptureTemplateDefinition]
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                viewModel.applyTemplate(template)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.subheadline.weight(.semibold))
                    Text(template.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(width: 164, alignment: .leading)
                .background(
                    viewModel.selectedTemplateID == template.id
                        ? Color.accentColor.opacity(0.16)
                        : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            viewModel.selectedTemplateID == template.id
                                ? Color.accentColor.opacity(0.5)
                                : Color.clear
                        )
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    let editableTemplate = template.isCustomTemplate
                        ? template
                        : template.copied(
                            id: "\(template.id)-custom-\(InboxReviewPreferenceStore.customTemplates(for: destination, projectID: projectID).count + 1)",
                            title: "\(template.title) Copy"
                        )
                    presentedTemplateEditor = InboxReviewTemplateEditorDraft(
                        template: editableTemplate,
                        originalID: template.isCustomTemplate ? template.id : nil,
                        destination: destination,
                        projectID: projectID
                    )
                } label: {
                    Label("Edit Template", systemImage: "pencil")
                }

                if template.isCustomTemplate {
                    Button(role: .destructive) {
                        presentedTemplateDeletion = InboxReviewTemplateEditorDraft(
                            template: template,
                            originalID: template.id,
                            destination: destination,
                            projectID: projectID
                        )
                    } label: {
                        Label("Delete Template", systemImage: "trash")
                    }
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12), in: Circle())
                    .opacity(draggingTemplateID == template.id ? 0.7 : 1)
                    .scaleEffect(draggingTemplateID == template.id ? 0.97 : 1)
                    .animation(.snappy(duration: 0.16), value: draggingTemplateID)
                    .onDrag {
                        draggingTemplateID = template.id
                        return NSItemProvider(object: template.id as NSString)
                    }
                    .onDrop(
                        of: [UTType.text.identifier],
                        delegate: InboxReviewReorderDropDelegate(
                            targetID: template.id,
                            activeID: draggingTemplateID,
                            moveAction: { sourceID, destinationID in
                                moveTemplate(
                                    sourceID: sourceID,
                                    destinationID: destinationID,
                                    destination: destination,
                                    projectID: projectID,
                                    templates: templates
                                )
                            },
                            clearAction: { draggingTemplateID = nil }
                        )
                    )
                    .accessibilityLabel("Reorder template")
            }
        }
    }

    private func createTemplateCopy(
        for destination: CaptureDestination,
        projectID: UUID?,
        using templates: [CaptureTemplateDefinition]
    ) {
        guard let sourceTemplate = templates.first(where: { $0.id == viewModel.selectedTemplateID }) ?? templates.first else {
            return
        }

        let newTemplate = InboxReviewPreferenceStore.createCustomTemplate(
            from: sourceTemplate,
            for: destination,
            projectID: projectID
        )
        viewModel.applyTemplate(newTemplate)
    }

    private func projectChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 72)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.06),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.18) : .clear, radius: 4, y: 1)
    }

    private struct InboxReviewProjectFormView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var name: String
        @State private var summary: String
        @State private var isPinned: Bool
        let initialProject: Project?
        let onSave: (Project) -> Void

        init(initialProject: Project? = nil, onSave: @escaping (Project) -> Void) {
            self.initialProject = initialProject
            self.onSave = onSave
            _name = State(initialValue: initialProject?.name ?? "")
            _summary = State(initialValue: initialProject?.summary ?? "")
            _isPinned = State(initialValue: initialProject?.isPinned ?? false)
        }

        var body: some View {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Summary", text: $summary, axis: .vertical)
                    Toggle("Pin to Home", isOn: $isPinned)
                }
            }
            .navigationTitle(initialProject == nil ? "New Project" : "Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let now = Date()
                        let project = Project(
                            id: initialProject?.id ?? UUID(),
                            name: name,
                            summary: summary,
                            isPinned: isPinned,
                            isArchived: initialProject?.isArchived ?? false,
                            createdAt: initialProject?.createdAt ?? now,
                            updatedAt: now
                        )
                        onSave(project)
                    }
                    .disabled(Project.cleanedName(from: name) == nil)
                }
            }
        }
    }

    private struct InboxReviewTemplateEditorView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var title: String
        @State private var summary: String
        @State private var presetValues: [CaptureFieldKey: String]
        let template: CaptureTemplateDefinition
        let originalID: String?
        let onSave: (CaptureTemplateDefinition, String?) -> Void

        init(
            template: CaptureTemplateDefinition,
            originalID: String?,
            onSave: @escaping (CaptureTemplateDefinition, String?) -> Void
        ) {
            self.template = template
            self.originalID = originalID
            self.onSave = onSave
            _title = State(initialValue: template.title)
            _summary = State(initialValue: template.summary)
            _presetValues = State(
                initialValue: Dictionary(uniqueKeysWithValues: template.presets.map { ($0.key, $0.value) })
            )
        }

        var body: some View {
            Form {
                Section("Template") {
                    TextField("Title", text: $title)
                    TextField("Summary", text: $summary, axis: .vertical)
                }

                if template.editableFieldKeys.isEmpty == false {
                    Section("Preset Values") {
                        ForEach(template.editableFieldKeys, id: \.self) { key in
                            TextField(key.displayName, text: binding(for: key))
                        }
                    }
                }
            }
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedTemplate = CaptureTemplateDefinition(
                            id: template.id,
                            title: cleanedTitle,
                            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                            presets: template.editableFieldKeys.compactMap { key in
                                let value = presetValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                guard value.isEmpty == false else {
                                    return nil
                                }

                                return CaptureTemplateFieldPreset(key: key, value: value)
                            },
                            editableFieldKeys: template.editableFieldKeys
                        )
                        onSave(updatedTemplate, originalID)
                        dismiss()
                    }
                    .disabled(cleanedTitle.isEmpty)
                }
            }
        }

        private var cleanedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func binding(for key: CaptureFieldKey) -> Binding<String> {
            Binding(
                get: { presetValues[key, default: ""] },
                set: { presetValues[key] = $0 }
            )
        }
    }

    private func intakeForm(for selectedKind: CaptureReviewKindOption) -> some View {
        let manifest = selectedKind.kindManifest
        let visibleFieldKeys = visibleFieldKeys(for: selectedKind.destination, manifest: manifest)
        let fields = manifest.fields.filter { visibleFieldKeys.contains($0.key) }
        let hiddenOptions = manifest.customizationOptions.filter { customizationIsExpanded($0, for: selectedKind.destination) == false }

        return VStack(alignment: .leading, spacing: 14) {
            Text(manifest.displayName)
                .font(.headline)

            ForEach(fields) { field in
                fieldView(field)
            }

            if manifest.customizationOptions.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional")
                        .font(.subheadline.weight(.semibold))

                    ForEach(manifest.customizationOptions) { option in
                        let isExpanded = customizationIsExpanded(option, for: selectedKind.destination)

                        Button {
                            toggleCustomization(option, for: selectedKind.destination)
                        } label: {
                            HStack {
                                Label(option.title, systemImage: "slider.horizontal.3")
                                Spacer()
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)

                        if isExpanded {
                            ForEach(manifest.fields.filter { option.fieldKeys.contains($0.key) && $0.isVisibleByDefault == false }) { field in
                                fieldView(field)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func fieldView(_ field: CaptureFieldDefinition) -> some View {
        switch field.key {
        case .title:
            labeledField(field.title, helperText: field.helperText) {
                TextField(field.title, text: stringBinding(\.title))
                    .textFieldStyle(.roundedBorder)
            }
        case .notes:
            labeledField(field.title, helperText: field.helperText) {
                TextField(field.title, text: stringBinding(\.notes), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        case .projectID:
            labeledField(field.title, helperText: field.helperText) {
                if viewModel.projects.isEmpty {
                    Text("No projects yet. Create one from the Projects tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(field.title, selection: projectBinding()) {
                        Text("None").tag(nil as UUID?)
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(project.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        case .taskEstimatedMinutes:
            labeledField(field.title, helperText: field.helperText) {
                TextField("30", text: stringBinding(\.taskEstimatedMinutesText))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
        case .taskHasDueDate:
            Toggle(field.title, isOn: boolBinding(\.taskHasDueDate))
        case .taskDueDate:
            if viewModel.currentDraft.taskHasDueDate {
                DatePicker(field.title, selection: dateBinding(\.taskDueDate), displayedComponents: [.date, .hourAndMinute])
            }
        case .taskPriority:
            pickerField(field.title, selection: optionalEnumBinding(\.taskPriority), options: PriorityLevel.allCases)
        case .taskEnergyLevel:
            pickerField(field.title, selection: optionalEnumBinding(\.taskEnergyLevel), options: EnergyLevel.allCases)
        case .taskWorkMode:
            pickerField(field.title, selection: optionalEnumBinding(\.taskWorkMode), options: WorkModeKind.allCases)
        case .taskGroup:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Follow Up", text: stringBinding(\.taskGroupText))
                    .textFieldStyle(.roundedBorder)
            }
        case .taskTags:
            labeledField(field.title, helperText: field.helperText) {
                TextField("email, admin", text: stringBinding(\.taskTagsText))
                    .textFieldStyle(.roundedBorder)
            }
        case .projectItemPressure:
            pickerField(field.title, selection: optionalEnumBinding(\.projectItemPressure), options: ProjectItemPressure.allCases)
        case .projectItemHasReviewAfter:
            Toggle(field.title, isOn: boolBinding(\.projectItemHasReviewAfter))
        case .projectItemReviewAfter:
            if viewModel.currentDraft.projectItemHasReviewAfter {
                DatePicker(field.title, selection: dateBinding(\.projectItemReviewAfter), displayedComponents: [.date, .hourAndMinute])
            }
        case .shoppingCategory:
            suggestionField(
                title: field.title,
                text: stringBinding(\.shoppingCategory),
                suggestions: field.options.map(\.title)
            )
        case .shoppingStoreType:
            suggestionField(
                title: field.title,
                text: stringBinding(\.shoppingStoreType),
                suggestions: field.options.map(\.title)
            )
        case .shoppingStoreName:
            suggestionField(
                title: field.title,
                text: stringBinding(\.shoppingStoreName),
                suggestions: field.options.map(\.title)
            )
        case .shoppingUrgency:
            pickerField(field.title, selection: enumBinding(\.shoppingUrgency), options: ShoppingUrgency.allCases)
        case .shoppingNecessity:
            pickerField(field.title, selection: enumBinding(\.shoppingNecessity), options: ShoppingNecessity.allCases)
        case .practiceComposer:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Composer / Artist", text: stringBinding(\.practiceComposer))
                    .textFieldStyle(.roundedBorder)
            }
        case .practiceCatalogOrOpus:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Op. 28 No. 4", text: stringBinding(\.practiceCatalogOrOpus))
                    .textFieldStyle(.roundedBorder)
            }
        case .practiceInstrument:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Piano", text: stringBinding(\.practiceInstrument))
                    .textFieldStyle(.roundedBorder)
            }
        case .practiceStatus:
            pickerField(field.title, selection: enumBinding(\.practiceStatus), options: PracticePieceStatus.allCases)
        case .personName:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Name", text: stringBinding(\.personName))
                    .textFieldStyle(.roundedBorder)
            }
        case .personPronunciation:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Pronunciation note", text: stringBinding(\.personPronunciation))
                    .textFieldStyle(.roundedBorder)
            }
        case .personWhereMet:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Where met", text: stringBinding(\.personWhereMet))
                    .textFieldStyle(.roundedBorder)
            }
        case .personHasMetAt:
            Toggle(field.title, isOn: boolBinding(\.personHasMetAt))
        case .personMetAt:
            if viewModel.currentDraft.personHasMetAt {
                DatePicker(field.title, selection: dateBinding(\.personMetAt), displayedComponents: .date)
            }
        case .personContext:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Context", text: stringBinding(\.personContext), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        case .personRecognitionCues:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Recognition cues", text: stringBinding(\.personRecognitionCues), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        case .personConversationHooks:
            labeledField(field.title, helperText: field.helperText) {
                TextField("Conversation hooks", text: stringBinding(\.personConversationHooks), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        case .personTags:
            personTagsField
        }
    }

    private var personTagsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline.weight(.medium))

            if viewModel.currentDraft.personTagNames.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.currentDraft.personTagNames, id: \.self) { tagName in
                            Button {
                                toggleTagName(tagName)
                            } label: {
                                Text(tagName)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.18), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if viewModel.availableTags.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableTags) { tag in
                            Button {
                                toggleTagName(tag.name)
                            } label: {
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        isTagSelected(tag.name)
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                TextField("New tag", text: $newTagName)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    addTagName(newTagName)
                    newTagName = ""
                }
                .disabled(PersonTag.cleanedName(from: newTagName) == nil)
            }
        }
    }

    private var clearedState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ContentUnavailableView(
                    "Inbox Clear",
                    systemImage: "tray",
                    description: Text("New sticky notes will appear here for review.")
                )

                if viewModel.reviewHistory.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recently Reviewed")
                            .font(.headline)

                        ForEach(viewModel.reviewHistory.prefix(8)) { capture in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(capture.title)
                                    .font(.subheadline.weight(.semibold))
                                if let notes = capture.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text(historyLabel(for: capture))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Reopen") {
                                        if viewModel.revisitCapture(capture) {
                                            onInboxChanged()
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func historyLabel(for capture: CaptureItem) -> String {
        switch capture.lastReviewAction {
        case .processed:
            return "Processed"
        case .archived:
            return "Archived"
        case .skipped:
            return "Skipped"
        case .routed:
            return "Routed"
        case .revisited:
            return "Revisited"
        case .created, .none:
            return "Reviewed"
        }
    }

    private func stickyNoteCard(_ capture: CaptureItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sticky Note", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(capture.title)
                .font(.title3.weight(.semibold))

            if let notes = capture.notes {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let source = capture.source {
                    Label(source, systemImage: "tray.full")
                }
                Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func feedbackText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(color)
    }

    private func visibleFieldKeys(
        for destination: CaptureDestination,
        manifest: CaptureIntakeKindManifest
    ) -> Set<CaptureFieldKey> {
        var visibleFieldKeys = Set(
            manifest.fields
                .filter(\.isVisibleByDefault)
                .map(\.key)
        )

        let expandedOptions = expandedCustomizationByDestination[destination.id] ?? []
        for option in manifest.customizationOptions where expandedOptions.contains(option.id) {
            visibleFieldKeys.formUnion(option.fieldKeys)
        }

        return visibleFieldKeys
    }

    private func customizationIsExpanded(
        _ option: CaptureCustomizationOption,
        for destination: CaptureDestination
    ) -> Bool {
        expandedCustomizationByDestination[destination.id]?.contains(option.id) == true
    }

    private func expandCustomization(
        _ option: CaptureCustomizationOption,
        for destination: CaptureDestination
    ) {
        expandedCustomizationByDestination[destination.id, default: []].insert(option.id)
    }

    private func toggleCustomization(
        _ option: CaptureCustomizationOption,
        for destination: CaptureDestination
    ) {
        if customizationIsExpanded(option, for: destination) {
            expandedCustomizationByDestination[destination.id]?.remove(option.id)
        } else {
            expandCustomization(option, for: destination)
        }
    }

    private func labeledField<Content: View>(
        _ title: String,
        helperText: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content()
            if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func suggestionField(
        title: String,
        text: Binding<String>,
        suggestions: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)

            if suggestions.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                text.wrappedValue = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func pickerField<Value: Hashable & CaseIterable & RawRepresentable>(
        _ title: String,
        selection: Binding<Value>,
        options: Value.AllCases
    ) -> some View where Value.RawValue == String {
        Picker(title, selection: selection) {
            ForEach(Array(options), id: \.self) { option in
                Text(displayName(for: option)).tag(option)
            }
        }
        .pickerStyle(.menu)
    }

    private func pickerField<Value: Hashable & CaseIterable & RawRepresentable>(
        _ title: String,
        selection: Binding<Value?>,
        options: Value.AllCases
    ) -> some View where Value.RawValue == String {
        Picker(title, selection: selection) {
            Text("None").tag(nil as Value?)
            ForEach(Array(options), id: \.self) { option in
                Text(displayName(for: option)).tag(option as Value?)
            }
        }
        .pickerStyle(.menu)
    }

    private func displayName<Value: RawRepresentable>(for value: Value) -> String where Value.RawValue == String {
        switch value {
        case let priority as PriorityLevel:
            return priority.displayName
        case let energy as EnergyLevel:
            return energy.displayName
        case let workMode as WorkModeKind:
            return workMode.displayName
        case let pressure as ProjectItemPressure:
            return pressure.displayName
        case let urgency as ShoppingUrgency:
            return urgency.displayName
        case let necessity as ShoppingNecessity:
            return necessity.displayName
        case let status as PracticePieceStatus:
            return status.displayName
        default:
            return value.rawValue.capitalized
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<CaptureReviewDraft, String>) -> Binding<String> {
        Binding(
            get: { viewModel.currentDraft[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateCurrentDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<CaptureReviewDraft, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.currentDraft[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateCurrentDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func dateBinding(_ keyPath: WritableKeyPath<CaptureReviewDraft, Date>) -> Binding<Date> {
        Binding(
            get: { viewModel.currentDraft[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateCurrentDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func projectBinding() -> Binding<UUID?> {
        Binding(
            get: { viewModel.currentDraft.projectID },
            set: { newValue in
                viewModel.selectProject(newValue)
            }
        )
    }

    private func enumBinding<Value>(_ keyPath: WritableKeyPath<CaptureReviewDraft, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.currentDraft[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateCurrentDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func optionalEnumBinding<Value>(_ keyPath: WritableKeyPath<CaptureReviewDraft, Value?>) -> Binding<Value?> {
        Binding(
            get: { viewModel.currentDraft[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateCurrentDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func addTagName(_ rawName: String) {
        guard let cleanedName = PersonTag.cleanedName(from: rawName),
              isTagSelected(cleanedName) == false
        else {
            return
        }

        viewModel.updateCurrentDraft { draft in
            draft.personTagNames.append(cleanedName)
        }
    }

    private func toggleTagName(_ rawName: String) {
        let key = PersonTag.normalizedKey(for: rawName)
        if isTagSelected(rawName) {
            viewModel.updateCurrentDraft { draft in
                draft.personTagNames.removeAll { PersonTag.normalizedKey(for: $0) == key }
            }
        } else {
            addTagName(rawName)
        }
    }

    private func isTagSelected(_ rawName: String) -> Bool {
        let key = PersonTag.normalizedKey(for: rawName)
        return viewModel.currentDraft.personTagNames.contains { PersonTag.normalizedKey(for: $0) == key }
    }
}

private struct InboxModuleTile: View {
    let manifest: CaptureModuleManifest
    let kindCount: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(manifest.displayName, systemImage: manifest.systemImage)
                .font(.headline)
            Text(manifest.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(kindCount == 1 ? "1 intake type" : "\(kindCount) intake types")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear)
        )
    }
}

private extension CaptureFieldKey {
    var displayName: String {
        switch self {
        case .title:
            return "Title"
        case .notes:
            return "Notes"
        case .projectID:
            return "Project"
        case .taskEstimatedMinutes:
            return "Estimated Minutes"
        case .taskHasDueDate:
            return "Has Due Date"
        case .taskDueDate:
            return "Due Date"
        case .taskPriority:
            return "Priority"
        case .taskEnergyLevel:
            return "Energy Level"
        case .taskWorkMode:
            return "Work Mode"
        case .taskGroup:
            return "Task Group"
        case .taskTags:
            return "Task Tags"
        case .projectItemPressure:
            return "Pressure"
        case .projectItemHasReviewAfter:
            return "Review Later"
        case .projectItemReviewAfter:
            return "Review After"
        case .shoppingCategory:
            return "Category"
        case .shoppingStoreType:
            return "Store Type"
        case .shoppingStoreName:
            return "Store Name"
        case .shoppingUrgency:
            return "Urgency"
        case .shoppingNecessity:
            return "Necessity"
        case .practiceComposer:
            return "Composer"
        case .practiceCatalogOrOpus:
            return "Catalog or Opus"
        case .practiceInstrument:
            return "Instrument"
        case .practiceStatus:
            return "Status"
        case .personName:
            return "Name"
        case .personPronunciation:
            return "Pronunciation"
        case .personWhereMet:
            return "Where Met"
        case .personHasMetAt:
            return "Has Met At"
        case .personMetAt:
            return "Met At"
        case .personContext:
            return "Context"
        case .personRecognitionCues:
            return "Recognition Cues"
        case .personConversationHooks:
            return "Conversation Hooks"
        case .personTags:
            return "Tags"
        }
    }
}
