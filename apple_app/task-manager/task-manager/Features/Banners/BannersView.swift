import SwiftUI

private struct BannerEditorDraft: Identifiable {
    let id: UUID
    let template: AlertTemplate
    let originalID: UUID?

    init(template: AlertTemplate, originalID: UUID?) {
        self.id = originalID ?? template.id
        self.template = template
        self.originalID = originalID
    }
}

struct BannersView: View {
    @StateObject private var viewModel: BannersViewModel
    @State private var presentedEditor: BannerEditorDraft?

    init(
        alertRepository: any AlertRepository,
        alertScheduler: AlertScheduler,
        routineRepository: any RoutineRepository,
        settingsRepository: any SettingsRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: BannersViewModel(
                alertRepository: alertRepository,
                alertScheduler: alertScheduler,
                routineRepository: routineRepository,
                settingsRepository: settingsRepository
            )
        )
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if viewModel.templates.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Banners Yet",
                        systemImage: "bell.badge",
                        description: Text("Create a Banner to open a Routine at a fixed time or inside a random window.")
                    )
                }
            } else {
                Section("Saved Banners") {
                    ForEach(viewModel.templates) { template in
                        bannerRow(for: template)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteTemplate(withID: template.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Banners")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentNewTemplate()
                } label: {
                    Label("New Banner", systemImage: "plus")
                }
                .disabled(viewModel.canCreateBanner == false)
            }
        }
        .sheet(item: $presentedEditor) { draft in
            NavigationStack {
                BannerTemplateEditorView(
                    template: draft.template,
                    originalID: draft.originalID,
                    routines: viewModel.routines
                ) { updatedTemplate, originalID in
                    await viewModel.saveTemplate(
                        updatedTemplate,
                        replacingTemplateWithID: originalID
                    )
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func bannerRow(for template: AlertTemplate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                presentedEditor = BannerEditorDraft(template: template, originalID: template.id)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    let routineName = template.routineID.map { viewModel.routineName(for: $0) } ?? "Missing Routine"

                    Text(template.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(routineName) · \(template.trigger.scheduleSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(template.urgency.displayName) · \(template.privacyMode.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 12) {
                Text(template.isEnabled ? "On" : "Off")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(template.isEnabled ? .green : .secondary)

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await viewModel.setTemplateEnabled(
                                template.id,
                                isEnabled: !template.isEnabled
                            )
                        }
                    } label: {
                        Image(systemName: template.isEnabled ? "bell.fill" : "bell.slash")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        presentedEditor = BannerEditorDraft(template: template, originalID: template.id)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func presentNewTemplate() {
        guard let template = viewModel.makeNewTemplateDraft() else {
            return
        }

        presentedEditor = BannerEditorDraft(template: template, originalID: nil)
    }
}
