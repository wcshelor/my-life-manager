import Foundation

nonisolated enum TransactionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income:
            return "Income"
        case .expense:
            return "Expense"
        }
    }

    var signSymbol: String {
        switch self {
        case .income:
            return "+"
        case .expense:
            return "-"
        }
    }
}

nonisolated struct FinanceCategory: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var kind: TransactionKind?
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int
    var isArchived: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: TransactionKind? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.colorHex = MyTask.cleanedOptionalText(from: colorHex)
        self.iconName = MyTask.cleanedOptionalText(from: iconName)
        self.sortOrder = max(0, sortOrder)
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    static func cleanedName(from rawName: String) -> String? {
        let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedName.isEmpty ? nil : cleanedName
    }
}

nonisolated struct FinanceTransaction: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String?
    var amount: Decimal
    var kind: TransactionKind
    var date: Date
    var category: FinanceCategory?
    var note: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String? = nil,
        amount: Decimal,
        kind: TransactionKind,
        date: Date = .now,
        category: FinanceCategory? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name.flatMap(Self.cleanedName(from:))
        self.amount = Self.cleanedAmount(amount)
        self.kind = kind
        self.date = date
        self.category = category
        self.note = MyTask.cleanedOptionalText(from: note)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var signedAmount: Decimal {
        kind == .income ? amount : -amount
    }

    static func cleanedName(from rawName: String) -> String? {
        let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedName.isEmpty ? nil : cleanedName
    }

    static func cleanedAmount(_ amount: Decimal) -> Decimal {
        amount < 0 ? -amount : amount
    }
}

extension FinanceCategory {
    static let defaultSeedCategories: [(name: String, kind: TransactionKind)] = [
        ("Bills", .expense),
        ("Car", .expense),
        ("Clothes", .expense),
        ("Communication", .expense),
        ("Eating Out", .expense),
        ("Entertainment", .expense),
        ("Food", .expense),
        ("Gifts", .expense),
        ("Health", .expense),
        ("House", .expense),
        ("Pets", .expense),
        ("Sports", .expense),
        ("Taxi", .expense),
        ("Toiletry", .expense),
        ("Transport", .expense),
        ("Salary", .income),
        ("Gift", .income),
        ("Other", .income),
    ]
}
