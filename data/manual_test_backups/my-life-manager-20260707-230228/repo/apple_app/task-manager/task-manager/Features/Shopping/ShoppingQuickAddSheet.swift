import SwiftUI

struct ShoppingQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var title = ""

    let onSave: () -> Void

    init(
        shoppingRepository: any ShoppingRepository,
        onSave: @escaping () -> Void
    ) {
        self.onSave = onSave
        _viewModel = StateObject(
            wrappedValue: ShoppingListViewModel(shoppingRepository: shoppingRepository)
        )
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Add item", text: $title)
                    .submitLabel(.done)
                    .onSubmit(save)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Shopping Item")
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
                .disabled(ShoppingItem.cleanedTitle(from: title) == nil)
            }
        }
        .task {
            viewModel.load()
        }
    }

    private func save() {
        guard let item = ShoppingItem(newTitle: title, createdAt: .now) else {
            return
        }

        viewModel.saveItem(item)
        onSave()
        dismiss()
    }
}
