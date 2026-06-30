import Foundation
import SwiftData

@Model
final class FitnessRouteRecord {
    var id: UUID = UUID()
    var name: String = ""
    var distance: Double = 0
    var distanceUnitRawValue: String = DistanceUnit.miles.rawValue
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(route: FitnessRoute) {
        update(from: route)
    }

    var route: FitnessRoute {
        FitnessRoute(
            id: id,
            name: name,
            distance: distance,
            distanceUnit: DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from route: FitnessRoute) {
        id = route.id
        name = route.name
        distance = route.distance
        distanceUnitRawValue = route.distanceUnit.rawValue
        createdAt = route.createdAt
        updatedAt = route.updatedAt
    }
}
