import Foundation
import SwiftData

@Model
final class ShoppingItemRecord {
    var id: UUID = UUID()
    var title: String = ""
    var listName: String = "General"
    var priceAmount: String?
    var notes: String?
    var storeName: String?
    var quantity: String?
    var statusRawValue: String = ShoppingItemStatus.needed.rawValue
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var completedAt: Date?

    init(item: ShoppingItem) {
        update(from: item)
    }

    var item: ShoppingItem {
        ShoppingItem(
            id: id,
            title: title,
            listName: listName,
            price: priceAmount.flatMap(Decimal.init(string:)),
            notes: notes,
            storeName: storeName,
            quantity: quantity,
            status: ShoppingItemStatus(rawValue: statusRawValue) ?? .needed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }

    func update(from item: ShoppingItem) {
        id = item.id
        title = item.title
        listName = item.listName
        priceAmount = item.price.map(String.init(describing:))
        notes = item.notes
        storeName = item.storeName
        quantity = item.quantity
        statusRawValue = item.status.rawValue
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        completedAt = item.completedAt
    }
}
