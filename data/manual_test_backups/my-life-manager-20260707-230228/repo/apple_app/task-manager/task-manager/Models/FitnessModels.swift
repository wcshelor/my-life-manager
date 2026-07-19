import Foundation

nonisolated enum FitnessTag: String, CaseIterable, Codable, Hashable, Sendable {
    case legs
    case push
    case pull
    case cardio

    var displayName: String {
        rawValue.capitalized
    }
}

nonisolated enum ExerciseTrackingStyle: String, CaseIterable, Codable, Hashable, Sendable {
    case strengthSets
    case metricSummary
    case stationaryBike
    case normalBike
    case walk

    var displayName: String {
        switch self {
        case .strengthSets:
            return "Strength Sets"
        case .metricSummary:
            return "Custom Metrics"
        case .stationaryBike:
            return "Stationary Bike"
        case .normalBike:
            return "Normal Bike"
        case .walk:
            return "Walk"
        }
    }

    var metricFields: [SelectableMetricField] {
        switch self {
        case .strengthSets:
            return []
        case .metricSummary:
            return []
        case .stationaryBike:
            return [.durationMinutes, .difficultyLevel, .averageRPM, .distance]
        case .normalBike:
            return [.durationMinutes, .distance]
        case .walk:
            return [.durationMinutes, .distance]
        }
    }
}

nonisolated enum SelectableMetricField: String, CaseIterable, Codable, Hashable, Sendable {
    case durationMinutes
    case difficultyLevel
    case averageRPM
    case distance

    var displayName: String {
        switch self {
        case .durationMinutes:
            return "Duration"
        case .difficultyLevel:
            return "Difficulty"
        case .averageRPM:
            return "Average RPM"
        case .distance:
            return "Distance"
        }
    }
}

nonisolated enum WeightUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case pounds
    case kilograms

    var displayName: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }
}

nonisolated enum DistanceUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case miles
    case kilometers

    var displayName: String {
        switch self {
        case .miles:
            return "mi"
        case .kilometers:
            return "km"
        }
    }
}

nonisolated enum ExerciseSortOption: String, CaseIterable, Codable, Hashable, Sendable {
    case recent
    case alphabetical
    case tag

    var displayName: String {
        switch self {
        case .recent:
            return "Recent"
        case .alphabetical:
            return "A-Z"
        case .tag:
            return "Tag"
        }
    }
}

nonisolated struct StrengthSet: Equatable, Codable, Sendable {
    var reps: Double
    var weight: Double?

    init(reps: Double, weight: Double? = nil) {
        self.reps = max(0, reps)
        self.weight = weight.map { max(0, $0) }
    }

    var isMeaningful: Bool {
        reps > 0 || weight != nil
    }

    var repsText: String {
        Self.numberText(reps)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let reps = try? container.decode(Double.self, forKey: .reps) {
            self.reps = max(0, reps)
        } else if let reps = try? container.decode(Int.self, forKey: .reps) {
            self.reps = max(0, Double(reps))
        } else {
            self.reps = 0
        }
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight).map { max(0, $0) }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if reps.rounded() == reps {
            try container.encode(Int(reps), forKey: .reps)
        } else {
            try container.encode(reps, forKey: .reps)
        }
        try container.encodeIfPresent(weight, forKey: .weight)
    }

    private enum CodingKeys: String, CodingKey {
        case reps
        case weight
    }

    private static func numberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }
}

nonisolated struct FitnessExercise: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var tag: FitnessTag
    var trackingStyle: ExerciseTrackingStyle
    var selectableMetricFields: [SelectableMetricField]
    var weightUnit: WeightUnit?
    var distanceUnit: DistanceUnit?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        tag: FitnessTag,
        trackingStyle: ExerciseTrackingStyle,
        selectableMetricFields: [SelectableMetricField] = [],
        weightUnit: WeightUnit? = nil,
        distanceUnit: DistanceUnit? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tag = tag
        self.trackingStyle = trackingStyle
        self.selectableMetricFields = Self.cleanedMetricFields(
            selectableMetricFields,
            trackingStyle: trackingStyle
        )
        self.weightUnit = Self.cleanedWeightUnit(
            weightUnit,
            trackingStyle: trackingStyle
        )
        self.distanceUnit = Self.cleanedDistanceUnit(
            distanceUnit,
            trackingStyle: trackingStyle,
            selectableMetricFields: selectableMetricFields
        )
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(
        newName: String,
        tag: FitnessTag,
        trackingStyle: ExerciseTrackingStyle,
        selectableMetricFields: [SelectableMetricField] = [],
        weightUnit: WeightUnit? = nil,
        distanceUnit: DistanceUnit? = nil,
        createdAt: Date = .now
    ) {
        guard let cleanedName = Self.cleanedName(from: newName),
              Self.isConfigurationValid(
                trackingStyle: trackingStyle,
                selectableMetricFields: selectableMetricFields,
                weightUnit: weightUnit,
                distanceUnit: distanceUnit
              ) else {
            return nil
        }

        self.init(
            name: cleanedName,
            tag: tag,
            trackingStyle: trackingStyle,
            selectableMetricFields: selectableMetricFields,
            weightUnit: weightUnit,
            distanceUnit: distanceUnit,
            createdAt: createdAt
        )
    }

    var usesDistance: Bool {
        metricFields.contains(.distance)
    }

    var metricFields: [SelectableMetricField] {
        trackingStyle == .metricSummary ? selectableMetricFields : trackingStyle.metricFields
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }

    static func cleanedMetricFields(
        _ fields: [SelectableMetricField],
        trackingStyle: ExerciseTrackingStyle
    ) -> [SelectableMetricField] {
        guard trackingStyle == .metricSummary else {
            return []
        }

        let fieldSet = Set(fields)
        return SelectableMetricField.allCases.filter { fieldSet.contains($0) }
    }

    static func cleanedWeightUnit(
        _ weightUnit: WeightUnit?,
        trackingStyle: ExerciseTrackingStyle
    ) -> WeightUnit? {
        trackingStyle == .strengthSets ? weightUnit : nil
    }

    static func cleanedDistanceUnit(
        _ distanceUnit: DistanceUnit?,
        trackingStyle: ExerciseTrackingStyle,
        selectableMetricFields: [SelectableMetricField]
    ) -> DistanceUnit? {
        let usesDistance: Bool
        if trackingStyle == .metricSummary {
            usesDistance = selectableMetricFields.contains(.distance)
        } else {
            usesDistance = trackingStyle.metricFields.contains(.distance)
        }

        guard usesDistance else {
            return nil
        }

        return distanceUnit
    }

    static func isConfigurationValid(
        trackingStyle: ExerciseTrackingStyle,
        selectableMetricFields: [SelectableMetricField],
        weightUnit: WeightUnit?,
        distanceUnit: DistanceUnit?
    ) -> Bool {
        switch trackingStyle {
        case .strengthSets:
            return weightUnit != nil
        case .metricSummary:
            let cleanedFields = cleanedMetricFields(
                selectableMetricFields,
                trackingStyle: trackingStyle
            )
            guard cleanedFields.isEmpty == false else {
                return false
            }

            if cleanedFields.contains(.distance) {
                return distanceUnit != nil
            }

            return true
        case .stationaryBike, .normalBike, .walk:
            return distanceUnit != nil
        }
    }
}

nonisolated struct WorkoutTemplate: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var exerciseIDs: [UUID]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        exerciseIDs: [UUID],
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exerciseIDs = Self.cleanedExerciseIDs(exerciseIDs)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(
        newName: String,
        exerciseIDs: [UUID],
        createdAt: Date = .now
    ) {
        guard let cleanedName = Self.cleanedName(from: newName) else {
            return nil
        }

        let cleanedExerciseIDs = Self.cleanedExerciseIDs(exerciseIDs)
        guard cleanedExerciseIDs.isEmpty == false else {
            return nil
        }

        self.init(
            name: cleanedName,
            exerciseIDs: cleanedExerciseIDs,
            createdAt: createdAt
        )
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }

    static func cleanedExerciseIDs(_ exerciseIDs: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return exerciseIDs.filter { seen.insert($0).inserted }
    }
}

nonisolated struct ExerciseSession: Identifiable, Equatable, Sendable {
    let id: UUID
    var exerciseID: UUID
    var performedAt: Date
    var strengthSets: [StrengthSet]
    var durationMinutes: Int?
    var difficultyLevel: Int?
    var averageRPM: Int?
    var distance: Double?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        performedAt: Date = .now,
        strengthSets: [StrengthSet] = [],
        durationMinutes: Int? = nil,
        difficultyLevel: Int? = nil,
        averageRPM: Int? = nil,
        distance: Double? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.performedAt = performedAt
        self.strengthSets = strengthSets.filter(\.isMeaningful)
        self.durationMinutes = durationMinutes.map { max(0, $0) }
        self.difficultyLevel = difficultyLevel.map { min(10, max(1, $0)) }
        self.averageRPM = averageRPM.map { max(0, $0) }
        self.distance = distance.map { max(0, $0) }
        self.notes = Self.cleanedNotes(notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func isForSameDay(as date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(performedAt, inSameDayAs: date)
    }

    func isValid(for exercise: FitnessExercise) -> Bool {
        switch exercise.trackingStyle {
        case .strengthSets:
            return strengthSets.isEmpty == false
        case .metricSummary, .stationaryBike, .normalBike, .walk:
            return exercise.metricFields.allSatisfy { field in
                switch field {
                case .durationMinutes:
                    return durationMinutes != nil
                case .difficultyLevel:
                    return difficultyLevel != nil
                case .averageRPM:
                    return averageRPM != nil
                case .distance:
                    return distance != nil
                }
            }
        }
    }

    var summaryText: String {
        if strengthSets.isEmpty == false {
            return strengthSets.enumerated().map { index, set in
                if let weight = set.weight {
                    return "Set \(index + 1): \(set.repsText)x\(Self.numberText(weight))"
                }

                return "Set \(index + 1): \(set.repsText) reps"
            }
            .joined(separator: " · ")
        }

        var parts: [String] = []
        if let durationMinutes {
            parts.append("\(durationMinutes)m")
        }
        if let difficultyLevel {
            parts.append("Diff \(difficultyLevel)")
        }
        if let averageRPM {
            parts.append("\(averageRPM) rpm")
        }
        if let distance {
            parts.append(Self.numberText(distance))
        }
        return parts.isEmpty ? "No metrics" : parts.joined(separator: " · ")
    }

    func draftCopy(for exercise: FitnessExercise, performedAt: Date = .now) -> ExerciseSession {
        ExerciseSession(
            exerciseID: exercise.id,
            performedAt: performedAt,
            strengthSets: exercise.trackingStyle == .strengthSets ? strengthSets : [],
            durationMinutes: exercise.metricFields.contains(.durationMinutes) ? durationMinutes : nil,
            difficultyLevel: exercise.metricFields.contains(.difficultyLevel) ? difficultyLevel : nil,
            averageRPM: exercise.metricFields.contains(.averageRPM) ? averageRPM : nil,
            distance: exercise.metricFields.contains(.distance) ? distance : nil,
            notes: notes,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private static func cleanedNotes(_ rawNotes: String?) -> String? {
        guard let rawNotes else {
            return nil
        }

        let cleaned = rawNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func numberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }
}

nonisolated struct FitnessRoute: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var distance: Double
    var distanceUnit: DistanceUnit
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        distance: Double,
        distanceUnit: DistanceUnit,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.distance = max(0, distance)
        self.distanceUnit = distanceUnit
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(
        newName: String,
        distance: Double,
        distanceUnit: DistanceUnit,
        createdAt: Date = .now
    ) {
        guard let cleanedName = Self.cleanedName(from: newName),
              distance > 0 else {
            return nil
        }

        self.init(
            name: cleanedName,
            distance: distance,
            distanceUnit: distanceUnit,
            createdAt: createdAt
        )
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }
}

extension Array where Element == ExerciseSession {
    nonisolated func sortedForExerciseHistory() -> [ExerciseSession] {
        sorted { leftSession, rightSession in
            if leftSession.performedAt != rightSession.performedAt {
                return leftSession.performedAt > rightSession.performedAt
            }

            return leftSession.id.uuidString < rightSession.id.uuidString
        }
    }
}

extension Array where Element == FitnessExercise {
    nonisolated func sortedAlphabetically() -> [FitnessExercise] {
        sorted { leftExercise, rightExercise in
            let comparison = leftExercise.name.localizedCaseInsensitiveCompare(rightExercise.name)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return leftExercise.id.uuidString < rightExercise.id.uuidString
        }
    }
}
