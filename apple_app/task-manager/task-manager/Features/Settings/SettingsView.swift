import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var permissionStatus: CalendarPermissionStatus
    @Published private(set) var calendars: [ReadableCalendar] = []
    @Published private(set) var homeWidgetCount = 0
    @Published private(set) var errorMessage: String?

    private let settingsRepository: any SettingsRepository
    private let homeLayoutRepository: any HomeLayoutRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private var hasLoaded = false

    init(
        settingsRepository: any SettingsRepository,
        homeLayoutRepository: any HomeLayoutRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing
    ) {
        self.settingsRepository = settingsRepository
        self.homeLayoutRepository = homeLayoutRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.settings = .mvpDefault
        self.permissionStatus = calendarPermissionProvider.currentStatus()
    }

    var writableCalendars: [ReadableCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    var selectedWriteCalendarIdentifier: String {
        settings.writeCalendarIdentifier
    }

    var selectedWriteCalendarTitle: String? {
        if let matchedCalendar = writableCalendars.first(where: {
            $0.id == settings.writeCalendarIdentifier
        }) {
            return matchedCalendar.title
        }

        guard settings.writeCalendarTitle.isEmpty == false else {
            return nil
        }

        return settings.writeCalendarTitle
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        await refresh()
    }

    func refresh() async {
        permissionStatus = calendarPermissionProvider.currentStatus()
        hasLoaded = true
        errorMessage = nil

        do {
            settings = try settingsRepository.loadSettings()
            homeWidgetCount = try homeLayoutRepository.loadLayout().orderedWidgets.count
        } catch {
            recordError("Unable to load settings: \(error.localizedDescription)")
        }

        guard permissionStatus == .fullAccessGranted else {
            calendars = []
            return
        }

        do {
            calendars = try await calendarListingService.fetchReadableCalendars()
        } catch {
            calendars = []
            recordError("Unable to load calendars: \(error.localizedDescription)")
        }
    }

    func selectWriteCalendar(withID calendarID: String) {
        guard let selectedCalendar = writableCalendars.first(where: { $0.id == calendarID }) else {
            recordError("The selected write calendar is no longer available.")
            return
        }

        var updatedSettings = settings
        updatedSettings.writeCalendarIdentifier = selectedCalendar.id
        updatedSettings.writeCalendarTitle = selectedCalendar.title
        save(updatedSettings, errorPrefix: "Unable to save calendar settings")
    }

    func setCalendarExcluded(_ title: String, isExcluded: Bool) {
        var updatedSettings = settings
        var titles = Set(updatedSettings.excludedReadCalendarTitles)

        if isExcluded {
            titles.insert(title)
        } else {
            titles.remove(title)
        }

        updatedSettings.excludedReadCalendarTitles = titles.sorted()
        save(updatedSettings, errorPrefix: "Unable to save calendar exclusions")
        calendars = calendars.map { calendar in
            guard calendar.title == title else {
                return calendar
            }

            return ReadableCalendar(
                id: calendar.id,
                title: calendar.title,
                allowsContentModifications: calendar.allowsContentModifications,
                isExcludedBySettings: isExcluded
            )
        }
    }

    func updateMinimumGapMinutes(_ minutes: Int) {
        var updatedSettings = settings
        updatedSettings.minimumGapMinutes = minutes
        save(updatedSettings, errorPrefix: "Unable to save planner settings")
    }

    func updateDefaultAssumedDurationMinutes(_ minutes: Int) {
        var updatedSettings = settings
        updatedSettings.defaultAssumedDurationMinutes = minutes
        save(updatedSettings, errorPrefix: "Unable to save planner settings")
    }

    func updatePlannerSuggestionCap(_ count: Int) {
        var updatedSettings = settings
        updatedSettings.plannerSuggestionCap = count
        save(updatedSettings, errorPrefix: "Unable to save planner settings")
    }

    func updateNotificationsEnabled(_ isEnabled: Bool) {
        var updatedSettings = settings
        updatedSettings.notificationsEnabled = isEnabled
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationQuietHoursEnabled(_ isEnabled: Bool) {
        var updatedSettings = settings
        updatedSettings.notificationQuietHoursEnabled = isEnabled
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationQuietHoursStart(_ timeOfDay: AlertTimeOfDay) {
        var updatedSettings = settings
        updatedSettings.notificationQuietHoursStart = timeOfDay
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationQuietHoursEnd(_ timeOfDay: AlertTimeOfDay) {
        var updatedSettings = settings
        updatedSettings.notificationQuietHoursEnd = timeOfDay
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationMaxNudgesPerDay(_ count: Int) {
        var updatedSettings = settings
        updatedSettings.notificationMaxNudgesPerDay = count
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationDefaultPrivacyMode(_ mode: AlertPrivacyMode) {
        var updatedSettings = settings
        updatedSettings.notificationDefaultPrivacyMode = mode
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationDefaultUrgency(_ urgency: AlertUrgency) {
        var updatedSettings = settings
        updatedSettings.notificationDefaultUrgency = urgency
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    func updateNotificationAvoidCalendarBusyPeriods(_ shouldAvoid: Bool) {
        var updatedSettings = settings
        updatedSettings.notificationAvoidCalendarBusyPeriods = shouldAvoid
        save(updatedSettings, errorPrefix: "Unable to save notification settings")
    }

    private func save(_ updatedSettings: AppSettings, errorPrefix: String) {
        do {
            try settingsRepository.saveSettings(updatedSettings)
            settings = try settingsRepository.loadSettings()
            errorMessage = nil
        } catch {
            recordError("\(errorPrefix): \(error.localizedDescription)")
        }
    }

    private func recordError(_ message: String) {
        errorMessage = message
    }
}

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    private let settingsRepository: any SettingsRepository
    private let homeLayoutRepository: any HomeLayoutRepository
    private let projectRepository: any ProjectRepository
    private let routineRepository: any RoutineRepository
    private let alertRepository: any AlertRepository
    private let alertScheduler: AlertScheduler

    init(
        settingsRepository: any SettingsRepository,
        alertRepository: any AlertRepository,
        alertScheduler: AlertScheduler,
        homeLayoutRepository: any HomeLayoutRepository,
        projectRepository: any ProjectRepository,
        routineRepository: any RoutineRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing
    ) {
        self.settingsRepository = settingsRepository
        self.homeLayoutRepository = homeLayoutRepository
        self.projectRepository = projectRepository
        self.routineRepository = routineRepository
        self.alertRepository = alertRepository
        self.alertScheduler = alertScheduler
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                settingsRepository: settingsRepository,
                homeLayoutRepository: homeLayoutRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarListingService: calendarListingService
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Home Screen") {
                    NavigationLink {
                        HomeLayoutEditorView(
                            homeLayoutRepository: homeLayoutRepository,
                            projectRepository: projectRepository,
                            routineRepository: routineRepository
                        )
                    } label: {
                        LabeledContent("Customize Widgets") {
                            Text("\(viewModel.homeWidgetCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(homeSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notifications") {
                    Toggle("Allow Notifications", isOn: notificationsEnabledBinding)

                    Group {
                        Toggle("Use Quiet Hours", isOn: notificationQuietHoursEnabledBinding)

                        if viewModel.settings.notificationQuietHoursEnabled {
                            DatePicker(
                                "Quiet Hours Start",
                                selection: notificationQuietHoursStartBinding,
                                displayedComponents: [.hourAndMinute]
                            )

                            DatePicker(
                                "Quiet Hours End",
                                selection: notificationQuietHoursEndBinding,
                                displayedComponents: [.hourAndMinute]
                            )
                        }

                        Stepper(value: notificationMaxNudgesBinding, in: 1 ... 10, step: 1) {
                            LabeledContent("Daily Nudge Limit") {
                                Text("\(viewModel.settings.notificationMaxNudgesPerDay)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Picker("Default Privacy", selection: notificationDefaultPrivacyBinding) {
                            ForEach(AlertPrivacyMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }

                        Picker("Default Urgency", selection: notificationDefaultUrgencyBinding) {
                            ForEach(AlertUrgency.allCases, id: \.self) { urgency in
                                Text(urgency.displayName).tag(urgency)
                            }
                        }

                        Toggle(
                            "Avoid Busy Calendar Times",
                            isOn: notificationAvoidBusyTimesBinding
                        )
                    }
                    .disabled(viewModel.settings.notificationsEnabled == false)

                    Text("Global notification defaults apply to new auto-generated nudges and new Banners. Quiet hours, daily caps, and busy-time avoidance affect scheduled Banner requests.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Banners") {
                    NavigationLink {
                        BannersView(
                            alertRepository: alertRepository,
                            alertScheduler: alertScheduler,
                            routineRepository: routineRepository,
                            settingsRepository: settingsRepository
                        )
                    } label: {
                        LabeledContent("Manage Banners") {
                            Text("Routine Alerts")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Create routine-linked local notifications that open a selected Routine at a fixed time or inside a random window.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Calendar / Planner") {
                    PlannerCalendarSetupCard(
                        writableCalendars: viewModel.writableCalendars,
                        selectedWriteCalendarIdentifier: viewModel.selectedWriteCalendarIdentifier,
                        selectedWriteCalendarTitle: viewModel.selectedWriteCalendarTitle,
                        onSelectWriteCalendar: { calendarID in
                            viewModel.selectWriteCalendar(withID: calendarID)
                        }
                    )

                    calendarReadAccessContent

                    Stepper(value: minimumGapBinding, in: 5 ... 180, step: 5) {
                        LabeledContent("Minimum Gap") {
                            Text("\(viewModel.settings.minimumGapMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: defaultDurationBinding, in: 15 ... 240, step: 15) {
                        LabeledContent("Default Duration") {
                            Text("\(viewModel.settings.defaultAssumedDurationMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: suggestionCapBinding, in: 0 ... 20, step: 1) {
                        LabeledContent("Suggestion Cap") {
                            Text("\(viewModel.settings.plannerSuggestionCap)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Sync / Devices") {
                    Text("Cross-device sync is not active yet. Settings sync and device-to-device sync are planned, but they are read-only placeholders in this build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }

    private var minimumGapBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.minimumGapMinutes },
            set: { viewModel.updateMinimumGapMinutes($0) }
        )
    }

    private var defaultDurationBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.defaultAssumedDurationMinutes },
            set: { viewModel.updateDefaultAssumedDurationMinutes($0) }
        )
    }

    private var suggestionCapBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.plannerSuggestionCap },
            set: { viewModel.updatePlannerSuggestionCap($0) }
        )
    }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.notificationsEnabled },
            set: { viewModel.updateNotificationsEnabled($0) }
        )
    }

    private var notificationQuietHoursEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.notificationQuietHoursEnabled },
            set: { viewModel.updateNotificationQuietHoursEnabled($0) }
        )
    }

    private var notificationQuietHoursStartBinding: Binding<Date> {
        Binding(
            get: { Self.date(for: viewModel.settings.notificationQuietHoursStart) },
            set: { viewModel.updateNotificationQuietHoursStart(AlertTimeOfDay(date: $0)) }
        )
    }

    private var notificationQuietHoursEndBinding: Binding<Date> {
        Binding(
            get: { Self.date(for: viewModel.settings.notificationQuietHoursEnd) },
            set: { viewModel.updateNotificationQuietHoursEnd(AlertTimeOfDay(date: $0)) }
        )
    }

    private var notificationMaxNudgesBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.notificationMaxNudgesPerDay },
            set: { viewModel.updateNotificationMaxNudgesPerDay($0) }
        )
    }

    private var notificationDefaultPrivacyBinding: Binding<AlertPrivacyMode> {
        Binding(
            get: { viewModel.settings.notificationDefaultPrivacyMode },
            set: { viewModel.updateNotificationDefaultPrivacyMode($0) }
        )
    }

    private var notificationDefaultUrgencyBinding: Binding<AlertUrgency> {
        Binding(
            get: { viewModel.settings.notificationDefaultUrgency },
            set: { viewModel.updateNotificationDefaultUrgency($0) }
        )
    }

    private var notificationAvoidBusyTimesBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.notificationAvoidCalendarBusyPeriods },
            set: { viewModel.updateNotificationAvoidCalendarBusyPeriods($0) }
        )
    }

    private var homeSummary: String {
        if viewModel.homeWidgetCount == 0 {
            return "Home is empty right now. Open customization to add widgets or restore the default layout."
        }

        return "Home currently shows \(viewModel.homeWidgetCount) widget\(viewModel.homeWidgetCount == 1 ? "" : "s")."
    }

    private static func date(for timeOfDay: AlertTimeOfDay) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = timeOfDay.hour
        components.minute = timeOfDay.minute
        return components.date ?? .now
    }

    @ViewBuilder
    private var calendarReadAccessContent: some View {
        switch viewModel.permissionStatus {
        case .fullAccessGranted:
            if viewModel.calendars.isEmpty {
                Text("No readable calendars are available yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.calendars) { calendar in
                    Toggle(
                        isOn: Binding(
                            get: { calendar.isExcludedBySettings == false },
                            set: { isIncluded in
                                viewModel.setCalendarExcluded(calendar.title, isExcluded: isIncluded == false)
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendar.title)
                            Text("Use for busy-time reads")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        case .notDetermined:
            Text("Grant Calendar access from Planner before changing read-calendar settings on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .writeOnlyGrantedButInsufficient:
            Text("Full Calendar access is required to choose read calendars.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .denied, .restricted:
            Text("Calendar access is off. Re-enable it in iPhone Settings to manage read calendars here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .error(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let previewContainer = AppContainer.makePreview()
    SettingsView(
        settingsRepository: previewContainer.settingsRepository,
        alertRepository: previewContainer.alertRepository,
        alertScheduler: previewContainer.alertScheduler,
        homeLayoutRepository: previewContainer.homeLayoutRepository,
        projectRepository: previewContainer.projectRepository,
        routineRepository: previewContainer.routineRepository,
        calendarPermissionProvider: previewContainer.calendarPermissionProvider,
        calendarListingService: previewContainer.calendarListingService
    )
}
