import SwiftUI

nonisolated enum PromiseModuleInitialRoute: Equatable, Sendable {
    case newPromise
    case checkInDuePromise(UUID?)
}

struct PromiseModuleView: View {
    @ObservedObject var viewModel: HomeExecutionViewModel
    @State private var presentedSheet: SheetDestination?
    @State private var hasAppliedInitialRoute = false

    private let initialRoute: PromiseModuleInitialRoute?

    private enum SheetDestination: Identifiable {
        case promiseForm
        case promiseCheckIn(Promise)

        var id: String {
            switch self {
            case .promiseForm:
                return "promiseForm"
            case .promiseCheckIn(let promise):
                return "promiseCheckIn-\(promise.id.uuidString)"
            }
        }
    }

    init(
        viewModel: HomeExecutionViewModel,
        initialRoute: PromiseModuleInitialRoute? = nil
    ) {
        self.viewModel = viewModel
        self.initialRoute = initialRoute
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summary
                duePromisesSection
                activePromisesSection
                historySection
            }
            .padding()
        }
        .navigationTitle("Promises")
        .task {
            applyInitialRouteIfNeeded()
        }
        .onChange(of: viewModel.duePromises.map(\.id)) { _, _ in
            applyInitialRouteIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = .promiseForm
                } label: {
                    Label("New Promise", systemImage: "plus")
                }
            }
        }
        .sheet(item: $presentedSheet) { destination in
            NavigationStack {
                switch destination {
                case .promiseForm:
                    PromiseFormView { promise in
                        viewModel.savePromise(promise)
                        presentedSheet = nil
                    }
                case .promiseCheckIn(let promise):
                    PromiseCheckInView(
                        promise: promise,
                        onResolve: { outcome, reflection in
                            viewModel.resolvePromise(
                                withID: promise.id,
                                outcome: outcome,
                                reflection: reflection
                            )
                            presentedSheet = nil
                        },
                        onReset: { title, checkInAt in
                            viewModel.makeResetPromise(
                                from: promise,
                                title: title,
                                checkInAt: checkInAt
                            )
                            presentedSheet = nil
                        }
                    )
                }
            }
        }
    }

    private func applyInitialRouteIfNeeded() {
        guard hasAppliedInitialRoute == false, let initialRoute else {
            return
        }

        switch initialRoute {
        case .newPromise:
            presentedSheet = .promiseForm
            hasAppliedInitialRoute = true
        case .checkInDuePromise(let promiseID):
            let promise = promiseID.flatMap { requestedID in
                viewModel.duePromises.first { $0.id == requestedID }
            } ?? viewModel.duePromises.first

            guard let promise else {
                return
            }

            presentedSheet = .promiseCheckIn(promise)
            hasAppliedInitialRoute = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Promises", systemImage: "hand.raised.fill")
                .font(.title3.weight(.semibold))

            Text("Track commitments, check in on due items, and review what has been kept or missed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            PromiseStatView(title: "Active", value: viewModel.activePromises.count, color: .blue)
            PromiseStatView(title: "Due", value: viewModel.duePromises.count, color: .orange)
            PromiseStatView(title: "Kept", value: viewModel.keptCount, color: .green)
            PromiseStatView(title: "Missed", value: viewModel.missedCount, color: .red)
        }
    }

    private var duePromisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Due Now")
                .font(.headline)

            if let promise = viewModel.duePromises.first {
                PromiseCard(
                    promise: promise,
                    isDue: true,
                    onCheckIn: {
                        presentedSheet = .promiseCheckIn(promise)
                    }
                )
            } else {
                ContentUnavailableView(
                    "Nothing Due",
                    systemImage: "hand.raised.square",
                    description: Text("Create a promise or wait for the next check-in window.")
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var activePromisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active")
                .font(.headline)

            if viewModel.activePromises.isEmpty {
                ContentUnavailableView(
                    "No Active Promises",
                    systemImage: "hand.raised",
                    description: Text("Use New Promise to create a commitment you want to keep visible.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.activePromises) { promise in
                    PromiseCard(
                        promise: promise,
                        isDue: viewModel.duePromises.contains { $0.id == promise.id },
                        onCheckIn: {
                            presentedSheet = .promiseCheckIn(promise)
                        }
                    )
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History")
                .font(.headline)

            if viewModel.promiseHistory.isEmpty {
                Text("No promise history yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.promiseHistory.prefix(5)) { promise in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: promise.outcome == .kept ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(promise.outcome == .kept ? .green : .orange)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(promise.title)
                                    .font(.subheadline.weight(.medium))
                                if let resolvedAt = promise.resolvedAt {
                                    Text(resolvedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

struct PromiseFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var startAt = Date()
    @State private var checkInAt = Date().addingTimeInterval(60 * 60)
    @State private var whyItMatters = ""
    @State private var expectedFriction = ""

    let onSave: (Promise) -> Void

    var body: some View {
        Form {
            Section("Promise") {
                TextField("Title", text: $title)
                TextField("Why it matters", text: $whyItMatters, axis: .vertical)
                TextField("Expected friction or excuse", text: $expectedFriction, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Timing") {
                DatePicker("Starts", selection: $startAt)
                DatePicker("Check In", selection: $checkInAt)
            }
        }
        .navigationTitle("New Promise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        Promise(
                            title: title,
                            notes: notes,
                            startAt: startAt,
                            checkInAt: checkInAt,
                            whyItMatters: whyItMatters,
                            expectedFriction: expectedFriction
                        )
                    )
                }
                .disabled(Promise.cleanedTitle(from: title) == nil)
            }
        }
    }
}

struct PromiseCheckInView: View {
    @Environment(\.dismiss) private var dismiss

    let promise: Promise
    let onResolve: (PromiseOutcome, String?) -> Void
    let onReset: (String, Date) -> Void

    @State private var reflection = ""
    @State private var resetTitle = ""
    @State private var resetCheckInAt = Date().addingTimeInterval(60 * 60)

    var body: some View {
        Form {
            Section("Promise") {
                Text(promise.title)
                if let whyItMatters = promise.whyItMatters {
                    Text(whyItMatters)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Check In") {
                TextField("What happened?", text: $reflection, axis: .vertical)
                Button {
                    onResolve(.kept, reflection)
                } label: {
                    Label("Kept", systemImage: "checkmark.circle.fill")
                }
                Button {
                    onResolve(.missed, reflection)
                } label: {
                    Label("Missed", systemImage: "exclamationmark.circle.fill")
                }
            }

            Section("Reset") {
                TextField("Reset promise", text: $resetTitle)
                DatePicker("Check In", selection: $resetCheckInAt)
                Button {
                    onReset(resetTitle, resetCheckInAt)
                } label: {
                    Label("Create Reset Promise", systemImage: "arrow.clockwise")
                }
                .disabled(Promise.cleanedTitle(from: resetTitle) == nil)
            }
        }
        .navigationTitle("Check In")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            resetTitle = promise.title
        }
    }
}
