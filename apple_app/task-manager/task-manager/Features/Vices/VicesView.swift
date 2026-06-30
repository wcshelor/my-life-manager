import Combine
import SwiftUI

struct VicesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VicesViewModel
    @State private var draftName = ""
    @State private var draftUnitLabel = ""
    @State private var isShowingAddSheet = false
    @State private var editingVice: Vice?
    @State private var editingGoal: ViceGoalEditorState?
    @State private var draftGoalMaxOccurrences = 1
    @State private var draftGoalDeadline = Date.now

    private let onChange: () -> Void

    init(
        viceRepository: any ViceRepository,
        debriefRepository: any DebriefRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: VicesViewModel(
                viceRepository: viceRepository,
                debriefRepository: debriefRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let now = timeline.date
                    if viewModel.activeVices.isEmpty {
                        ContentUnavailableView(
                            "No Vices Yet",
                            systemImage: "flame",
                            description: Text("Add a vice to start logging each occurrence with one tap.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.summaries) { summary in
                                    ViceCard(
                                        summary: summary,
                                        now: now,
                                        onTap: {
                                            viewModel.logViceHit(viceID: summary.vice.id)
                                            onChange()
                                        },
                                        onEdit: {
                                            editingVice = summary.vice
                                            draftName = summary.vice.name
                                            draftUnitLabel = summary.vice.unitLabel
                                        },
                                        onArchive: {
                                            viewModel.archiveVice(withID: summary.vice.id)
                                            onChange()
                                        },
                                        onEditGoal: {
                                            let currentGoal = summary.goalProgress?.goal
                                            editingGoal = ViceGoalEditorState(
                                                vice: summary.vice,
                                                goal: currentGoal
                                            )
                                            draftGoalMaxOccurrences = currentGoal?.maxOccurrences ?? max(1, summary.todayCount + 1)
                                            draftGoalDeadline = currentGoal?.deadline ?? Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                if let viceName = viewModel.pendingUndoViceName {
                    HStack(spacing: 12) {
                        Text("Logged \(viceName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button("Undo") {
                            viewModel.undoLastLog()
                            onChange()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Vices")
            .task {
                viewModel.loadIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingVice = nil
                        draftName = ""
                        draftUnitLabel = ""
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Vice", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationStack {
                    viceForm(title: "New Vice") {
                        if viewModel.saveVice(name: draftName, unitLabel: draftUnitLabel) {
                            isShowingAddSheet = false
                            onChange()
                        }
                    }
                }
            }
            .sheet(item: $editingVice) { vice in
                NavigationStack {
                    viceForm(title: "Edit Vice") {
                        if viewModel.saveVice(
                            name: draftName,
                            unitLabel: draftUnitLabel,
                            replacingViceWithID: vice.id
                        ) {
                            editingVice = nil
                            onChange()
                        }
                    }
                }
            }
            .sheet(item: $editingGoal) { state in
                NavigationStack {
                    goalForm(for: state)
                }
            }
        }
    }

    private func viceForm(
        title: String,
        onSave: @escaping () -> Void
    ) -> some View {
        Form {
            Section("Vice") {
                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)

                TextField("Unit label", text: $draftUnitLabel)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isShowingAddSheet = false
                    editingVice = nil
                }
            }
        }
    }

    private func goalForm(for state: ViceGoalEditorState) -> some View {
        Form {
            Section(state.goal == nil ? "Add Limit" : "Edit Limit") {
                Stepper(value: $draftGoalMaxOccurrences, in: 1 ... 10_000) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max occurrences")
                        Text("\(draftGoalMaxOccurrences) \(state.vice.unitLabel.lowercased())")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                DatePicker(
                    "Deadline",
                    selection: $draftGoalDeadline,
                    in: Date.now...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
        .navigationTitle(state.vice.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveGoal(
                        viceID: state.vice.id,
                        maxOccurrences: draftGoalMaxOccurrences,
                        deadline: draftGoalDeadline,
                        replacingGoalWithID: state.goal?.id
                    ) {
                        editingGoal = nil
                        onChange()
                    }
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    editingGoal = nil
                }
            }
        }
    }
}

private struct ViceCard: View {
    let summary: ViceCardSummary
    let now: Date
    let onTap: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onEditGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.vice.name)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Edit", action: onEdit)
                    Button("Archive", role: .destructive, action: onArchive)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(summary.todayCount)")
                    .font(.title2.weight(.semibold))
                Text(summary.vice.unitLabel.lowercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onEditGoal) {
                    Image(systemName: summary.goalProgress == nil ? "target" : "slider.horizontal.below.square.and.square.filled")
                        .font(.footnote.weight(.semibold))
                        .padding(8)
                        .background(Color(.tertiarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(lastLogLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let recentGapSummary = summary.recentHistorySummaryText() {
                Text("Recent gaps: \(recentGapSummary)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let goalProgress = summary.goalProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goalProgress.summaryText())
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(goalColor(for: goalProgress.status))

                    ProgressView(value: goalProgress.clampedRatio, total: 1)
                        .tint(goalColor(for: goalProgress.status))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private var lastLogLabel: String {
        guard let timeSinceLastLog = summary.timeSinceLastLogText(now: now) else {
            return "No logs yet"
        }

        return "Last hit \(timeSinceLastLog) ago"
    }

    private func goalColor(for status: ViceGoalStatus) -> Color {
        switch status {
        case .onTrack:
            return .green
        case .warning:
            return .yellow
        case .exceeded:
            return .red
        }
    }
}

private struct ViceGoalEditorState: Identifiable {
    let vice: Vice
    let goal: ViceGoal?

    var id: UUID {
        vice.id
    }
}
