import Combine
import SwiftUI

struct FinanceTransactionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FinanceTransactionEntryViewModel
    @State private var isShowingCategoryPicker = false

    let categories: [FinanceCategory]
    let onSaveTransaction: (Decimal, String?, String?, Date, FinanceCategory) -> Void
    let onCreateCategoryAndSave: (Decimal, String?, String?, Date, String) -> Void

    init(
        kind: TransactionKind,
        categories: [FinanceCategory],
        onSaveTransaction: @escaping (Decimal, String?, String?, Date, FinanceCategory) -> Void,
        onCreateCategoryAndSave: @escaping (Decimal, String?, String?, Date, String) -> Void
    ) {
        self.categories = categories
        self.onSaveTransaction = onSaveTransaction
        self.onCreateCategoryAndSave = onCreateCategoryAndSave
        _viewModel = StateObject(wrappedValue: FinanceTransactionEntryViewModel(kind: kind))
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Amount", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                TextField("Title (Optional)", text: $viewModel.transactionName)
                TextField("Note (Optional)", text: $viewModel.note, axis: .vertical)
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            }

            Section {
                Button("Choose Category") {
                    isShowingCategoryPicker = true
                }
                .disabled(viewModel.canChooseCategory == false)
            } footer: {
                Text("Selecting a category saves the \(viewModel.kind.displayName.lowercased()) immediately.")
            }
        }
        .navigationTitle(viewModel.kind.displayName)
        .navigationDestination(isPresented: $isShowingCategoryPicker) {
            FinanceCategoryPickerView(
                kind: viewModel.kind,
                categories: categories,
                newCategoryName: $viewModel.newCategoryName,
                canCreateCategory: viewModel.canCreateCategory,
                onSelectCategory: { category in
                    guard let amount = viewModel.parsedAmount else {
                        return
                    }
                    onSaveTransaction(
                        amount,
                        viewModel.cleanedTransactionName,
                        viewModel.cleanedNote,
                        viewModel.date,
                        category
                    )
                },
                onCreateCategory: {
                    guard let amount = viewModel.parsedAmount else {
                        return
                    }
                    onCreateCategoryAndSave(
                        amount,
                        viewModel.cleanedTransactionName,
                        viewModel.cleanedNote,
                        viewModel.date,
                        viewModel.newCategoryName
                    )
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

private struct FinanceCategoryPickerView: View {
    @State private var isShowingNewCategorySheet = false

    let kind: TransactionKind
    let categories: [FinanceCategory]
    @Binding var newCategoryName: String
    let canCreateCategory: Bool
    let onSelectCategory: (FinanceCategory) -> Void
    let onCreateCategory: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { category in
                    Button {
                        onSelectCategory(category)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: category.iconName ?? defaultIconName)
                                .font(.title3)
                            Text(category.name)
                                .font(.footnote.weight(.medium))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .padding(.horizontal, 8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Choose Category")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewCategorySheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewCategorySheet) {
            NavigationStack {
                Form {
                    TextField("Category name", text: $newCategoryName)
                }
                .navigationTitle("New Category")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingNewCategorySheet = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            onCreateCategory()
                            isShowingNewCategorySheet = false
                        }
                        .disabled(canCreateCategory == false)
                    }
                }
            }
        }
    }

    private var defaultIconName: String {
        kind == .income ? "arrow.down.circle" : "arrow.up.circle"
    }
}
