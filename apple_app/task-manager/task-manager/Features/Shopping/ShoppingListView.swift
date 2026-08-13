import Combine
import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShoppingListViewModel
    private let shoppingRepository: any ShoppingRepository
    @State private var listMode: ShoppingListMode = .active
    @State private var searchText = ""
    @State private var editingItem: ShoppingItem?
    @State private var isPresentingAddSheet = false
    @State private var creatingListName = ""

    private let onChange: () -> Void

    init(
        shoppingRepository: any ShoppingRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        self.shoppingRepository = shoppingRepository
        _viewModel = StateObject(
            wrappedValue: ShoppingListViewModel(shoppingRepository: shoppingRepository)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Shopping View", selection: $listMode) {
                ForEach(ShoppingListMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if listMode == .active {
                addButtonRow
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            content
        }
        .navigationTitle("Shopping")
        .searchable(text: $searchText, prompt: "Search shopping")
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ShoppingItemFormSheet(
                    title: "Edit Shopping Item",
                    shoppingRepository: shoppingRepository,
                    initialItem: item
                ) { updatedItem in
                    viewModel.saveItem(updatedItem, replacingItemWithID: item.id)
                    onChange()
                    editingItem = nil
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            NavigationStack {
                ShoppingItemFormSheet(
                    title: "Add Shopping Item",
                    shoppingRepository: shoppingRepository,
                    initialItem: ShoppingItem(title: "", listName: creatingListName)
                ) { newItem in
                    viewModel.saveItem(newItem)
                    onChange()
                    isPresentingAddSheet = false
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch listMode {
        case .active:
            activeList
        case .history:
            historyList
        }
    }

    private var addButtonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.availableListNames(searchText: searchText), id: \.self) { listName in
                    Button {
                        creatingListName = listName
                        isPresentingAddSheet = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.title3)
                            Text(listName)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 88, height: 88)
                        .foregroundStyle(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    creatingListName = ""
                    isPresentingAddSheet = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.title3)
                        Text("New List")
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 88, height: 88)
                    .foregroundStyle(.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.secondary)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    private var activeList: some View {
        let groups = viewModel.activeTripGroups(searchText: searchText)

        return Group {
            if viewModel.activeItems.isEmpty {
                ContentUnavailableView(
                    "No Shopping Items",
                    systemImage: "cart",
                    description: Text("Tap the plus button to add something to a list.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                ContentUnavailableView(
                    "No Matching Items",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                ShoppingItemRow(item: item)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingItem = item
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            viewModel.markBought(withID: item.id)
                                            onChange()
                                        } label: {
                                            Label("Bought", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            viewModel.skipItem(withID: item.id)
                                            onChange()
                                        } label: {
                                            Label("Skip", systemImage: "forward.end.fill")
                                        }
                                        .tint(.orange)

                                        Button(role: .destructive) {
                                            viewModel.archiveItem(withID: item.id)
                                            onChange()
                                        } label: {
                                            Label("Archive", systemImage: "archivebox.fill")
                                        }
                                    }
                            }
                        } header: {
                            Text("\(group.title) (\(group.items.count))")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var historyList: some View {
        let items = viewModel.history(searchText: searchText)

        return Group {
            if viewModel.historyItems.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Bought and skipped items will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView(
                    "No Matching History",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        ShoppingItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingItem = item
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    viewModel.reopenItem(withID: item.id)
                                    listMode = .active
                                    onChange()
                                } label: {
                                    Label("Reopen", systemImage: "arrow.uturn.backward.circle.fill")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteItem(withID: item.id)
                                    onChange()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

private enum ShoppingListMode: String, CaseIterable, Identifiable {
    case active
    case history

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .history:
            return "History"
        }
    }
}

private struct ShoppingItemRow: View {
    let item: ShoppingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.title)
                    .font(.body.weight(.semibold))

                Spacer()

                Text(item.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 8) {
                Label(item.listName, systemImage: "square.grid.2x2")
                if let price = item.price {
                    Label(price.formatted(.currency(code: "EUR")), systemImage: "eurosign.circle")
                }
                if let quantity = item.quantity {
                    Label(quantity, systemImage: "number")
                }
                if let storeName = item.storeName {
                    Label(storeName, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let notes = item.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch item.status {
        case .needed:
            return .blue
        case .bought:
            return .green
        case .skipped:
            return .orange
        case .archived:
            return .secondary
        }
    }
}

struct ShoppingItemFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let shoppingRepository: any ShoppingRepository
    let initialItem: ShoppingItem
    let onSave: (ShoppingItem) -> Void

    @State private var name = ""
    @State private var listName = "General"
    @State private var priceText = ""
    @State private var notes = ""
    @State private var quantity = ""
    @State private var storeName = ""
    @State private var listOptions: [String] = []
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case price
        case notes
        case quantity
        case store
    }

    init(
        title: String,
        shoppingRepository: any ShoppingRepository,
        initialItem: ShoppingItem,
        onSave: @escaping (ShoppingItem) -> Void
    ) {
        self.title = title
        self.shoppingRepository = shoppingRepository
        self.initialItem = initialItem
        self.onSave = onSave
        _name = State(initialValue: initialItem.title)
        _listName = State(initialValue: initialItem.listName)
        _priceText = State(initialValue: initialItem.price.map { String(describing: $0) } ?? "")
        _notes = State(initialValue: initialItem.notes ?? "")
        _quantity = State(initialValue: initialItem.quantity ?? "")
        _storeName = State(initialValue: initialItem.storeName ?? "")
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                TextField("Price", text: $priceText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .price)
            }

            Section("List") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(listOptions, id: \.self) { option in
                            listChip(option)
                        }

                        Button {
                            listName = ""
                            focusedField = .name
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("New")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(width: 88, height: 88)
                            .foregroundStyle(.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(.secondary)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

                TextField("List name", text: $listName)
                    .focused($focusedField, equals: .name)
            }

            Section("Details") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .notes)
                TextField("Quantity", text: $quantity)
                    .focused($focusedField, equals: .quantity)
                TextField("Store", text: $storeName)
                    .focused($focusedField, equals: .store)
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
                Button("Save") {
                    save()
                }
                .disabled(ShoppingItem.cleanedTitle(from: name) == nil)
            }
        }
        .task {
            listOptions = viewModelListOptions()
            focusedField = .name
        }
    }

    private func viewModelListOptions() -> [String] {
        let stored = (try? shoppingRepository.fetchShoppingItems(includeHistory: true)) ?? []
        let names = Set(stored.map(\.listName).filter { $0.isEmpty == false })
        return Array(names).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func listChip(_ text: String) -> some View {
        Button {
            listName = text
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                Text(text)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 88, height: 88)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(listName == text ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(listName == text ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let cleanedName = ShoppingItem.cleanedTitle(from: name)
        guard let cleanedName else {
            return
        }

        let price = Decimal(string: priceText.trimmingCharacters(in: .whitespacesAndNewlines))
        let item = ShoppingItem(
            id: initialItem.id,
            title: cleanedName,
            listName: listName,
            price: price,
            notes: notes,
            quantity: quantity,
            storeName: storeName,
            status: initialItem.status,
            createdAt: initialItem.createdAt,
            updatedAt: .now,
            completedAt: initialItem.completedAt
        )

        onSave(item)
    }
}

nonisolated struct ShoppingItemFormData: Equatable, Sendable {
    var title: String
    var listName: String
    var priceText: String
    var notes: String
    var quantity: String
    var storeName: String

    init(
        title: String = "",
        listName: String = "General",
        priceText: String = "",
        notes: String = "",
        quantity: String = "",
        storeName: String = ""
    ) {
        self.title = title
        self.listName = listName
        self.priceText = priceText
        self.notes = notes
        self.quantity = quantity
        self.storeName = storeName
    }

    init(
        title: String = "",
        notes: String = "",
        category: String = "",
        storeType: String = "",
        storeName: String = "",
        urgency: ShoppingUrgency = .nextTrip,
        necessity: ShoppingNecessity = .necessary
    ) {
        self.init(
            title: title,
            listName: category.isEmpty ? "General" : category,
            priceText: "",
            notes: notes,
            quantity: storeType,
            storeName: storeName
        )
        _ = urgency
        _ = necessity
    }

    init(item: ShoppingItem) {
        self.init(
            title: item.title,
            listName: item.listName,
            priceText: item.price.map { String(describing: $0) } ?? "",
            notes: item.notes ?? "",
            quantity: item.quantity ?? "",
            storeName: item.storeName ?? ""
        )
    }

    func makeItem(
        id: UUID = UUID(),
        status: ShoppingItemStatus = .needed,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil
    ) -> ShoppingItem? {
        guard ShoppingItem.cleanedTitle(from: title) != nil else {
            return nil
        }

        return ShoppingItem(
            id: id,
            title: title,
            listName: listName,
            price: Decimal(string: priceText.trimmingCharacters(in: .whitespacesAndNewlines)),
            notes: notes,
            quantity: quantity,
            storeName: storeName,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }
}
