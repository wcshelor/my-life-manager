import Combine
import Charts
import SwiftUI

struct FinanceDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FinanceDashboardViewModel
    @State private var entryKind: TransactionKind?
    @State private var isShowingTransactions = false
    private let onChange: () -> Void

    init(
        financeRepository: any FinanceRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: FinanceDashboardViewModel(repository: financeRepository)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                totalsSection
                categoryOverviewCard
                transactionsCard
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Finance")
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $entryKind) { kind in
            NavigationStack {
                FinanceTransactionEntryView(
                    kind: kind,
                    categories: kind == .expense ? viewModel.expenseCategories : viewModel.incomeCategories,
                    onSaveTransaction: { amount, name, note, date, category in
                        if viewModel.saveTransaction(
                            name: name,
                            amount: amount,
                            kind: kind,
                            date: date,
                            category: category,
                            note: note
                        ) {
                            onChange()
                            entryKind = nil
                        }
                    },
                    onCreateCategoryAndSave: { amount, name, note, date, categoryName in
                        if viewModel.createCategoryAndSaveTransaction(
                            categoryName: categoryName,
                            transactionName: name,
                            amount: amount,
                            kind: kind,
                            date: date,
                            note: note
                        ) {
                            onChange()
                            entryKind = nil
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingTransactions) {
            NavigationStack {
                FinanceTransactionListView(
                    month: viewModel.selectedMonth,
                    transactions: viewModel.transactions,
                    onDelete: { transaction in
                        viewModel.deleteTransaction(withID: transaction.id)
                        onChange()
                    }
                )
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

    private var header: some View {
        HStack {
            Button {
                viewModel.selectPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(viewModel.monthTitle)
                .font(.headline)

            Spacer()

            Button {
                viewModel.selectNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var totalsSection: some View {
        HStack(spacing: 12) {
            totalCard(title: "Income", amount: viewModel.monthSummary.income, color: .green)
            totalCard(title: "Expenses", amount: viewModel.monthSummary.expenses, color: .red)
            totalCard(title: "Balance", amount: viewModel.monthSummary.balance, color: .blue, signed: true)
        }
    }

    private var categoryOverviewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Category Spending")
                    .font(.headline)
                Spacer()
            }

            if viewModel.spendingBreakdown.isEmpty {
                ContentUnavailableView(
                    "No Expenses This Month",
                    systemImage: "chart.pie",
                    description: Text("Add an expense to see category spending.")
                )
                .frame(height: 240)
            } else {
                Chart(viewModel.spendingBreakdown) { slice in
                    SectorMark(
                        angle: .value("Amount", NSDecimalNumber(decimal: slice.amount).doubleValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", slice.displayName))
                }
                .frame(height: 240)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.spendingBreakdown.prefix(5)) { slice in
                        HStack {
                            Text(slice.displayName)
                            Spacer()
                            Text(FinanceFormatting.currencyString(from: slice.amount))
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.headline)
            Button {
                isShowingTransactions = true
            } label: {
                HStack {
                    Label("Transactions", systemImage: "list.bullet")
                    Spacer()
                    Text("\(viewModel.monthSummary.transactionCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionButtons: some View {
        HStack(spacing: 32) {
            actionButton(symbol: "minus", color: .red) {
                entryKind = .expense
            }

            actionButton(symbol: "plus", color: .green) {
                entryKind = .income
            }
        }
        .padding(.bottom, 12)
    }

    private func totalCard(title: String, amount: Decimal, color: Color, signed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(
                signed
                    ? FinanceFormatting.signedCurrencyString(from: amount)
                    : FinanceFormatting.currencyString(from: amount)
            )
            .font(.headline.weight(.semibold))
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionButton(symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(color, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
