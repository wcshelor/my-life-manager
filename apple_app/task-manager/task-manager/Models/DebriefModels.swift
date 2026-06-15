import Foundation

nonisolated enum DebriefTemplateKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case generic
    case workBlock
    case meeting
    case social
    case pianoPractice
    case jamSession
    case viceSession

    var id: Self { self }

    var displayName: String {
        switch self {
        case .generic:
            return "Generic"
        case .workBlock:
            return "Work Session"
        case .meeting:
            return "Meeting"
        case .social:
            return "Social Hangout"
        case .pianoPractice:
            return "Piano Practice"
        case .jamSession:
            return "Jam Session"
        case .viceSession:
            return "Vice Session"
        }
    }
}

nonisolated enum CalendarDebriefStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
    case skipped
}

nonisolated enum DebriefSourceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case calendarBlock
    case scheduledBlock
    case viceSession
    case routine
    case workout
    case musicPracticeSession
    case meeting
    case socialHangout
    case jamSession
    case custom

    var id: Self { self }
}

nonisolated enum DebriefQuickOutcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case good
    case mid
    case bad
    case skipped
    case cancelled
    case postponed
    case useful
    case fine
    case unclear
    case draining
    case awkward
    case productive
    case okay
    case frustrating
    case fun
    case intentional
    case mixed
    case regretful

    var id: Self { self }

    var displayName: String {
        switch self {
        case .good: return "Good"
        case .mid: return "Mid"
        case .bad: return "Bad"
        case .skipped: return "Skipped"
        case .cancelled: return "Cancelled"
        case .postponed: return "Postponed"
        case .useful: return "Useful"
        case .fine: return "Fine"
        case .unclear: return "Unclear"
        case .draining: return "Draining"
        case .awkward: return "Awkward"
        case .productive: return "Productive"
        case .okay: return "Okay"
        case .frustrating: return "Frustrating"
        case .fun: return "Fun"
        case .intentional: return "Intentional"
        case .mixed: return "Mixed"
        case .regretful: return "Regretful"
        }
    }

    var completionStatus: CalendarDebriefStatus {
        self == .skipped ? .skipped : .completed
    }
}

nonisolated struct DebriefPrompt: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: String
    let prompt: String
}

nonisolated struct DebriefPromptResponse: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: String
    let prompt: String
    var response: String

    init(id: String, prompt: String, response: String) {
        self.id = id
        self.prompt = prompt
        self.response = MyTask.cleanedOptionalText(from: response) ?? ""
    }
}

nonisolated struct DebriefTemplateDefinition: Identifiable, Equatable, Sendable {
    let kind: DebriefTemplateKind
    let displayName: String
    let applicableSourceTypes: [DebriefSourceType]
    let quickOutcomes: [DebriefQuickOutcome]
    let shortPrompts: [DebriefPrompt]
    let detailedPrompts: [DebriefPrompt]

    var id: DebriefTemplateKind { kind }
}

nonisolated enum DebriefTemplates {
    static let generic = DebriefTemplateDefinition(
        kind: .generic,
        displayName: DebriefTemplateKind.generic.displayName,
        applicableSourceTypes: DebriefSourceType.allCases,
        quickOutcomes: [.good, .mid, .bad, .skipped, .cancelled, .postponed],
        shortPrompts: [DebriefPrompt(id: "note", prompt: "Anything worth noting?")],
        detailedPrompts: [
            DebriefPrompt(id: "what_happened", prompt: "What happened?"),
            DebriefPrompt(id: "what_matters", prompt: "What matters to remember?"),
            DebriefPrompt(id: "next_action", prompt: "What is the next action?")
        ]
    )

    static let workBlock = DebriefTemplateDefinition(
        kind: .workBlock,
        displayName: DebriefTemplateKind.workBlock.displayName,
        applicableSourceTypes: [.calendarBlock, .scheduledBlock, .routine, .custom],
        quickOutcomes: [.good, .mid, .bad, .skipped, .postponed, .cancelled],
        shortPrompts: [DebriefPrompt(id: "done", prompt: "What got done?")],
        detailedPrompts: [
            DebriefPrompt(id: "done", prompt: "What did you actually get done?"),
            DebriefPrompt(id: "blocked", prompt: "What blocked you?"),
            DebriefPrompt(id: "estimate", prompt: "Was the estimate realistic?"),
            DebriefPrompt(id: "next_action", prompt: "What is the next action?")
        ]
    )

    static let meeting = DebriefTemplateDefinition(
        kind: .meeting,
        displayName: DebriefTemplateKind.meeting.displayName,
        applicableSourceTypes: [.meeting],
        quickOutcomes: [.useful, .fine, .unclear, .skipped, .cancelled],
        shortPrompts: [DebriefPrompt(id: "decisions", prompt: "Any decisions or follow-ups?")],
        detailedPrompts: [
            DebriefPrompt(id: "decisions", prompt: "What decisions were made?"),
            DebriefPrompt(id: "follow_ups", prompt: "What follow-ups came out of this?"),
            DebriefPrompt(id: "needs", prompt: "Who needs something from me?"),
            DebriefPrompt(id: "remember", prompt: "Anything worth remembering?")
        ]
    )

    static let social = DebriefTemplateDefinition(
        kind: .social,
        displayName: DebriefTemplateKind.social.displayName,
        applicableSourceTypes: [.socialHangout],
        quickOutcomes: [.good, .fine, .draining, .awkward, .skipped],
        shortPrompts: [DebriefPrompt(id: "feel", prompt: "How did it feel?")],
        detailedPrompts: [
            DebriefPrompt(id: "feel", prompt: "How did I feel during/after?"),
            DebriefPrompt(id: "moments", prompt: "Any good moments?"),
            DebriefPrompt(id: "awkward", prompt: "Anything awkward or worth repairing?"),
            DebriefPrompt(id: "remember_people", prompt: "Anything to remember about the people involved?")
        ]
    )

    static let pianoPractice = DebriefTemplateDefinition(
        kind: .pianoPractice,
        displayName: DebriefTemplateKind.pianoPractice.displayName,
        applicableSourceTypes: [.musicPracticeSession],
        quickOutcomes: [.productive, .okay, .frustrating, .skipped],
        shortPrompts: [DebriefPrompt(id: "practiced", prompt: "What did I practice?")],
        detailedPrompts: [
            DebriefPrompt(id: "practiced", prompt: "What did I practice?"),
            DebriefPrompt(id: "improved", prompt: "What improved?"),
            DebriefPrompt(id: "frustrating", prompt: "What was frustrating?"),
            DebriefPrompt(id: "next_focus", prompt: "What should I focus on next time?")
        ]
    )

    static let jamSession = DebriefTemplateDefinition(
        kind: .jamSession,
        displayName: DebriefTemplateKind.jamSession.displayName,
        applicableSourceTypes: [.jamSession],
        quickOutcomes: [.fun, .productive, .okay, .awkward, .skipped],
        shortPrompts: [DebriefPrompt(id: "ideas", prompt: "What came up?")],
        detailedPrompts: [
            DebriefPrompt(id: "ideas", prompt: "What songs/ideas came up?"),
            DebriefPrompt(id: "felt_good", prompt: "What felt good musically?"),
            DebriefPrompt(id: "practice_next", prompt: "What should I practice next?"),
            DebriefPrompt(id: "people", prompt: "Who was there?")
        ]
    )

    static let viceSession = DebriefTemplateDefinition(
        kind: .viceSession,
        displayName: DebriefTemplateKind.viceSession.displayName,
        applicableSourceTypes: [.viceSession],
        quickOutcomes: [.intentional, .mixed, .regretful, .skipped],
        shortPrompts: [DebriefPrompt(id: "trigger", prompt: "What triggered it?")],
        detailedPrompts: [
            DebriefPrompt(id: "trigger", prompt: "What triggered the session?"),
            DebriefPrompt(id: "intentional", prompt: "Did it feel intentional?"),
            DebriefPrompt(id: "help", prompt: "Did it help?"),
            DebriefPrompt(id: "cost", prompt: "Did it cost me anything?"),
            DebriefPrompt(id: "next_time", prompt: "What would help next time?")
        ]
    )

    static let all: [DebriefTemplateDefinition] = [
        generic,
        workBlock,
        meeting,
        social,
        pianoPractice,
        jamSession,
        viceSession,
    ]

    static func definition(for kind: DebriefTemplateKind) -> DebriefTemplateDefinition {
        all.first(where: { $0.kind == kind }) ?? generic
    }
}

nonisolated struct DebriefTemplateInferenceService: Sendable {
    func inferredTemplate(
        sourceType: DebriefSourceType,
        title: String? = nil
    ) -> DebriefTemplateKind {
        switch sourceType {
        case .viceSession:
            return .viceSession
        case .musicPracticeSession:
            return .pianoPractice
        case .meeting:
            return .meeting
        case .socialHangout:
            return .social
        case .jamSession:
            return .jamSession
        case .calendarBlock, .scheduledBlock, .routine, .workout:
            return .workBlock
        case .custom:
            guard let title else {
                return .generic
            }
            return CalendarDebriefRecord.suggestedTemplate(for: title)
        }
    }
}

nonisolated enum WorkBlockPlannedOutcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case yes
    case mostly
    case partly
    case no
    case differentUsefulThing

    var id: Self { self }

    var displayName: String {
        switch self {
        case .yes:
            return "Yes"
        case .mostly:
            return "Mostly"
        case .partly:
            return "Partly"
        case .no:
            return "No"
        case .differentUsefulThing:
            return "Different useful thing"
        }
    }
}

nonisolated enum WorkBlockBlocker: String, Codable, CaseIterable, Identifiable, Sendable {
    case tired
    case distracted
    case unclearNextStep
    case underestimatedTask
    case interrupted
    case avoidance
    case wrongEnvironment
    case techSetupIssue
    case emotionalResistance
    case moreUrgentThingAppeared

    var id: Self { self }

    var displayName: String {
        switch self {
        case .tired:
            return "Tired"
        case .distracted:
            return "Distracted"
        case .unclearNextStep:
            return "Unclear next step"
        case .underestimatedTask:
            return "Underestimated task"
        case .interrupted:
            return "Interrupted"
        case .avoidance:
            return "Avoidance"
        case .wrongEnvironment:
            return "Wrong environment"
        case .techSetupIssue:
            return "Tech/setup issue"
        case .emotionalResistance:
            return "Emotional resistance"
        case .moreUrgentThingAppeared:
            return "More urgent thing appeared"
        }
    }
}

nonisolated enum WorkBlockLengthFit: String, Codable, CaseIterable, Identifiable, Sendable {
    case tooShort
    case aboutRight
    case tooLong

    var id: Self { self }

    var displayName: String {
        switch self {
        case .tooShort:
            return "Too short"
        case .aboutRight:
            return "About right"
        case .tooLong:
            return "Too long"
        }
    }
}

nonisolated enum SocialDebriefMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case draining
    case mixed
    case fine
    case good
    case reallyGood

    var id: Self { self }

    var displayName: String {
        switch self {
        case .draining:
            return "Draining"
        case .mixed:
            return "Mixed"
        case .fine:
            return "Fine"
        case .good:
            return "Good"
        case .reallyGood:
            return "Really good"
        }
    }
}

nonisolated enum SocialDebriefNourishment: String, Codable, CaseIterable, Identifiable, Sendable {
    case nourishing
    case neutral
    case obligatory
    case draining

    var id: Self { self }

    var displayName: String {
        switch self {
        case .nourishing:
            return "Nourishing"
        case .neutral:
            return "Neutral"
        case .obligatory:
            return "Obligatory"
        case .draining:
            return "Draining"
        }
    }
}

nonisolated struct CalendarDebriefRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    var sourceType: DebriefSourceType
    var sourceID: String?
    var sourceContext: String?
    var eventKey: String
    var eventIdentifier: String?
    var calendarIdentifier: String?
    var calendarTitleSnapshot: String
    var titleSnapshot: String
    var startDateSnapshot: Date
    var endDateSnapshot: Date
    var templateKind: DebriefTemplateKind
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var status: CalendarDebriefStatus
    var noDebriefNeeded: Bool
    var quickOutcome: DebriefQuickOutcome?
    var quickNote: String?
    var essentialNote: String?
    var detailedResponses: [DebriefPromptResponse]
    var createdCaptureIDs: [UUID]

    var workPlannedOutcome: WorkBlockPlannedOutcome?
    var workProductivityRating: Int?
    var workWhatHappened: String?
    var workBlockers: [WorkBlockBlocker]
    var workBlockLengthFit: WorkBlockLengthFit?
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
    var socialMood: SocialDebriefMood?
    var socialWhoWasThere: String?
    var socialLearnedAboutSomeone: String?
    var socialPromised: String?
    var socialDifferentNextTime: String?
    var socialNourishment: SocialDebriefNourishment?
    var taskOutcomes: [DebriefTaskOutcome]

    init(
        id: UUID = UUID(),
        sourceType: DebriefSourceType = .calendarBlock,
        sourceID: String? = nil,
        sourceContext: String? = nil,
        eventKey: String,
        eventIdentifier: String?,
        calendarIdentifier: String?,
        calendarTitleSnapshot: String,
        titleSnapshot: String,
        startDateSnapshot: Date,
        endDateSnapshot: Date,
        templateKind: DebriefTemplateKind,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        status: CalendarDebriefStatus,
        noDebriefNeeded: Bool = false,
        quickOutcome: DebriefQuickOutcome? = nil,
        quickNote: String? = nil,
        essentialNote: String? = nil,
        detailedResponses: [DebriefPromptResponse] = [],
        createdCaptureIDs: [UUID] = [],
        workPlannedOutcome: WorkBlockPlannedOutcome? = nil,
        workProductivityRating: Int? = nil,
        workWhatHappened: String? = nil,
        workBlockers: [WorkBlockBlocker] = [],
        workBlockLengthFit: WorkBlockLengthFit? = nil,
        workEnergyBeforeRating: Int? = nil,
        workEnergyAfterRating: Int? = nil,
        workFocusQualityRating: Int? = nil,
        workNextStep: String? = nil,
        meetingOutcomes: String? = nil,
        meetingFollowUps: String? = nil,
        meetingUsefulnessRating: Int? = nil,
        meetingDecisions: String? = nil,
        meetingOpenQuestions: String? = nil,
        meetingDeadlines: String? = nil,
        meetingPreparednessRating: Int? = nil,
        meetingPeopleInvolved: String? = nil,
        meetingRememberBeforeNext: String? = nil,
        socialWorthRemembering: String? = nil,
        socialFollowUp: String? = nil,
        socialMood: SocialDebriefMood? = nil,
        socialWhoWasThere: String? = nil,
        socialLearnedAboutSomeone: String? = nil,
        socialPromised: String? = nil,
        socialDifferentNextTime: String? = nil,
        socialNourishment: SocialDebriefNourishment? = nil,
        taskOutcomes: [DebriefTaskOutcome] = []
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = Self.cleanedIdentifier(sourceID)
        self.sourceContext = MyTask.cleanedOptionalText(from: sourceContext)
        self.eventKey = eventKey
        self.eventIdentifier = Self.cleanedIdentifier(eventIdentifier)
        self.calendarIdentifier = Self.cleanedIdentifier(calendarIdentifier)
        self.calendarTitleSnapshot = Self.cleanedSnapshotTitle(calendarTitleSnapshot)
        self.titleSnapshot = Self.cleanedSnapshotTitle(titleSnapshot)
        self.startDateSnapshot = startDateSnapshot
        self.endDateSnapshot = endDateSnapshot
        self.templateKind = templateKind
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.completedAt = completedAt
        self.status = status
        self.noDebriefNeeded = noDebriefNeeded
        self.quickOutcome = quickOutcome
        self.quickNote = MyTask.cleanedOptionalText(from: quickNote)
        self.essentialNote = MyTask.cleanedOptionalText(from: essentialNote)
        self.detailedResponses = detailedResponses.filter { $0.response.isEmpty == false }
        self.createdCaptureIDs = Array(Set(createdCaptureIDs))

        self.workPlannedOutcome = workPlannedOutcome
        self.workProductivityRating = Self.cleanedRating(workProductivityRating)
        self.workWhatHappened = MyTask.cleanedOptionalText(from: workWhatHappened)
        self.workBlockers = Array(Set(workBlockers))
        self.workBlockLengthFit = workBlockLengthFit
        self.workEnergyBeforeRating = Self.cleanedRating(workEnergyBeforeRating)
        self.workEnergyAfterRating = Self.cleanedRating(workEnergyAfterRating)
        self.workFocusQualityRating = Self.cleanedRating(workFocusQualityRating)
        self.workNextStep = MyTask.cleanedOptionalText(from: workNextStep)

        self.meetingOutcomes = MyTask.cleanedOptionalText(from: meetingOutcomes)
        self.meetingFollowUps = MyTask.cleanedOptionalText(from: meetingFollowUps)
        self.meetingUsefulnessRating = Self.cleanedRating(meetingUsefulnessRating)
        self.meetingDecisions = MyTask.cleanedOptionalText(from: meetingDecisions)
        self.meetingOpenQuestions = MyTask.cleanedOptionalText(from: meetingOpenQuestions)
        self.meetingDeadlines = MyTask.cleanedOptionalText(from: meetingDeadlines)
        self.meetingPreparednessRating = Self.cleanedRating(meetingPreparednessRating)
        self.meetingPeopleInvolved = MyTask.cleanedOptionalText(from: meetingPeopleInvolved)
        self.meetingRememberBeforeNext = MyTask.cleanedOptionalText(from: meetingRememberBeforeNext)

        self.socialWorthRemembering = MyTask.cleanedOptionalText(from: socialWorthRemembering)
        self.socialFollowUp = MyTask.cleanedOptionalText(from: socialFollowUp)
        self.socialMood = socialMood
        self.socialWhoWasThere = MyTask.cleanedOptionalText(from: socialWhoWasThere)
        self.socialLearnedAboutSomeone = MyTask.cleanedOptionalText(from: socialLearnedAboutSomeone)
        self.socialPromised = MyTask.cleanedOptionalText(from: socialPromised)
        self.socialDifferentNextTime = MyTask.cleanedOptionalText(from: socialDifferentNextTime)
        self.socialNourishment = socialNourishment
        self.taskOutcomes = taskOutcomes.map { outcome in
            DebriefTaskOutcome(
                id: outcome.id,
                debriefID: outcome.debriefID,
                taskID: outcome.taskID,
                taskTitleSnapshot: outcome.taskTitleSnapshot,
                outcome: outcome.outcome,
                note: outcome.note,
                didUpdateTaskStatus: outcome.didUpdateTaskStatus,
                createdAt: outcome.createdAt,
                updatedAt: outcome.updatedAt
            )
        }
    }

    var completed: Bool {
        status == .completed
    }

    var skipped: Bool {
        status == .skipped
    }

    var durationMinutes: Int {
        max(0, Int(endDateSnapshot.timeIntervalSince(startDateSnapshot) / 60))
    }

    var templateDefinition: DebriefTemplateDefinition {
        DebriefTemplates.definition(for: templateKind)
    }

    func pendingCandidateIfNeeded() -> CalendarDebriefCandidate? {
        guard status == .pending else {
            return nil
        }

        return CalendarDebriefCandidate(
            sourceType: sourceType,
            sourceID: sourceID,
            sourceContext: sourceContext,
            eventKey: eventKey,
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier,
            calendarTitle: calendarTitleSnapshot,
            title: titleSnapshot,
            start: startDateSnapshot,
            end: endDateSnapshot,
            suggestedTemplate: templateKind,
            existingRecordID: id
        )
    }

    func completedQuickly(
        outcome: DebriefQuickOutcome,
        note: String?,
        completedAt: Date,
        templateKind: DebriefTemplateKind? = nil
    ) -> CalendarDebriefRecord {
        var copy = self
        copy.templateKind = templateKind ?? self.templateKind
        copy.quickOutcome = outcome
        copy.quickNote = MyTask.cleanedOptionalText(from: note)
        copy.essentialNote = copy.quickNote ?? essentialNote
        copy.status = outcome.completionStatus
        copy.noDebriefNeeded = outcome == .skipped
        copy.completedAt = completedAt
        copy.updatedAt = completedAt
        return copy
    }

    static func suggestedTemplate(for eventTitle: String) -> DebriefTemplateKind {
        let normalized = eventTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if matchesAnyKeyword(
            normalized,
            keywords: ["meeting", "call", "sync", "besprechung"]
        ) {
            return .meeting
        }

        if matchesAnyKeyword(
            normalized,
            keywords: ["dinner", "drinks", "party", "hang", "date", "coffee"]
        ) {
            return .social
        }

        if matchesAnyKeyword(
            normalized,
            keywords: ["jam", "rehearsal", "band"]
        ) {
            return .jamSession
        }

        if matchesAnyKeyword(
            normalized,
            keywords: ["piano", "practice", "scales", "lesson"]
        ) {
            return .pianoPractice
        }

        if matchesAnyKeyword(
            normalized,
            keywords: ["work", "admin", "study", "write", "coding", "project", "deep work"]
        ) {
            return .workBlock
        }

        return .generic
    }

    private static func matchesAnyKeyword(
        _ text: String,
        keywords: [String]
    ) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword)
        }
    }

    private static func cleanedIdentifier(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func cleanedSnapshotTitle(_ value: String) -> String {
        MyTask.cleanedTitle(from: value) ?? "Untitled Event"
    }

    private static func cleanedRating(_ value: Int?) -> Int? {
        guard let value else {
            return nil
        }

        return min(5, max(1, value))
    }
}

nonisolated struct CalendarDebriefCandidate: Identifiable, Equatable, Hashable, Sendable {
    let sourceType: DebriefSourceType
    let sourceID: String?
    let sourceContext: String?
    let eventKey: String
    let eventIdentifier: String?
    let calendarIdentifier: String?
    let calendarTitle: String
    let title: String
    let start: Date
    let end: Date
    let suggestedTemplate: DebriefTemplateKind
    let existingRecordID: UUID?
    var linkedProjectID: UUID? = nil
    var linkedProjectName: String? = nil
    var selectedTaskCount: Int = 0

    var id: String {
        eventKey
    }

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }
}

nonisolated struct DebriefQueueSettings: Equatable, Sendable {
    var lookbackDays: Int
    var minimumDurationMinutes: Int
    var ignoreAllDayEvents: Bool

    static let mvpDefault = DebriefQueueSettings(
        lookbackDays: 3,
        minimumDurationMinutes: 15,
        ignoreAllDayEvents: true
    )
}

nonisolated enum DebriefEventKey {
    static func from(
        eventIdentifier: String?,
        title: String,
        start: Date,
        end: Date,
        calendarIdentifier: String?,
        calendarTitle: String
    ) -> String {
        let normalizedIdentifier = eventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryIdentifier: String
        if let normalizedIdentifier, normalizedIdentifier.isEmpty == false {
            primaryIdentifier = normalizedIdentifier
        } else {
            primaryIdentifier = "no-id"
        }

        let normalizedCalendarIdentifier = calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendarKey: String
        if let normalizedCalendarIdentifier, normalizedCalendarIdentifier.isEmpty == false {
            calendarKey = normalizedCalendarIdentifier
        } else {
            calendarKey = calendarTitle
        }

        return [
            primaryIdentifier,
            String(start.timeIntervalSince1970),
            String(end.timeIntervalSince1970),
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarKey,
        ]
        .joined(separator: "|")
    }
}

nonisolated struct DebriefQueueService {
    private static let passiveEventKeywords = [
        "birthday",
        "holiday",
        "travel time",
        "commute",
        "out of office",
        "ooo",
    ]

    let settings: DebriefQueueSettings

    init(settings: DebriefQueueSettings = .mvpDefault) {
        self.settings = settings
    }

    func pendingCandidates(
        from events: [CalendarEventSnapshot],
        existingDebriefs: [CalendarDebriefRecord],
        now: Date
    ) -> [CalendarDebriefCandidate] {
        let earliestAllowedEndDate = now.addingTimeInterval(
            -Double(max(1, settings.lookbackDays)) * 86_400
        )

        let resolvedEventKeys = Set(
            existingDebriefs
                .filter { debrief in
                    debrief.status == .completed || debrief.status == .skipped
                }
                .map(\.eventKey)
        )

        let pendingPairs: [(String, UUID)] = existingDebriefs.compactMap { debrief in
            guard debrief.status == .pending else {
                return nil
            }

            return (debrief.eventKey, debrief.id)
        }
        let pendingRecordByEventKey = Dictionary(uniqueKeysWithValues: pendingPairs)

        return events
            .filter { event in
                event.end <= now
                    && event.end >= earliestAllowedEndDate
                    && (settings.ignoreAllDayEvents == false || event.isAllDay == false)
                    && event.end.timeIntervalSince(event.start) >= Double(settings.minimumDurationMinutes) * 60
                    && isPassiveEventTitle(event.title) == false
            }
            .map { event in
                let eventKey = DebriefEventKey.from(
                    eventIdentifier: event.identifier,
                    title: event.title,
                    start: event.start,
                    end: event.end,
                    calendarIdentifier: event.calendarIdentifier,
                    calendarTitle: event.calendarTitle
                )

            return CalendarDebriefCandidate(
                sourceType: .calendarBlock,
                sourceID: event.identifier,
                sourceContext: event.calendarTitle,
                eventKey: eventKey,
                eventIdentifier: event.identifier,
                calendarIdentifier: event.calendarIdentifier,
                calendarTitle: event.calendarTitle,
                title: event.title,
                start: event.start,
                end: event.end,
                suggestedTemplate: DebriefTemplateInferenceService().inferredTemplate(
                    sourceType: .calendarBlock,
                    title: event.title
                ),
                existingRecordID: pendingRecordByEventKey[eventKey]
            )
        }
            .filter { candidate in
                resolvedEventKeys.contains(candidate.eventKey) == false
            }
            .sorted { lhs, rhs in
                if lhs.end != rhs.end {
                    return lhs.end > rhs.end
                }

                if lhs.start != rhs.start {
                    return lhs.start > rhs.start
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func isPassiveEventTitle(_ title: String) -> Bool {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        return Self.passiveEventKeywords.contains { keyword in
            normalizedTitle.contains(keyword)
        }
    }
}
