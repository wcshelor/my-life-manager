import Foundation
import SwiftData

@Model
final class AlertTemplateRecord {
    var id: UUID = UUID()
    var title: String = ""
    var targetData: Data = Data()
    var triggerData: Data = Data()
    var urgencyRawValue: String = AlertUrgency.normal.rawValue
    var privacyModeRawValue: String = AlertPrivacyMode.full.rawValue
    var actionsData: Data = Data()
    var isEnabled: Bool = true
    var snoozeMinutes: Int = 15
    var maxSnoozes: Int = 3
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(template: AlertTemplate) {
        update(from: template)
    }

    var template: AlertTemplate {
        AlertTemplate(
            id: id,
            title: title,
            target: Self.decode(AlertTarget.self, from: targetData) ?? .openRoutine(UUID()),
            trigger: Self.decode(AlertTrigger.self, from: triggerData) ?? .fixedTime(AlertFixedTimeTrigger(hour: 9, minute: 0)),
            urgency: AlertUrgency(rawValue: urgencyRawValue) ?? .normal,
            privacyMode: AlertPrivacyMode(rawValue: privacyModeRawValue) ?? .full,
            actions: Self.decode([AlertAction].self, from: actionsData) ?? AlertAction.canonical,
            isEnabled: isEnabled,
            snoozeMinutes: snoozeMinutes,
            maxSnoozes: maxSnoozes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from template: AlertTemplate) {
        id = template.id
        title = template.title
        targetData = Self.encode(template.target)
        triggerData = Self.encode(template.trigger)
        urgencyRawValue = template.urgency.rawValue
        privacyModeRawValue = template.privacyMode.rawValue
        actionsData = Self.encode(template.actions)
        isEnabled = template.isEnabled
        snoozeMinutes = template.snoozeMinutes
        maxSnoozes = template.maxSnoozes
        createdAt = template.createdAt
        updatedAt = template.updatedAt
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
