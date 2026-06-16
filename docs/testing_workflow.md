# Testing Workflow

The SwiftUI Apple app in `apple_app/task-manager/` is the only active implementation surface.

Use `README.md`, `docs/life_assistant_vision.md`, and `docs/product_direction.md` as expected-behavior references for each session.

## 1. Baseline Automated Checks

From the repo root, run:

```bash
DERIVED_DATA_PATH=/tmp/task-manager-derived-data
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator -derivedDataPath "$DERIVED_DATA_PATH" build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator -derivedDataPath "$DERIVED_DATA_PATH" build-for-testing
bash scripts/check_swift_typecheck_complexity.sh
```

These are the default checks for coding sessions because they do not require booting a simulator runtime.

Use a writable temporary `DerivedData` location in sandboxed or locked-down environments. The default Xcode path under `~/Library/Developer/Xcode/DerivedData` can fail before app code is evaluated with errors such as `Couldn't create workspace arena folder`, `Unable to write to info file`, or `Operation not permitted`.

The compiler complexity guard runs the same simulator `build-for-testing` path with Swift frontend timing warnings enabled. It fails if a view body or expression starts taking long enough to type-check that it is likely to turn into Xcode's "unable to type-check this expression in reasonable time" error.

Current automated confidence covers:

- task models, repositories, and task-list presentation behavior
- planner engine ranking, gap handling, and selected-slot behavior
- planner view-model acceptance, rejection, lifecycle, and reconciliation behavior
- EventKit adapter behavior with mocked stores
- Home layout/execution view-model behavior, including capture conversion and module summaries
- Home widget model resolution and landing-target routing behavior
- capture capability routing and candidate generation for Tasks, Shopping, and Music Practice
- promise models, repositories, and Home aggregation behavior
- routine models, repositories, and daily completion behavior
- Shopping models, SwiftData repository round trips, view-model behavior, and inbox conversion
- Debrief model validation, queue filtering, queue-review composer state, and SwiftData round trips
- work-in-progress Health model calculations, nutrition catalog search/custom-food persistence, SwiftData repository round trips, Health view-model summaries, and meal debrief reminder timing
- Fitness model validation, SwiftData repository round trips, draft-session seeding, Fitness view-model state, and Home Fitness summaries
- Music Practice model validation, SwiftData repository round trips, view-model behavior, and Home summaries
- People Memory model validation, SwiftData repository round trips, view-model behavior, and Home summaries
- Vices model validation, SwiftData repository round trips, undo behavior, vice session grouping, and vice-session Debrief generation

## 1A. Area-Specific Battery Expectations

Use the baseline battery above, then add the narrowest matching targeted checks for the area you changed.

### Home / Capture / Widgets

- update or inspect `apple_app/task-manager/task-managerTests/Home/HomeExecutionViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Home/HomeLayoutViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Models/HomeWidgetModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Models/CaptureCapabilityTests.swift`
- manually verify Home widget summaries or Capture Review flows when the UI changed

### Routines

- update or inspect `apple_app/task-manager/task-managerTests/Routines/RoutineModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Routines/SwiftDataRoutineRepositoryTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Home/HomeExecutionViewModelTests.swift`
- manually verify routine creation, step reordering, step-link quick-action editing, and routine module landing-page launches when the UI changed

### Debriefs / Block Focus

- update or inspect `apple_app/task-manager/task-managerTests/Debrief/DebriefComposerViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Debrief/DebriefModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Debrief/DebriefQueueFlowTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Debrief/DebriefQueueViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Debrief/DebriefQueueServiceTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Persistence/SwiftDataDebriefRepositoryTests.swift`
- when touching `Features/Debrief/DebriefViews.swift`, run the iPhone-simulator `build`/`build-for-testing` first to catch actor-isolation and exhaustive-switch compile failures before chasing runtime behavior
- if you see `Main actor-isolated instance method ... cannot be called from outside of the actor` or `Switch must be exhaustive` in Debrief code, inspect closure annotations and `DebriefTemplateKind` coverage before looking at UI logic
- manually verify queue progression, quick-action auto-advance, pushed detail navigation, detailed prompts, and task-outcome UI only when those surfaces changed

### Vices

- update or inspect `apple_app/task-manager/task-managerTests/Vices/VicesViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Vices/ViceModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Vices/SwiftDataViceRepositoryTests.swift`
- manually verify vice undo, active-session summaries, and Debrief handoff UI only when those surfaces changed

### Fitness

- update or inspect `apple_app/task-manager/task-managerTests/Fitness/FitnessModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Fitness/FitnessViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Fitness/SwiftDataFitnessRepositoryTests.swift`
- run `bash scripts/check_swift_typecheck_complexity.sh` when touching large Fitness SwiftUI bodies, sheets, or navigation flows

### Planner / Calendar / EventKit

- update or inspect `apple_app/task-manager/task-managerTests/Planner/PlannerEngineTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Planner/PlannerViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Calendar/EventKitCalendarServicesTests.swift`
- reserve real EventKit/manual verification for behavior that cannot be proven with repository or view-model tests

### Health / Nutrition

- update or inspect `apple_app/task-manager/task-managerTests/Health/HealthModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Health/HealthViewModelTests.swift`
- update or inspect `apple_app/task-manager/task-managerTests/Health/SwiftDataHealthRepositoryTests.swift`
- manually verify custom-food creation, food search suggestions, and multi-entry meal logging only when the Health Nutrition UI changes

## 2. Optional Simulator Swift Runs

Use these only when simulator behavior is required for the change and CoreSimulator is available. Use `-only-testing` when narrowing scope, for example:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /tmp/task-manager-derived-data test -only-testing:task-managerTests/PlannerViewModelTests
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /tmp/task-manager-derived-data test -only-testing:task-managerTests/HomeExecutionViewModelTests
```

Use the iPhone simulator SDK builds to catch cross-platform compile regressions even when no simulator runtime is installed:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator -derivedDataPath /tmp/task-manager-derived-data build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator -derivedDataPath /tmp/task-manager-derived-data build-for-testing
```

If `xcrun simctl list runtimes` or `xcrun simctl list devices available` is empty, treat iPhone confidence on that machine as build-only confidence.

Recurring environment issue guidance:

- if `xcodebuild` fails with `CoreSimulatorService`, `simdiskimaged`, `actool`, provisioning-profile, or DerivedData-permission errors, treat that as a machine or sandbox problem first
- if the failure is `Couldn't create workspace arena folder`, `Unable to write to info file`, or another `Operation not permitted` error under `~/Library/Developer/Xcode/DerivedData`, rerun with `-derivedDataPath /tmp/task-manager-derived-data` before assuming app code is broken
- if the failure is `No available simulator runtimes for platform iphonesimulator` or `SimServiceContext supportedRuntimes=[]`, treat that as a CoreSimulator runtime outage; simulator-targeted `actool` work cannot complete until the host machine exposes at least one runtime
- run `bash scripts/diagnose_ios_dev_env.sh` when local environment diagnosis is relevant
- do not burn time repeatedly rerunning the same command without changing the failure class

## 3. Manual Session Helper

From the repo root:

```bash
bash scripts/manual_test_session.sh
```

That helper:

- runs an iPhone simulator build using a temporary DerivedData path
- runs the Swift compiler complexity guard
- creates a timestamped note in `docs/test_sessions/`
- prints the next recommended Swift, EventKit, simulator, Home, Capture Review, Debrief, Vices, Finance, and routine validation steps

Run simulator tests in the helper only when intentionally enabled:

```bash
RUN_IOS_SIMULATOR_TESTS=1 bash scripts/manual_test_session.sh
```

You still need to launch the Swift app from Xcode for real EventKit or hands-on simulator testing.

## 4. Current Manual Surface

Split manual testing by area depending on scope.

### Home / Promises

Validate:

- Home is the first visible tab
- Home widgets render and the card body opens the expected destination flow
- Home quick-action buttons run their own action directly instead of bubbling into the module launch
- long-pressing a Home widget enters edit mode, and edit-mode taps open widget quick-action editing instead of triggering the live widget action
- module widgets show configurable in-card quick-action buttons and those selections persist after relaunch
- promise module landing pages open from Home and from routine-step module links
- the Home banner shows a stable welcome message and the transient confirmation appears after in-place quick actions
- the App Refresh widget shows the last sideload/update time and a weekly reinstall countdown
- pending Debrief, Vices, People, Fitness, and other module summaries refresh after underlying data changes
- new promise creation
- active promise visibility on Home
- active-promise banner on Tasks and Planner
- kept check-in flow
- missed check-in flow with reflection
- reset promise creation
- kept/missed history counts
- no direct Apple Calendar writes from promises

### Routines

Validate:

- daily routine creation
- selected-weekday routine creation
- item ordering
- routine sessions show a top Edit action that pushes the step-list editor
- routine editing supports adding steps and drag-reordering from the pushed editor
- routine-step module links open the module landing page instead of the Home default action
- routine-step quick buttons can be customized independently from the Home board
- Home visibility for routines active today
- item completion and uncompletion
- per-day completion persistence after relaunch
- no direct Apple Calendar writes from routines

### Tasks

Validate:

- task create, edit, delete
- search, sort, and grouping
- quick complete, reopen, and archive flows
- capture review still routes task-like captures through the shared task form when relevant
- iPhone quick add and narrow-width task review if a simulator or device is available

### Capture Review / Inbox

Validate:

- create or load a raw capture
- confirm candidate groups appear for Tasks, Shopping, and Music Practice when applicable
- convert one capture into a task
- convert one capture into a shopping item
- convert one capture into a practice piece
- confirm processed captures leave the active review queue

### Calendar / Planner And EventKit

Validate:

- permission-state copy for not-determined, granted, denied, restricted, or write-only states when reachable
- readable calendar listing and excluded-calendar labeling
- selected-day timeline rendering
- selected-slot creation, drag expansion, and clearing
- slot-based suggestion generation
- horizon-based suggestion generation
- accept, reject, edit, reschedule, cancel, and delete flows
- write-calendar routing
- reconciliation after external calendar moves and deletes

### Health

Validate:

- quick sleep check-in entry and persistence
- completed PVT session saving
- real-time PVT tap flow timing on device or simulator
- meal and workout quick logs
- custom food creation and persistence when Nutrition UI changes
- food search suggestions and tap-to-fill behavior when Nutrition UI changes
- multi-entry meal logging with servings and meal-level notes when Nutrition UI changes
- meal debrief reminder timing that lands three hours after the meal timestamp
- Health history and delete flows
- neutral 7/30-day trend summaries
- nutrient totals and 7/30-day nutrition aggregates when Nutrition trend UI changes

### Shopping

Validate:

- open Shopping from Home
- add a shopping item from the module screen
- add a shopping item from the Home quick-add widget
- group active items by store type
- mark items bought, skipped, archived, reopened, and deleted
- search active and history lists

### Fitness

Validate:

- open Fitness from Home
- create Push Day, Pull Day, and Leg Day workout days
- create one strength exercise and one bike-style metric exercise
- add existing exercises to a workout day
- log sessions from both the exercise list and workout day flow
- confirm draft quick-log values seed from the most recent session for that exercise
- confirm last-session references refresh immediately
- confirm logged-today state appears after same-day logging
- confirm Recent, A-Z, and Tag sorting
- confirm the older Health workout log still works unchanged

### Music Practice

Validate:

- open Music Practice from Home
- add a practice piece
- log a practice session with and without a piece
- confirm recent sessions, 7/30-day totals, focus-area breakdown, and stale-piece visibility refresh

### People Memory

Validate:

- open People Memory from Home
- add a person with meeting context and tags
- search by name, details, and tag text
- start a study review and apply easy/almost/missed ratings
- confirm due-review counts and saved-person counts refresh on Home

### Debriefs / Block Focus

Validate:

- complete a Debrief from a quick outcome without opening detailed prompts
- confirm Debriefs are presented one at a time like Capture Review
- confirm tapping a quick debrief button saves immediately and advances to the next candidate
- confirm the optional Later action moves the current candidate to the back of the in-memory queue
- reopen the same Debrief into the detailed prompt flow
- confirm a detailed Debrief save advances to the next candidate
- confirm template inference matches the source type when applicable
- when a Block Focus-backed work block exists, confirm selected-task outcomes can be reviewed without writing to Apple Calendar

### Vices

Validate:

- create or edit a vice
- log a hit from the main vice card
- repeat the most recent active vice from Home and confirm the Home summary updates without navigation
- confirm the repeat-last Home quick action shows a gentle inline message when no prior active vice log exists
- undo a recent hit inside the undo window
- confirm repeated hits inside the session window aggregate into one active session
- confirm session closure creates at most one pending Vice Session Debrief candidate

### Finance

Validate:

- open Finance from Home
- add one income and one expense
- confirm the monthly balance updates
- confirm category summaries and transaction history refresh
- confirm delete flows still update the dashboard totals

### iPhone Runtime Pass

Validate when a simulator runtime exists:

- app launch
- Home layout
- promise creation and check-in sheets
- routine builder and checklist sheets
- task quick add
- task edit and swipe actions
- planner screen layout
- selected-slot interactions
- permission-state copy and recovery messaging on phone layout

## 5. Manual EventKit Checklist

Use this checklist when you have a real macOS calendar account available:

- permission states:
  - not determined
  - granted full access
  - denied
  - restricted if reproducible
  - write-only if reproducible
- excluded read calendars:
  - confirm excluded calendars do not contribute busy time
  - confirm included calendars still do
- write calendar:
  - confirm the configured write calendar is used
  - confirm missing or ambiguous write-calendar configuration fails clearly
- accepted suggestion flow:
  - generate a suggestion
  - accept it
  - confirm the linked event is created in the correct calendar
- accepted block lifecycle:
  - edit
  - reschedule
  - cancel
  - delete
  - confirm matching EventKit updates or deletes happen
- reconciliation:
  - move the linked event externally in Calendar.app
  - delete the linked event externally in Calendar.app
  - confirm the app refreshes or reconciles the local block state correctly
- error handling:
  - missing write calendar
  - non-writable write calendar
  - revoked permission after launch
  - event missing at update or delete time

## 6. Manual Logging Protocol

For each issue, capture:

- area
- exact steps
- expected behavior
- actual behavior
- severity
- whether it blocks testing or is polish

Keep issue notes short during the session. Rewrite them later only if they turn into tracked bug work.

## 7. Recurring Failure Themes To Test Ahead Of Time

- SwiftUI compiler complexity:
  - if a view body gained more nesting, more sheets, more navigation destinations, or more inline bindings, run `bash scripts/check_swift_typecheck_complexity.sh`
  - if it reports long type-check warnings, split the body before merging
- Cross-module Home regressions:
  - if a feature publishes a Home summary, widget, or quick action, verify `HomeExecutionViewModelTests` and the matching manual Home summary flow
- Debrief source drift:
  - if a source type, template, or vice-session rule changes, verify both the data-model tests and the queue/composer behavior
- Environment false negatives:
  - if builds fail before Swift compilation because of simulator runtimes, provisioning profiles, or DerivedData permissions, diagnose and document the environment issue instead of misclassifying it as an app regression
