import Foundation

nonisolated enum ViceSessionPolicy {
    static let defaultWindow: TimeInterval = 3 * 3_600
}

nonisolated struct ViceSession: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let viceID: UUID
    let startedAt: Date
    var lastHitAt: Date
    var hitCount: Int
    var closedAt: Date?

    init(
        id: UUID = UUID(),
        viceID: UUID,
        startedAt: Date,
        lastHitAt: Date? = nil,
        hitCount: Int = 1,
        closedAt: Date? = nil
    ) {
        self.id = id
        self.viceID = viceID
        self.startedAt = startedAt
        self.lastHitAt = lastHitAt ?? startedAt
        self.hitCount = Swift.max(1, hitCount)
        self.closedAt = closedAt
    }

    var isClosed: Bool {
        closedAt != nil
    }

    func isActive(at now: Date, window: TimeInterval = ViceSessionPolicy.defaultWindow) -> Bool {
        guard closedAt == nil else {
            return false
        }

        return now.timeIntervalSince(lastHitAt) <= window
    }

    func closingDate(window: TimeInterval = ViceSessionPolicy.defaultWindow) -> Date {
        lastHitAt.addingTimeInterval(window)
    }

    var duration: TimeInterval {
        Swift.max(0, lastHitAt.timeIntervalSince(startedAt))
    }
}

nonisolated struct Vice: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var unitLabel: String
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        unitLabel: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unitLabel = Self.cleanedUnitLabel(from: unitLabel) ?? unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.isArchived = isArchived
    }

    init?(
        newName: String,
        unitLabel: String,
        createdAt: Date = .now
    ) {
        guard let cleanedName = Self.cleanedName(from: newName),
              let cleanedUnitLabel = Self.cleanedUnitLabel(from: unitLabel) else {
            return nil
        }

        self.init(
            name: cleanedName,
            unitLabel: cleanedUnitLabel,
            createdAt: createdAt
        )
    }

    static func cleanedName(from rawName: String) -> String? {
        MyTask.cleanedTitle(from: rawName)
    }

    static func cleanedUnitLabel(from rawLabel: String) -> String? {
        MyTask.cleanedTitle(from: rawLabel)
    }
}

nonisolated struct ViceLog: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let viceID: UUID
    let timestamp: Date
    let amount: Int

    init(
        id: UUID = UUID(),
        viceID: UUID,
        timestamp: Date,
        amount: Int = 1
    ) {
        self.id = id
        self.viceID = viceID
        self.timestamp = timestamp
        self.amount = Swift.max(1, amount)
    }
}

nonisolated struct ViceGoal: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let viceID: UUID
    var maxOccurrences: Int
    var startDate: Date
    var deadline: Date
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        viceID: UUID,
        maxOccurrences: Int,
        startDate: Date,
        deadline: Date,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.viceID = viceID
        self.maxOccurrences = Swift.max(1, maxOccurrences)
        self.startDate = startDate
        self.deadline = Swift.max(startDate, deadline)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.archivedAt = archivedAt
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    func isActive(at now: Date) -> Bool {
        isArchived == false && now <= deadline
    }

    func contains(_ date: Date) -> Bool {
        date >= startDate && date <= deadline
    }

    func progress(count: Int) -> Double {
        let safeCount = Swift.max(0, count)
        return Double(safeCount) / Double(Swift.max(1, maxOccurrences))
    }

    func status(forCount count: Int) -> ViceGoalStatus {
        let ratio = progress(count: count)
        if ratio >= 1 {
            return .exceeded
        }

        if ratio >= 0.7 {
            return .warning
        }

        return .onTrack
    }
}

nonisolated enum ViceGoalStatus: String, Equatable, Hashable, Sendable {
    case onTrack
    case warning
    case exceeded
}

nonisolated struct ViceGoalProgress: Equatable, Hashable, Sendable {
    let goal: ViceGoal
    let count: Int

    var ratio: Double {
        goal.progress(count: count)
    }

    var clampedRatio: Double {
        min(max(ratio, 0), 1)
    }

    var status: ViceGoalStatus {
        goal.status(forCount: count)
    }

    func summaryText() -> String {
        "\(count) / \(goal.maxOccurrences) until \(goal.deadline.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

nonisolated struct ViceSessionSummary: Equatable, Sendable {
    let session: ViceSession
    let viceName: String

    var summaryText: String {
        let durationText = Self.formatDuration(session.duration, style: .compact)
        return "\(viceName) session: \(session.hitCount) hit\(session.hitCount == 1 ? "" : "s") over \(durationText)."
    }

    private static func formatDuration(_ interval: TimeInterval, style: ViceDurationStyle) -> String {
        ViceDurationFormatter.format(interval, style: style)
    }
}

nonisolated enum ViceDurationStyle {
    case compact
    case elapsed
}

nonisolated enum ViceDurationFormatter {
    static func format(_ interval: TimeInterval, style: ViceDurationStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        formatter.allowedUnits = interval >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        let formatted = formatter.string(from: Swift.max(0, interval)) ?? "00:00"
        switch style {
        case .compact:
            return formatted
        case .elapsed:
            return formatted
        }
    }

    static func elapsedSince(_ date: Date, now: Date) -> String {
        format(now.timeIntervalSince(date), style: .elapsed)
    }
}

nonisolated struct HomeVicesSummary: Equatable, Sendable {
    let vices: [Vice]
    let logs: [ViceLog]
    let now: Date
    let calendar: Calendar

    var activeViceCount: Int {
        vices.filter { $0.isArchived == false }.count
    }

    var totalTodayCount: Int {
        logs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
            .reduce(0) { partialResult, log in
                partialResult + log.amount
            }
    }

    var detail: String {
        if activeViceCount == 0 {
            return "No vices added"
        }

        if totalTodayCount == 0 {
            return "No logs today"
        }

        return "\(totalTodayCount) logged today"
    }

    var value: String {
        "\(activeViceCount)"
    }
}

nonisolated struct ViceSessionDebriefCandidateFactory {
    func makeCandidate(
        for session: ViceSession,
        vice: Vice,
        now: Date
    ) -> CalendarDebriefRecord {
        let summary = ViceSessionSummary(session: session, viceName: vice.name)
        return CalendarDebriefRecord(
            id: session.id,
            sourceType: .viceSession,
            sourceID: vice.id.uuidString,
            sourceContext: vice.name,
            eventKey: session.id.uuidString,
            eventIdentifier: session.id.uuidString,
            calendarIdentifier: nil,
            calendarTitleSnapshot: vice.name,
            titleSnapshot: summary.summaryText,
            startDateSnapshot: session.startedAt,
            endDateSnapshot: session.lastHitAt,
            templateKind: .viceSession,
            createdAt: now,
            updatedAt: now,
            status: .pending,
            noDebriefNeeded: false
        )
    }
}

nonisolated enum ViceLogRecorder {
    @MainActor
    static func recordHit(
        for vice: Vice,
        at timestamp: Date,
        repository: any ViceRepository
    ) throws -> ViceLog {
        let log = ViceLog(
            viceID: vice.id,
            timestamp: timestamp,
            amount: 1
        )

        try repository.saveViceLog(log)
        try recordSession(for: vice, at: timestamp, repository: repository)
        return log
    }

    static func mostRecentRepeatableLog(
        in logs: [ViceLog],
        activeVices: [Vice]
    ) -> (vice: Vice, log: ViceLog)? {
        let activeViceLookup = Dictionary(uniqueKeysWithValues: activeVices.map { ($0.id, $0) })
        guard let log = logs.sortedForViceLogs().first(where: { activeViceLookup[$0.viceID] != nil }),
              let vice = activeViceLookup[log.viceID] else {
            return nil
        }

        return (vice: vice, log: log)
    }

    @MainActor
    private static func recordSession(
        for vice: Vice,
        at timestamp: Date,
        repository: any ViceRepository
    ) throws {
        let sessions = try repository.fetchViceSessions()
        let activeSession = sessions.first(where: { session in
            session.viceID == vice.id && session.isActive(at: timestamp)
        })

        if var session = activeSession {
            session.hitCount += 1
            session.lastHitAt = timestamp
            try repository.saveViceSession(session)
            return
        }

        let session = ViceSession(
            viceID: vice.id,
            startedAt: timestamp,
            lastHitAt: timestamp,
            hitCount: 1
        )
        try repository.saveViceSession(session)
    }
}

extension Array where Element == ViceLog {
    func sortedForViceHistory() -> [ViceLog] {
        sortedForViceLogs()
    }

    func gapsBetweenRecentInstances(limit: Int = 2) -> [TimeInterval] {
        let ordered = sorted { $0.timestamp < $1.timestamp }
        guard ordered.count > 1 else {
            return []
        }

        var gaps: [TimeInterval] = []
        for index in stride(from: ordered.count - 1, through: 1, by: -1) {
            let end = ordered[index].timestamp
            let start = ordered[index - 1].timestamp
            gaps.append(Swift.max(0, end.timeIntervalSince(start)))
            if gaps.count == limit {
                break
            }
        }
        return gaps
    }
}

extension Array where Element == ViceSession {
    func sortedForViceSessions() -> [ViceSession] {
        sorted { lhs, rhs in
            if lhs.lastHitAt != rhs.lastHitAt {
                return lhs.lastHitAt > rhs.lastHitAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
