import Combine
import Foundation

@MainActor
final class FinanceTransactionEntryViewModel: ObservableObject {
    @Published var amountText = ""
    @Published var transactionName = ""
    @Published var note = ""
    @Published var date: Date
    @Published var newCategoryName = ""

    let kind: TransactionKind

    init(kind: TransactionKind, date: Date = .now) {
        self.kind = kind
        self.date = date
    }

    var parsedAmount: Decimal? {
        FinanceFormatting.decimal(from: amountText)
    }

    var cleanedTransactionName: String? {
        FinanceTransaction.cleanedName(from: transactionName)
    }

    var cleanedNote: String? {
        MyTask.cleanedOptionalText(from: note)
    }

    var canChooseCategory: Bool {
        parsedAmount != nil
    }

    var canCreateCategory: Bool {
        canChooseCategory && FinanceCategory.cleanedName(from: newCategoryName) != nil
    }
}
