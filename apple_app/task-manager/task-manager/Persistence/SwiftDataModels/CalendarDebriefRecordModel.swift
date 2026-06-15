import Foundation
import SwiftData

// Declaration defaults preserve lightweight migration for existing stores.
@Model
final class CalendarDebriefRecordModel {
    var id: UUID = Foundation.UUID()
    var sourceTypeRawValue: String = "calendarBlock"
    var sourceID: String?
    var sourceContext: String?
    var eventKey: String = ""
    var eventIdentifier: String?
    var calendarIdentifier: String?
    var calendarTitleSnapshot: String = ""
    var titleSnapshot: String = ""
    var startDateSnapshot: Date = Foundation.Date.distantPast
    var endDateSnapshot: Date = Foundation.Date.distantPast
    var templateKindRawValue: String = "workBlock"
    var createdAt: Date = Foundation.Date.distantPast
    var updatedAt: Date = Foundation.Date.distantPast
    var completedAt: Date?
    var statusRawValue: String = "pending"
    var noDebriefNeeded: Bool = false
    var quickOutcomeRawValue: String?
    var quickNote: String?
    var essentialNote: String?
    var detailedResponsesData: Data = Foundation.Data()
    var createdCaptureIDsData: Data = Foundation.Data()

    var workPlannedOutcomeRawValue: String?
    var workProductivityRating: Int?
    var workWhatHappened: String?
    var workBlockersRawValueText: String = ""
    var workBlockLengthFitRawValue: String?
    var workEnergyBeforeRating: Int?
    var workEnergyAfterRating: Int?
    var workFocusQualityRating: Int?
    var workNextStep: String?

    var meetingOutcomes: String?
    var meetingFollowUps: String?
    var meetingUsefulnessRating: Int?
    var meetingDecisions: String?
    var meetingOpenQuestions: String?
    var meetingDeadlines: String?
    var meetingPreparednessRating: Int?
    var meetingPeopleInvolved: String?
    var meetingRememberBeforeNext: String?

    var socialWorthRemembering: String?
    var socialFollowUp: String?
    var socialMoodRawValue: String?
    var socialWhoWasThere: String?
    var socialLearnedAboutSomeone: String?
    var socialPromised: String?
    var socialDifferentNextTime: String?
    var socialNourishmentRawValue: String?
    var taskOutcomesData: Data = Foundation.Data()

    init(debrief: CalendarDebriefRecord) {
        update(from: debrief)
    }

    var debrief: CalendarDebriefRecord {
        CalendarDebriefRecord(
            id: id,
            sourceType: DebriefSourceType(rawValue: sourceTypeRawValue) ?? .calendarBlock,
            sourceID: sourceID,
            sourceContext: sourceContext,
            eventKey: eventKey,
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier,
            calendarTitleSnapshot: calendarTitleSnapshot,
            titleSnapshot: titleSnapshot,
            startDateSnapshot: startDateSnapshot,
            endDateSnapshot: endDateSnapshot,
            templateKind: DebriefTemplateKind(rawValue: templateKindRawValue) ?? .workBlock,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            status: CalendarDebriefStatus(rawValue: statusRawValue) ?? .pending,
            noDebriefNeeded: noDebriefNeeded,
            quickOutcome: quickOutcomeRawValue.flatMap(DebriefQuickOutcome.init(rawValue:)),
            quickNote: quickNote,
            essentialNote: essentialNote,
            detailedResponses: decodedDetailedResponses,
            createdCaptureIDs: decodedCaptureIDs,
            workPlannedOutcome: workPlannedOutcomeRawValue.flatMap(WorkBlockPlannedOutcome.init(rawValue:)),
            workProductivityRating: workProductivityRating,
            workWhatHappened: workWhatHappened,
            workBlockers: decodedWorkBlockers,
            workBlockLengthFit: workBlockLengthFitRawValue.flatMap(WorkBlockLengthFit.init(rawValue:)),
            workEnergyBeforeRating: workEnergyBeforeRating,
            workEnergyAfterRating: workEnergyAfterRating,
            workFocusQualityRating: workFocusQualityRating,
            workNextStep: workNextStep,
            meetingOutcomes: meetingOutcomes,
            meetingFollowUps: meetingFollowUps,
            meetingUsefulnessRating: meetingUsefulnessRating,
            meetingDecisions: meetingDecisions,
            meetingOpenQuestions: meetingOpenQuestions,
            meetingDeadlines: meetingDeadlines,
            meetingPreparednessRating: meetingPreparednessRating,
            meetingPeopleInvolved: meetingPeopleInvolved,
            meetingRememberBeforeNext: meetingRememberBeforeNext,
            socialWorthRemembering: socialWorthRemembering,
            socialFollowUp: socialFollowUp,
            socialMood: socialMoodRawValue.flatMap(SocialDebriefMood.init(rawValue:)),
            socialWhoWasThere: socialWhoWasThere,
            socialLearnedAboutSomeone: socialLearnedAboutSomeone,
            socialPromised: socialPromised,
            socialDifferentNextTime: socialDifferentNextTime,
            socialNourishment: socialNourishmentRawValue.flatMap(SocialDebriefNourishment.init(rawValue:)),
            taskOutcomes: decodedTaskOutcomes
        )
    }

    func update(from debrief: CalendarDebriefRecord) {
        id = debrief.id
        sourceTypeRawValue = debrief.sourceType.rawValue
        sourceID = debrief.sourceID
        sourceContext = debrief.sourceContext
        eventKey = debrief.eventKey
        eventIdentifier = debrief.eventIdentifier
        calendarIdentifier = debrief.calendarIdentifier
        calendarTitleSnapshot = debrief.calendarTitleSnapshot
        titleSnapshot = debrief.titleSnapshot
        startDateSnapshot = debrief.startDateSnapshot
        endDateSnapshot = debrief.endDateSnapshot
        templateKindRawValue = debrief.templateKind.rawValue
        createdAt = debrief.createdAt
        updatedAt = debrief.updatedAt
        completedAt = debrief.completedAt
        statusRawValue = debrief.status.rawValue
        noDebriefNeeded = debrief.noDebriefNeeded
        quickOutcomeRawValue = debrief.quickOutcome?.rawValue
        quickNote = debrief.quickNote
        essentialNote = debrief.essentialNote
        detailedResponsesData = (try? JSONEncoder().encode(debrief.detailedResponses)) ?? Data()
        createdCaptureIDsData = (try? JSONEncoder().encode(debrief.createdCaptureIDs)) ?? Data()

        workPlannedOutcomeRawValue = debrief.workPlannedOutcome?.rawValue
        workProductivityRating = debrief.workProductivityRating
        workWhatHappened = debrief.workWhatHappened
        workBlockersRawValueText = debrief.workBlockers.map(\.rawValue).joined(separator: "\n")
        workBlockLengthFitRawValue = debrief.workBlockLengthFit?.rawValue
        workEnergyBeforeRating = debrief.workEnergyBeforeRating
        workEnergyAfterRating = debrief.workEnergyAfterRating
        workFocusQualityRating = debrief.workFocusQualityRating
        workNextStep = debrief.workNextStep

        meetingOutcomes = debrief.meetingOutcomes
        meetingFollowUps = debrief.meetingFollowUps
        meetingUsefulnessRating = debrief.meetingUsefulnessRating
        meetingDecisions = debrief.meetingDecisions
        meetingOpenQuestions = debrief.meetingOpenQuestions
        meetingDeadlines = debrief.meetingDeadlines
        meetingPreparednessRating = debrief.meetingPreparednessRating
        meetingPeopleInvolved = debrief.meetingPeopleInvolved
        meetingRememberBeforeNext = debrief.meetingRememberBeforeNext

        socialWorthRemembering = debrief.socialWorthRemembering
        socialFollowUp = debrief.socialFollowUp
        socialMoodRawValue = debrief.socialMood?.rawValue
        socialWhoWasThere = debrief.socialWhoWasThere
        socialLearnedAboutSomeone = debrief.socialLearnedAboutSomeone
        socialPromised = debrief.socialPromised
        socialDifferentNextTime = debrief.socialDifferentNextTime
        socialNourishmentRawValue = debrief.socialNourishment?.rawValue
        taskOutcomesData = (try? JSONEncoder().encode(debrief.taskOutcomes)) ?? Data()
    }

    private var decodedCaptureIDs: [UUID] {
        (try? JSONDecoder().decode([UUID].self, from: createdCaptureIDsData)) ?? []
    }

    private var decodedDetailedResponses: [DebriefPromptResponse] {
        (try? JSONDecoder().decode([DebriefPromptResponse].self, from: detailedResponsesData)) ?? []
    }

    private var decodedWorkBlockers: [WorkBlockBlocker] {
        workBlockersRawValueText
            .split(separator: "\n")
            .compactMap { WorkBlockBlocker(rawValue: String($0)) }
    }

    private var decodedTaskOutcomes: [DebriefTaskOutcome] {
        (try? JSONDecoder().decode([DebriefTaskOutcome].self, from: taskOutcomesData)) ?? []
    }
}
