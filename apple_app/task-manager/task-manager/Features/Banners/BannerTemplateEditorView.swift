import SwiftUI

private enum BannerRecurrenceMode: String, CaseIterable, Identifiable {
    case daily
    case weekdays

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Selected Days"
        }
    }
}

private enum BannerScheduleMode: String, CaseIterable, Identifiable {
    case fixedTime
    case randomWindow

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .fixedTime:
            return "Fixed Time"
        case .randomWindow:
            return "Random Window"
        }
    }
}

struct BannerTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let template: AlertTemplate
    let originalID: UUID?
    let routines: [Routine]
    let onSave: (AlertTemplate, UUID?) async -> Bool

    @State private var title: String
    @State private var selectedRoutineID: UUID?
    @State private var scheduleMode: BannerScheduleMode
    @State private var selectedTime: Date
    @State private var randomWindowStart: Date
    @State private var randomWindowEnd: Date
    @State private var recurrenceMode: BannerRecurrenceMode
    @State private var selectedWeekdays: Set<RoutineWeekday>
    @State private var urgency: AlertUrgency
    @State private var privacyMode: AlertPrivacyMode
    @State private var isEnabled: Bool
    @State private var saveAttemptFailed = false

    init(
        template: AlertTemplate,
        originalID: UUID?,
        routines: [Routine],
        onSave: @escaping (AlertTemplate, UUID?) async -> Bool
    ) {
        self.template = template
        self.originalID = originalID
        self.routines = routines
        self.onSave = onSave
        _title = State(initialValue: template.title)
        _selectedRoutineID = State(initialValue: template.routineID)
        _scheduleMode = State(initialValue: template.randomDailyWindowTrigger == nil ? .fixedTime : .randomWindow)
        _selectedTime = State(
            initialValue: Self.makeDate(
                from: template.fixedTimeTrigger?.timeOfDay
                    ?? template.randomDailyWindowTrigger?.window.start
            )
        )
        _randomWindowStart = State(
            initialValue: Self.makeDate(
                from: template.randomDailyWindowTrigger?.window.start ?? AlertTimeOfDay(hour: 9, minute: 0)
            )
        )
        _randomWindowEnd = State(
            initialValue: Self.makeDate(
                from: template.randomDailyWindowTrigger?.window.end ?? AlertTimeOfDay(hour: 11, minute: 0)
            )
        )
        _recurrenceMode = State(initialValue: template.isDailyFixedTimeTrigger ? .daily : .weekdays)
        _selectedWeekdays = State(
            initialValue: (
                template.fixedTimeTrigger?.recurrence.weekdaysSet
                    ?? template.randomDailyWindowTrigger?.recurrence.weekdaysSet
                    ?? []
            )
        )
        _urgency = State(initialValue: template.urgency)
        _privacyMode = State(initialValue: template.privacyMode)
        _isEnabled = State(initialValue: template.isEnabled)
    }

    var body: some View {
        Group {
            if routines.isEmpty {
                ContentUnavailableView(
                    "No Routines Yet",
                    systemImage: "checklist",
                    description: Text("Create a Routine first, then come back to add a Banner.")
                )
            } else {
                Form {
                    if saveAttemptFailed {
                        Section {
                            Text("Unable to save this Banner. Check the title and Routine selection.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Banner") {
                        TextField("Banner title", text: $title)
                        Toggle("Enabled", isOn: $isEnabled)
                    }

                    Section("Routine") {
                        Picker("Open Routine", selection: $selectedRoutineID) {
                            Text("Choose Routine").tag(nil as UUID?)
                            ForEach(routines) { routine in
                                Text(routine.name).tag(routine.id as UUID?)
                            }
                        }
                    }

                    Section("Schedule") {
                        Picker("Mode", selection: $scheduleMode) {
                            ForEach(BannerScheduleMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if scheduleMode == .fixedTime {
                            DatePicker(
                                "Time",
                                selection: $selectedTime,
                                displayedComponents: [.hourAndMinute]
                            )
                        } else {
                            DatePicker(
                                "Window Start",
                                selection: $randomWindowStart,
                                displayedComponents: [.hourAndMinute]
                            )

                            DatePicker(
                                "Window End",
                                selection: $randomWindowEnd,
                                displayedComponents: [.hourAndMinute]
                            )
                        }

                        Picker("Repeat", selection: $recurrenceMode) {
                            ForEach(BannerRecurrenceMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if recurrenceMode == .weekdays {
                            weekdayPicker
                        }
                    }

                    Section("Behavior") {
                        Picker("Urgency", selection: $urgency) {
                            ForEach(AlertUrgency.allCases, id: \.self) { urgency in
                                Text(urgency.displayName).tag(urgency)
                            }
                        }

                        Picker("Privacy", selection: $privacyMode) {
                            ForEach(AlertPrivacyMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }

                        Text("Snooze defaults to 15 minutes and stops after a few repeats.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(originalID == nil ? "New Banner" : "Edit Banner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        saveAttemptFailed = false
                        let saved = await onSave(buildTemplate(), originalID)
                        if saved {
                            dismiss()
                        } else {
                            saveAttemptFailed = true
                        }
                    }
                }
                .disabled(canSave == false)
            }
        }
    }

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            selectedRoutineID != nil &&
            routines.isEmpty == false
    }

    private var weekdayPicker: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 56), spacing: 8)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(RoutineWeekday.allCases, id: \.self) { weekday in
                Button {
                    toggle(weekday)
                } label: {
                    Text(weekday.shortName)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedWeekdays.contains(weekday) ? .white : .primary)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedWeekdays.contains(weekday) ? Color.accentColor : Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ weekday: RoutineWeekday) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private func buildTemplate() -> AlertTemplate {
        let routineID = selectedRoutineID ?? template.routineID ?? UUID()
        let recurrence: AlertRecurrence = recurrenceMode == .daily ? .daily : .weekdays(selectedWeekdays.sortedByRawValue)
        let trigger: AlertTrigger

        switch scheduleMode {
        case .fixedTime:
            trigger = .fixedTime(
                AlertFixedTimeTrigger(
                    hour: Self.hour(from: selectedTime),
                    minute: Self.minute(from: selectedTime),
                    recurrence: recurrence
                )
            )
        case .randomWindow:
            trigger = .randomDailyWindow(
                AlertRandomDailyWindowTrigger(
                    start: AlertTimeOfDay(
                        hour: Self.hour(from: randomWindowStart),
                        minute: Self.minute(from: randomWindowStart)
                    ),
                    end: AlertTimeOfDay(
                        hour: Self.hour(from: randomWindowEnd),
                        minute: Self.minute(from: randomWindowEnd)
                    ),
                    recurrence: recurrence
                )
            )
        }

        return AlertTemplate(
            id: template.id,
            title: title,
            target: .openRoutine(routineID),
            trigger: trigger,
            urgency: urgency,
            privacyMode: privacyMode,
            isEnabled: isEnabled,
            snoozeMinutes: template.snoozeMinutes,
            maxSnoozes: template.maxSnoozes,
            createdAt: template.createdAt,
            updatedAt: .now
        )
    }

    private static func makeDate(from timeOfDay: AlertTimeOfDay?) -> Date {
        let timeOfDay = timeOfDay ?? AlertTimeOfDay(hour: 7, minute: 30)
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = timeOfDay.hour
        components.minute = timeOfDay.minute
        return components.date ?? .now
    }

    private static func hour(from date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private static func minute(from date: Date) -> Int {
        Calendar.current.component(.minute, from: date)
    }
}

private extension AlertTemplate {
    var fixedTimeTrigger: AlertFixedTimeTrigger? {
        trigger.fixedTime
    }

    var randomDailyWindowTrigger: AlertRandomDailyWindowTrigger? {
        trigger.randomDailyWindow
    }

    var isDailyFixedTimeTrigger: Bool {
        fixedTimeTrigger?.isDaily
            ?? (randomDailyWindowTrigger?.recurrence.normalized == .daily)
    }
}

private extension AlertRecurrence {
    var weekdaysSet: Set<RoutineWeekday> {
        Set(weekdays)
    }
}

private extension Set where Element == RoutineWeekday {
    var sortedByRawValue: [RoutineWeekday] {
        sorted { $0.rawValue < $1.rawValue }
    }
}
