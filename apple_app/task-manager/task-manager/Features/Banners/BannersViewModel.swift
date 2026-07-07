import Foundation

@MainActor
final class BannersViewModel: ObservableObject {
    @Published private(set) var templates: [AlertTemplate] = []
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var errorMessage: String?

    private let alertRepository: any AlertRepository
    private let alertScheduler: AlertScheduler
    private let routineRepository: any RoutineRepository
    private var hasLoaded = false

    init(
        alertRepository: any AlertRepository,
        alertScheduler: AlertScheduler,
        routineRepository: any RoutineRepository
    ) {
        self.alertRepository = alertRepository
        self.alertScheduler = alertScheduler
        self.routineRepository = routineRepository
    }

    var canCreateBanner: Bool {
        routines.isEmpty == false
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        await load()
    }

    func load() async {
        do {
            templates = try alertRepository.fetchTemplates()
            routines = try routineRepository.fetchRoutines()
                .filter { $0.isArchived == false }
                .sorted { left, right in
                    left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
                }
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load banners: \(error.localizedDescription)"
        }
    }

    func makeNewTemplateDraft() -> AlertTemplate? {
        guard let routine = routines.first else {
            return nil
        }

        let defaultTime = defaultTriggerTime(for: routine)
        let title = "\(routine.name) Banner"
        return AlertTemplate(
            title: title,
            target: .openRoutine(routine.id),
            trigger: .fixedTime(
                AlertFixedTimeTrigger(
                    hour: defaultTime.hour,
                    minute: defaultTime.minute,
                    recurrence: .daily
                )
            ),
            urgency: .normal,
            privacyMode: .full,
            isEnabled: true
        )
    }

    func routineName(for routineID: UUID) -> String {
        routines.first { $0.id == routineID }?.name ?? "Missing Routine"
    }

    func saveTemplate(_ template: AlertTemplate, replacingTemplateWithID originalID: UUID?) async -> Bool {
        guard template.title.isEmpty == false else {
            errorMessage = "Banner title cannot be empty."
            return false
        }

        guard routines.contains(where: { $0.id == template.routineID }) else {
            errorMessage = "Select a valid Routine before saving this Banner."
            return false
        }

        let existingTemplate = try? alertRepository.template(withID: originalID ?? template.id)

        if existingTemplate == nil || (existingTemplate?.isEnabled == false && template.isEnabled) {
            do {
                _ = try await alertScheduler.requestNotificationAuthorization()
            } catch {
                errorMessage = "Unable to request notification permission: \(error.localizedDescription)"
            }
        }

        do {
            try alertRepository.saveTemplate(template, replacingTemplateWithID: originalID)

            if template.isEnabled {
                if existingTemplate == nil {
                    try await alertScheduler.schedule(template)
                } else {
                    try await alertScheduler.reschedule(template)
                }
            } else {
                try await alertScheduler.cancel(templateID: template.id)
            }

            await load()
            return true
        } catch {
            errorMessage = "Unable to save banner: \(error.localizedDescription)"
            return false
        }
    }

    func setTemplateEnabled(_ templateID: UUID, isEnabled: Bool) async {
        guard let template = templates.first(where: { $0.id == templateID }) else {
            return
        }

        var updatedTemplate = template
        updatedTemplate.isEnabled = isEnabled
        updatedTemplate.updatedAt = .now
        _ = await saveTemplate(updatedTemplate, replacingTemplateWithID: templateID)
    }

    func deleteTemplate(withID templateID: UUID) async {
        do {
            try await alertScheduler.cancel(templateID: templateID)
            try alertRepository.deleteTemplate(withID: templateID)
            await load()
        } catch {
            errorMessage = "Unable to delete banner: \(error.localizedDescription)"
        }
    }

    private func defaultTriggerTime(for routine: Routine) -> (hour: Int, minute: Int) {
        let lowercasedName = routine.name.lowercased()

        if lowercasedName.contains("night") || lowercasedName.contains("evening") || lowercasedName.contains("bed") {
            return (21, 0)
        }

        return (7, 30)
    }
}
