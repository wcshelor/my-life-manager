import SwiftUI

struct HomeWidgetQuickActionSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String?
    let availableQuickActions: [WidgetQuickAction]
    let maximumSelectionCount: Int
    let onSave: ([String]) -> Void

    @State private var selectedQuickActionIDs: [String]

    init(
        title: String,
        subtitle: String? = nil,
        availableQuickActions: [WidgetQuickAction],
        selectedQuickActionIDs: [String],
        maximumSelectionCount: Int = 2,
        onSave: @escaping ([String]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.availableQuickActions = availableQuickActions
        self.maximumSelectionCount = maximumSelectionCount
        self.onSave = onSave
        _selectedQuickActionIDs = State(
            initialValue: HomeWidgetQuickActionResolver.normalizedQuickActionIDs(
                selectedQuickActionIDs,
                maxCount: maximumSelectionCount
            )
        )
    }

    var body: some View {
        Form {
            if let subtitle, subtitle.isEmpty == false {
                Section {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Quick Buttons") {
                if availableQuickActions.isEmpty {
                    ContentUnavailableView(
                        "No Quick Actions",
                        systemImage: "slider.horizontal.3",
                        description: Text("This widget does not expose any configurable buttons.")
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Choose up to \(maximumSelectionCount) buttons.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(availableQuickActions) { action in
                        Toggle(
                            action.title,
                            isOn: Binding(
                                get: { selectedQuickActionIDs.contains(action.id) },
                                set: { isOn in
                                    updateSelection(for: action.id, isOn: isOn)
                                }
                            )
                        )
                        .disabled(
                            selectedQuickActionIDs.count >= maximumSelectionCount &&
                                selectedQuickActionIDs.contains(action.id) == false
                        )
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onSave(
                        HomeWidgetQuickActionResolver.normalizedQuickActionIDs(
                            selectedQuickActionIDs,
                            maxCount: maximumSelectionCount
                        )
                    )
                    dismiss()
                }
            }
        }
    }

    private func updateSelection(for actionID: String, isOn: Bool) {
        if isOn {
            guard selectedQuickActionIDs.contains(actionID) == false else {
                return
            }

            guard selectedQuickActionIDs.count < maximumSelectionCount else {
                return
            }

            selectedQuickActionIDs.append(actionID)
        } else {
            selectedQuickActionIDs.removeAll { $0 == actionID }
        }
    }
}
