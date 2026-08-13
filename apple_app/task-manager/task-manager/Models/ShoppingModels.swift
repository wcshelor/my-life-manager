import Foundation

nonisolated enum ShoppingUrgency: String, CaseIterable, Codable, Sendable {
    case needSoon
    case nextTrip
    case someday
}

nonisolated enum ShoppingNecessity: String, CaseIterable, Codable, Sendable {
    case necessary
    case useful
    case optional
}

nonisolated enum ShoppingItemStatus: String, CaseIterable, Codable, Sendable {
    case needed
    case bought
    case skipped
    case archived

    var displayName: String {
        switch self {
        case .needed:
            return "Needed"
        case .bought:
            return "Bought"
        case .skipped:
            return "Skipped"
        case .archived:
            return "Archived"
        }
    }

    var isActive: Bool {
        self == .needed
    }
}

nonisolated struct ShoppingItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var listName: String
    var price: Decimal?
    var notes: String?
    var quantity: String?
    var storeName: String?
    var status: ShoppingItemStatus
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        listName: String = "General",
        price: Decimal? = nil,
        notes: String? = nil,
        quantity: String? = nil,
        storeName: String? = nil,
        status: ShoppingItemStatus = .needed,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        let cleanedUpdatedAt = updatedAt ?? createdAt

        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.listName = Self.cleanedTitle(from: listName) ?? "General"
        self.price = price
        self.notes = Self.cleanedOptionalText(from: notes)
        self.quantity = Self.cleanedOptionalText(from: quantity)
        self.storeName = Self.cleanedOptionalText(from: storeName)
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = cleanedUpdatedAt
        self.completedAt = status.isActive ? nil : (completedAt ?? cleanedUpdatedAt)
    }

    init?(newTitle: String, createdAt: Date = .now) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(title: cleanedTitle, createdAt: createdAt)
    }

    var isActive: Bool {
        status.isActive
    }

    var tripGroupName: String {
        listName
    }

    func updatingStatus(
        _ status: ShoppingItemStatus,
        at date: Date
    ) -> ShoppingItem {
        ShoppingItem(
            id: id,
            title: title,
            listName: listName,
            price: price,
            notes: notes,
            quantity: quantity,
            storeName: storeName,
            status: status,
            createdAt: createdAt,
            updatedAt: date,
            completedAt: status.isActive ? nil : date
        )
    }

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }

    static func cleanedOptionalText(from rawText: String?) -> String? {
        MyTask.cleanedOptionalText(from: rawText)
    }
}

nonisolated struct ShoppingTripGroup: Identifiable, Equatable, Sendable {
    let listName: String
    let items: [ShoppingItem]

    var id: String { listName }

    var title: String { listName }
}

extension Array where Element == ShoppingItem {
    func sortedForShoppingLists() -> [ShoppingItem] {
        sorted { leftItem, rightItem in
            let leftList = leftItem.listName.localizedLowercase
            let rightList = rightItem.listName.localizedLowercase

            if leftList != rightList {
                return leftList < rightList
            }

            if leftItem.createdAt != rightItem.createdAt {
                return leftItem.createdAt < rightItem.createdAt
            }

            return leftItem.id.uuidString < rightItem.id.uuidString
        }
    }
}
