**All agents should always read [AGENTS.md](AGENTS.md) before using this repository.**

# My Life Manager

`my-life-manager` is a SwiftUI iOS app that is evolving from a task manager into a broader personal planning and life-assistant app. The active product surface is the Apple app in `apple_app/task-manager/`. The repo also contains product docs, domain notes, and manual test artifacts that explain intended behavior beyond what is already polished in the app.

This README is written as an agent-orientation document. A capable coding agent should be able to read this file and get a near-complete sense of:

- what the repo is for
- which implementation surface matters
- how the app is structured
- where business logic, persistence, and UI live
- what major feature domains exist
- what is implemented vs. aspirational
- how to verify changes
- what files and folders exist in the repo

## Status

Current status is active work in progress.

- The SwiftUI app is the only active implementation path.
- The app shell is stable enough to navigate and extend.
- Several modules are implemented enough to have models, repositories, views, and tests.
- Some domains are still incomplete or intentionally lightweight: Health, Music Practice, Fitness, Shopping, People Memory, Vices, Debriefs, Calendar Block Focus, and Sync should be treated as evolving surfaces rather than finished consumer features.
- Product docs in `docs/` describe intended direction and frequently go beyond current UX polish.

## Product Summary

The app combines four responsibilities:

1. App-owned tasks and related metadata.
2. Calendar-aware planning that reads Apple Calendar busy time.
3. User-accepted planner output written back to Apple Calendar through EventKit.
4. A Home execution layer that surfaces summaries, widgets, quick actions, and entry points into supporting life domains.

The current top-level tab shell is:

- `Home`
- `Tasks`
- `Projects`
- `Settings`

Important nuance:

- `Home` is the main execution dashboard and entry point into many modules.
- Planner, Debriefs, Block Focus, Finance, Shopping, Health, Fitness, Music Practice, People Memory, and Vices are surfaced from Home flows rather than each owning a top-level tab.
- `ProjectsView` currently lives inside `Features/Home/HomeView.swift`, so "Projects" is a visible product area even though its implementation is still colocated inside the large Home feature file.

## Recently Implemented Workflows

These are worth knowing because they are no longer just aspirational product notes:

- Capture Review is now module-aware and candidate-driven. Raw captures can be reviewed into task, shopping, or music-practice candidates instead of being forced through a single universal conversion form.
- Debriefs now support a queue-style review flow that mirrors Capture Review. Pending debriefs are presented one at a time, quick outcomes gate a pushed detail screen, and finishing or skipping immediately advances to the next pending item.
- Debriefs support more than calendar-only sources. The durable model and inference layer now handle work blocks, meetings, social hangouts, music practice, jam sessions, vice sessions, routines, and custom entries.
- Work-block Debriefs can reuse Block Focus context so the user can review selected tasks and capture per-task outcomes after a block ends.
- Vices now have session grouping on top of atomic hit logs. Repeated hits inside the same window roll into a `ViceSession`, and session closure can queue one Debrief candidate instead of spamming multiple reflections.
- Vices tap cards can also hold one active limit goal per vice. The limit is created from the same one-tap card, tracks occurrences in an explicit start-to-deadline window, and renders an inline green/yellow/red progress bar until the deadline passes.
- Fitness quick-log flows can seed a draft from the most recent session for the same exercise, while still preserving explicit edit flows for existing logs, partial-rep strength sets, session notes, cardio presets, and saved route reuse from the same editor flow.
- Health Nutrition now has foundational calorie-and-macros plumbing under the existing lightweight meal log. Meals can carry multiple itemized entries, each entry stores per-serving nutrient snapshots, meals are oriented around timestamp plus itemized foods rather than meal types, and the Health repository now supports a starter searchable food catalog plus persisted custom foods.
- Routines now have a dedicated module landing screen plus an in-routine editor. Routine sessions expose a top Edit action that pushes a step-list editor with add/reorder support, and routine module widgets inside steps can open the module landing page instead of the Home default action.

## Source Of Truth And Architecture

These contracts are central to the repo and should not be casually violated.

- SwiftData is the source of truth for app-owned durable data.
- Apple Calendar is external reality, not the source of truth for tasks.
- EventKit reads existing calendar state and writes accepted plan output.
- `ScheduledBlock` is the bridge between in-app planning and calendar events.
- Planner logic should remain testable outside SwiftUI.
- Business logic should live in models, repositories, services, and view models rather than in SwiftUI views.
- Home widgets are lightweight summaries, module launch points, and quick actions. Quick actions can now be either navigation-style launches or in-place commands, depending on the widget definition.
- Full workflows belong in feature/module screens.
- Sync exists as scaffolding and exploration, not as an active end-user feature unless a task explicitly asks for sync work.

Calendar-specific rules:

- Only Planner / ScheduledBlock flows should write to Apple Calendar.
- Block Focus records are app-owned SwiftData records that annotate calendar work; they do not write calendar events.
- Debriefs read calendar context but store debrief state in SwiftData.

### Home Widget System

Home widget definitions, quick actions, and registry metadata live in:

- `apple_app/task-manager/task-manager/Models/HomeWidgetModels.swift`
- `apple_app/task-manager/task-manager/Features/Home/Widgets/HomeWidgetRendering.swift`

Home widget persistence uses the existing SwiftData-backed Home layout record:

- `apple_app/task-manager/task-manager/Persistence/SwiftDataModels/HomeLayoutRecord.swift`
- `apple_app/task-manager/task-manager/Persistence/SwiftDataRepositories/SwiftDataHomeLayoutRepository.swift`

Implementation notes:

- `HomeWidgetRegistry` owns the canonical widget descriptors and the module widget definitions.
- `HomeWidgetDefinition` describes a module widget's title, main destination, default quick actions, and available quick actions.
- `HomeWidgetConfiguration` stores durable per-widget state, including selected quick action IDs, visibility, sort order, size, and legacy configuration values.
- `HomeView` renders module widgets from registry definitions and widget configurations instead of hardcoding module-specific quick buttons in the view body.
- Module widgets open their destination when the card body is tapped, while quick-action buttons run their own action directly.
- `HomeWidgetQuickActionResolver` is the shared rule set for choosing up to two quick actions, and both Home widgets and routine-step module widgets use it.
- Routine-step module widgets store their own quick-action selection on `RoutineStepLink`, so step-specific widget customization stays independent from the Home board.
- Routine-step module widgets open dedicated module landing pages when tapped from a routine, while the Home board keeps its existing default-action behavior.
- Long-pressing a widget enters edit mode in the iPhone-home-screen style. In edit mode, the tile itself can be tapped to edit quick actions, and resize/remove controls remain available in the widget chrome.
- Module widgets render up to two configurable quick-action buttons inside the card instead of using the old small-card numeric summary slot.
- Quick-action choices are capped at two per widget. Invalid or deleted quick-action IDs are filtered out when widgets are rendered, and registry defaults are used until the user customizes the widget.
- The Home screen now uses a small curated welcome banner and transient inline feedback for in-place command actions such as the Vices repeat-last quick action.
- The Home board also includes an App Refresh widget that records the last sideloaded build timestamp and shows a weekly reinstall reminder on Home.

To add a new widget-enabled module:

1. Add the module's main widget descriptor and module definition in `HomeWidgetModels.swift`.
2. Declare the module's available quick actions in its `HomeWidgetDefinition`.
3. Map the quick action IDs and action behavior to routing/command behavior in `HomeView`'s generic quick-action handler.
4. Add the module widget to the default Home layout if it should appear on first launch.

On first launch or when Home layout data is missing, the app seeds a deterministic default layout and the module widget defaults come from the registry definition.

## Implementation Surface

The app entry path is:

- `apple_app/task-manager/task-manager/task_managerApp.swift`
- `apple_app/task-manager/task-manager/ContentView.swift`
- `apple_app/task-manager/task-manager/App/AppContainer.swift`
- `apple_app/task-manager/task-manager/App/AppEnvironment.swift`

What these files do:

- `task_managerApp.swift` boots the app and injects the shared SwiftData container.
- `ContentView.swift` builds the four-tab shell.
- `AppContainer.swift` constructs live and preview repositories/services and is the clearest dependency map in the codebase.
- `AppEnvironment.swift` exposes those dependencies to the app shell and feature entry points.

`AppContainer.makeLive()` is especially useful for orientation because it shows:

- all repository protocols currently expected by the app
- which repositories already have SwiftData implementations
- where EventKit services are created
- which modules are seeded or initialized on launch

## Feature And Domain Map

### Core App Areas

- `Tasks`: canonical task data and task list workflows.
- `Projects`: project, capture, and project-item workflows; currently implemented inside the Home feature file plus shared task/project models.
- `Planner`: planning engine and view-model logic for generating and accepting suggestions.
- `Settings`: app-owned settings and calendar configuration.
- `Home`: execution dashboard and widget layout owner.

### Supporting Domains Surfaced From Home

- `Promises`: commitment/check-in workflows.
- `Routines`: recurring daily/weekly routines with completion logging.
- `Shopping`: practical shopping list capture and history.
- `Health`: lightweight health logs and summaries, including an evolving Nutrition layer with multi-entry meals, per-serving nutrient snapshots, searchable food catalog plumbing, and meal debrief reminder timing.
- `Fitness`: structured workout/exercise tracking with workout templates, latest-session-seeded quick logs, cardio presets, route reuse, and edit-in-place session history.
- `Music Practice`: pieces and session logging, plus capture-review conversion into practice pieces.
- `People Memory`: names, contexts, tags, and spaced-review style study flows.
- `Vices`: personal vice tracking with lightweight one-tap logs, card-level per-vice limit goals, live elapsed-time summaries, and session-aware debrief generation for smoking-style patterns.
- `Finance`: manual local-only expense/income tracking with a month overview, plus/minus entry flow, category-tap save, and category summaries.
- `Debriefs`: app-owned reflection records with a queue-style quick-review flow, task-outcome capture for work blocks, multi-source template inference, and detailed prompts when needed.
  - the queue loader/persister should stay actor-safe: keep repository access inside `@MainActor` closures or methods, and update exhaustive template switches when `DebriefTemplateKind` changes
- `Calendar Block Focus`: app-owned focus/intention metadata for calendar blocks.
- `Sync`: local sync scaffolding and status/settings UI, not a finished sync product.

### Cross-Cutting Workflows

- `Capture Review`: shared capture intake and module-specific conversion for tasks, shopping, and music practice.
- `Home Widgets`: persisted Home board with module widgets, quick actions, pending Debriefs, and summary cards that aggregate many repositories in one place.
- `Debrief + Block Focus`: post-event reflection can reuse pre-event task selection and intent context without writing back to Apple Calendar.
- `Vice Session -> Debrief`: vice hits remain atomic logs, but eligible hits are also grouped into sessions that can produce one follow-up Debrief when the session window closes.

### Current Maturity Heuristic

Reasonably established in code shape:

- Tasks
- Planner
- Home layout/execution
- Settings
- Routines
- Promises
- Shopping
- Finance

Implemented but still clearly evolving:

- Health
- Fitness, including seeded quick logs, workout drill-down flows, route reuse, and shared create/edit session logging
- Music Practice
- People Memory
- Vices, including vice sessions and Debrief handoff
- Debriefs, including queue-style quick review, quick-action auto-advance, and Block Focus task-outcome capture
- Calendar Block Focus
- Sync

## Code Layout

### App Shell

- `apple_app/task-manager/task-manager/App/`
  - dependency construction and environment wiring
- `apple_app/task-manager/task-manager/ContentView.swift`
  - top-level tab shell
- `apple_app/task-manager/task-manager/task_managerApp.swift`
  - app bootstrap

### Domain Models

- `apple_app/task-manager/task-manager/Models/`
  - domain types for tasks, routines, health, shopping, scheduling, promises, people memory, fitness, vices, music practice, debriefs, block focus, and home widgets

Notable files:

- `MyTask.swift`
  - task, project, capture, and project-item related model types live here
- `CaptureModels.swift`
  - shared raw capture, capture candidate, and capture module metadata types
- `CaptureCapabilityService.swift`
  - small module capability registry that drives Capture Review
- `Features/Debrief/DebriefViews.swift`
  - queue-first Debrief screen, detail navigation, and the queue controller
  - common failure mode: `@MainActor` repository calls escaping through nonisolated closures will compile-fail here before runtime tests ever run
- `SchedulingModels.swift`
  - scheduled blocks and planning-adjacent shared models
- `TaskListPresentation.swift`
  - presentation logic for task list grouping/sorting structures

Health nutrition note:

- `HealthModels.swift` now holds both the older meal-log shell and the newer nutrition primitives used underneath it.
- `NutritionFacts` stores per-serving calories, protein, carbs, sugars, fiber, and optional sodium.
- `FoodCatalogItem` represents a built-in or custom searchable food.
- `MealEntry` stores a meal line item with servings and a nutrient snapshot so later food edits do not rewrite historical meals.
- `MealLog` can now carry multiple entries while still preserving the older summary/note shape used by the current Health UI.
- Meal rows now surface the derived debrief reminder time, which is three hours after the meal timestamp.

### Feature UI And View Models

- `apple_app/task-manager/task-manager/Features/`
  - most feature-specific SwiftUI views and view models
- `apple_app/task-manager/task-manager/Views/`
  - older shared or cross-feature views such as task form, planner view, and quick add

Capture review note:

- Capture Review is now candidate-driven and module-aware rather than a hardcoded universal form.
- Tasks, Shopping, and Music Practice expose capture candidates through the shared capability registry.
- Task creation still reuses `TaskFormView` and `MyTaskFormData`; shopping and music practice reuse their module-owned forms where practical.

Important detail:

- Some newer modules are neatly split into feature folders.
- Some older surfaces still have large colocated files, especially `Features/Home/HomeView.swift`.
- The Projects UI currently lives in `HomeView.swift`, so not every feature boundary is represented by a matching folder yet.

### Planner And Calendar

- `apple_app/task-manager/task-manager/Planner/`
  - planning engine and planning contracts
- `apple_app/task-manager/task-manager/Calendar/`
  - calendar contracts, stubs, and EventKit-backed services

Use this split as the intended design:

- planner ranking/slotting logic in `Planner/`
- Apple Calendar integration in `Calendar/`
- planner UI/view-model glue in `Features/Planner/` and `Views/PlannerView.swift`

### Persistence

- `apple_app/task-manager/task-manager/Persistence/Repositories/`
  - protocol contracts
- `apple_app/task-manager/task-manager/Persistence/SwiftDataRepositories/`
  - concrete SwiftData implementations
- `apple_app/task-manager/task-manager/Persistence/SwiftDataModels/`
  - SwiftData record models
- `apple_app/task-manager/task-manager/Persistence/ModelContainerFactory.swift`
  - SwiftData container construction

Repository coverage visible in the tree:

- Task
- Settings
- Home layout
- Scheduled block
- Promise
- Routine
- Shopping
- Health
- Fitness
- Music Practice
- People Memory
- Vice
- Debrief
- Calendar Block Focus
- Finance

Project/capture/project-item repository protocols and implementations are still important app concepts, but they currently live in the task-related files rather than in separate repository files.

Health repository scope now includes:

- sleep check-ins
- meal logs
- meal-entry-backed nutrition totals
- starter food-catalog search
- persisted custom food catalog items
- workout logs
- PVT sessions

### Sync

- `apple_app/task-manager/task-manager/Sync/`
  - sync engine, snapshot, manifest, change batch, device identity, conflict types, folder access, and status types
- `apple_app/task-manager/task-manager/Features/Sync/`
  - sync-facing UI/view-model layer

Treat sync as scaffolding unless the task explicitly requires sync work.

## Tests

The main automated coverage is in:

- `apple_app/task-manager/task-managerTests/`

Test coverage is organized by domain:

- `Calendar/`
- `Debrief/`
- `Features/`
- `Finance/`
- `Fitness/`
- `Health/`
- `Home/`
- `Models/`
- `MusicPractice/`
- `PeopleMemory/`
- `Persistence/`
- `Planner/`
- `Promises/`
- `Routines/`
- `Settings/`
- `Shopping/`
- `Vices/`

Broadly, the tests focus on:

- model behavior
- repository round trips
- planner logic
- home execution/view-model behavior
- domain-specific view-model behavior
- EventKit adapter behavior with test doubles
- capture capability routing and inbox conversion
- Debrief template inference, queue-first composer state, queue advancement, and persistence
- vice session grouping, undo timing, session closure, and Debrief generation
- Fitness draft-session seeding, route persistence, cardio preset logging, and Home summary behavior
- Health nutrition catalog search, custom-food persistence, meal-entry nutrient aggregation, and existing meal/workout/PVT summaries

The standard battery, targeted area-specific checks, and recurring failure-mode guidance live in `docs/testing_workflow.md`.

## Documentation Layout

Top-level docs:

- `docs/life_assistant_vision.md`
  - broader product framing
- `docs/product_direction.md`
  - frozen product responsibilities and source-of-truth rules
- `docs/iphone_product_scope.md`
  - iPhone-specific framing
- `docs/testing_workflow.md`
  - recommended build/test/manual QA workflow

Domain docs:

- `docs/domains/`
  - active domain notes such as promises, routines, shopping, debriefs, calendar block focus, and the older today dashboard framing
- `docs/domains/future-modules/`
  - future or partially implemented module direction notes

Manual test artifacts:

- `docs/manual_test_session_template.md`
- `docs/test_sessions/`

Helper scripts:

- `scripts/check_swift_typecheck_complexity.sh`
  - runs the usual simulator `build-for-testing` path with long-typecheck warnings enabled and fails if SwiftUI bodies or expressions become compiler hot spots
- `scripts/diagnose_ios_dev_env.sh`
  - checks local Xcode, simulator, provisioning-profile, DerivedData, and build-path health when machine-specific iOS tooling is failing
- `scripts/manual_test_session.sh`
  - creates a manual QA note, runs the simulator build plus compiler-complexity guard, and prints the current manual checklist

## How To Work In This Repo

Preferred workflow for agents and humans:

1. Read `AGENTS.md`.
2. Read this README.
3. Read the domain doc in `docs/` that matches the change.
4. Find the existing model, repository, and view model before editing SwiftUI.
5. Make the smallest correct change.
6. Prefer existing patterns over new abstractions.
7. Run the narrowest useful verification.
8. Update docs when behavior, structure, or repo shape changed.

### Verification Guidance

Per repo guidance, prefer deterministic, non-simulator checks first.

Agents should avoid simulator testing by default to conserve tokens. Use simulator-based runs only when the change truly requires runtime UI validation that narrower deterministic checks cannot cover.

Agents may be running in a sandboxed environment with restricted access to CoreSimulator, UI services, logs, parts of the filesystem, or other machine-level OS state. Treat failures that point to those constraints as possible sandbox limitations first. Do not spend excessive effort trying to repair host-machine configuration from inside the sandbox; report the limitation, explain what was still verified, and let the user run the machine-local command when needed.

Primary compile check:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/task-manager-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Other common checks from `docs/testing_workflow.md`:

```bash
DERIVED_DATA_PATH=/tmp/task-manager-derived-data
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator -derivedDataPath "$DERIVED_DATA_PATH" build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator -derivedDataPath "$DERIVED_DATA_PATH" build-for-testing
bash scripts/check_swift_typecheck_complexity.sh
```

In sandboxed sessions, prefer the temporary `DerivedData` override above. The default Xcode path under `~/Library/Developer/Xcode/DerivedData` may be unreadable or unwritable even when the repo itself is writable, which produces host-environment failures before the app build is meaningfully evaluated.

Use the compiler complexity guard when you touch large SwiftUI bodies. It runs the standard simulator `build-for-testing` battery with extra Swift frontend timing warnings enabled and fails if a body or expression starts taking long enough to risk the usual "unable to type-check this expression in reasonable time" compiler error.

Match the standard battery to the area you changed:

- Home, Capture Review, and widget work should usually include the Home/Capture-focused checks in `docs/testing_workflow.md`.
- Debrief and Block Focus changes should usually include the Debrief-focused checks in `docs/testing_workflow.md`.
- Vices changes should usually include the Vices-focused checks in `docs/testing_workflow.md`.
- Large SwiftUI edits should usually include the compiler complexity guard even when the logic tests are otherwise narrow.

Manual session helper:

```bash
bash scripts/manual_test_session.sh
```

Simulator testing should be used sparingly and only when the change really requires runtime UI behavior.

Local iOS environment diagnostics:

```bash
bash scripts/diagnose_ios_dev_env.sh
```

Use this when Xcode reports simulator, DerivedData, or CoreSimulator errors on the local machine. It checks toolchain availability, writable Xcode paths, simulator runtime/device visibility, CoreSimulator responsiveness, and a dry-run iPhone build with a temporary DerivedData directory.

The diagnostic battery also checks:

- whether an existing `task-manager-*` DerivedData folder is writable
- whether cached provisioning profiles in Xcode's UserData directory decode cleanly
- whether the build log points to DerivedData permissions, provisioning cache corruption, or CoreSimulator service failures
- whether a writable temporary DerivedData path is enough to recover a build that was failing only because the default Xcode cache location was blocked

### Recurring Issue Themes

- SwiftUI compiler complexity is a real recurring risk in this repo. Large nested `body` expressions, especially in `HomeView.swift` and feature views with multiple sheets/destinations, can turn into "unable to type-check this expression in reasonable time" failures. Prefer extracting subviews and helper properties before the body gets large, and run `bash scripts/check_swift_typecheck_complexity.sh` after touching those surfaces.
- Host-machine iOS tooling issues can fail builds before app code is meaningfully evaluated. Missing simulator runtimes, `CoreSimulatorService` disconnects, `actool` runtime lookup failures, invalid cached provisioning profiles, and unwritable DerivedData folders should be treated as environment failures first. Use `bash scripts/diagnose_ios_dev_env.sh` and report the exact class of failure rather than repeatedly rerunning the same broken command.
- Two concrete failure signatures are worth recognizing quickly:
  - `Couldn't create workspace arena folder`, `Unable to write to info file`, or `Operation not permitted` under `~/Library/Developer/Xcode/DerivedData`: rerun with `-derivedDataPath /tmp/task-manager-derived-data` before blaming app code.
  - `No available simulator runtimes for platform iphonesimulator`, `SimServiceContext supportedRuntimes=[]`, `CoreSimulatorService connection became invalid`, or `simdiskimaged` disconnects during `actool`: the host machine is missing a usable simulator runtime or simulator services are down, so simulator-targeted builds cannot fully complete from that environment.
- Home is an aggregation surface, so regressions often come from cross-module summaries instead of the screen you edited directly. When touching Capture Review, Debriefs, Fitness, People Memory, Vices, Promises, or widget quick actions, explicitly consider the corresponding Home summary and `HomeExecutionViewModel` behavior.
- Documentation and verification drift are easy to introduce because the repo has many evolving modules and large feature files. When you add a new source type, helper script, test file, or workflow, update `README.md`, `docs/testing_workflow.md`, and the relevant domain doc in the same change.

## Known Structural Realities

These are worth knowing before editing:

- `Features/Home/HomeView.swift` is a large file and currently contains more than just a narrow Home dashboard.
- `Features/Home/HomeView.swift` and some feature views are large enough that compiler type-check performance can become a productively important constraint, not just a cosmetic concern.
- `ContentView.swift` still presents only four tabs even though the product surface is broader.
- Multiple newer domains are reachable from Home widgets or Home-linked navigation rather than from dedicated top-level tabs.
- Promises and Routines now also have dedicated feature screens under `Features/Promises/PromisesFeatureViews.swift` and `Features/Routines/RoutinesFeatureViews.swift`, while Shopping has a reusable quick-add sheet at `Features/Shopping/ShoppingQuickAddSheet.swift`.
- Some product docs describe target behavior that is directionally true but not fully implemented.
- Existing user changes may be present in the worktree; do not revert unrelated edits.

## Repo Tree

The following is the current repository tree as observed from the repo root, excluding generated `.deriveddata`, `.derived-data`, `.git`, and `.DS_Store` noise.

```text
.
├── .gitignore
├── AGENTS.md
├── README.md
├── scripts
│   ├── check_swift_typecheck_complexity.sh
│   ├── diagnose_ios_dev_env.sh
│   └── manual_test_session.sh
├── apple_app
│   └── task-manager
│       ├── task-manager
│       │   ├── App
│       │   │   ├── AppContainer.swift
│       │   │   └── AppEnvironment.swift
│       │   ├── Assets.xcassets
│       │   │   ├── AccentColor.colorset
│       │   │   │   └── Contents.json
│       │   │   ├── AppIcon.appiconset
│       │   │   │   ├── AppIcon-128.png
│       │   │   │   ├── AppIcon-128@2x.png
│       │   │   │   ├── AppIcon-16.png
│       │   │   │   ├── AppIcon-16@2x.png
│       │   │   │   ├── AppIcon-256.png
│       │   │   │   ├── AppIcon-256@2x.png
│       │   │   │   ├── AppIcon-32.png
│       │   │   │   ├── AppIcon-32@2x.png
│       │   │   │   ├── AppIcon-512.png
│       │   │   │   ├── AppIcon-512@2x.png
│       │   │   │   ├── AppIcon-iPhone-20@2x.png
│       │   │   │   ├── AppIcon-iPhone-20@3x.png
│       │   │   │   ├── AppIcon-iPhone-29@2x.png
│       │   │   │   ├── AppIcon-iPhone-29@3x.png
│       │   │   │   ├── AppIcon-iPhone-40@2x.png
│       │   │   │   ├── AppIcon-iPhone-40@3x.png
│       │   │   │   ├── AppIcon-iPhone-60@2x.png
│       │   │   │   ├── AppIcon-iPhone-60@3x.png
│       │   │   │   └── Contents.json
│       │   │   └── Contents.json
│       │   ├── Calendar
│       │   │   ├── CalendarContracts.swift
│       │   │   ├── CalendarStubServices.swift
│       │   │   └── EventKit
│       │   │       ├── EventKitCalendarEventStore.swift
│       │   │       └── EventKitCalendarServices.swift
│       │   ├── ContentView.swift
│       │   ├── Features
│       │   │   ├── Debrief
│       │   │   │   └── DebriefViews.swift
│       │   │   ├── Finance
│       │   │   │   ├── Models
│       │   │   │   │   └── FinanceModels.swift
│       │   │   │   ├── Services
│       │   │   │   │   ├── FinanceFormatting.swift
│       │   │   │   │   └── FinanceSummaryService.swift
│       │   │   │   ├── ViewModels
│       │   │   │   │   ├── FinanceDashboardViewModel.swift
│       │   │   │   │   └── FinanceTransactionEntryViewModel.swift
│       │   │   │   └── Views
│       │   │   │       ├── FinanceDashboardView.swift
│       │   │   │       ├── FinanceTransactionEntryView.swift
│       │   │   │       └── FinanceTransactionListView.swift
│       │   │   ├── Fitness
│       │   │   │   ├── FitnessView.swift
│       │   │   │   └── FitnessViewModel.swift
│       │   │   ├── Health
│       │   │   │   ├── HealthView.swift
│       │   │   │   └── HealthViewModel.swift
│       │   │   ├── Home
│       │   │   │   ├── AddHomeWidgetView.swift
│       │   │   │   ├── HomeCustomizationView.swift
│       │   │   │   ├── HomeExecutionViewModel.swift
│       │   │   │   ├── HomeFeatureNotes.md
│       │   │   │   ├── HomeLayoutViewModel.swift
│       │   │   │   ├── HomeView.swift
│       │   │   │   └── Widgets
│       │   │   │       ├── HomeWidgetQuickActionSelectionView.swift
│       │   │   │       └── HomeWidgetRendering.swift
│       │   │   ├── Logs
│       │   │   │   └── LogsFeatureNotes.md
│       │   │   ├── MusicPractice
│       │   │   │   ├── MusicPracticeView.swift
│       │   │   │   └── MusicPracticeViewModel.swift
│       │   │   ├── PeopleMemory
│       │   │   │   ├── PeopleMemoryView.swift
│       │   │   │   └── PeopleMemoryViewModel.swift
│       │   │   ├── Planner
│       │   │   │   ├── PlannerPresentationModels.swift
│       │   │   │   ├── PlannerTimelineSelection.swift
│       │   │   │   └── PlannerViewModel.swift
│       │   │   ├── Promises
│       │   │   │   └── PromisesFeatureViews.swift
│       │   │   ├── Debrief
│       │   │   │   └── DebriefViews.swift
│       │   │   ├── Practice
│       │   │   │   └── PracticeFeatureNotes.md
│       │   │   ├── Reflection
│       │   │   │   └── ReflectionFeatureNotes.md
│       │   │   ├── Routines
│       │   │   │   ├── RoutinesFeatureNotes.md
│       │   │   │   └── RoutinesFeatureViews.swift
│       │   │   ├── Settings
│       │   │   │   └── SettingsView.swift
│       │   │   ├── Shopping
│       │   │   │   ├── ShoppingListView.swift
│       │   │   │   ├── ShoppingListViewModel.swift
│       │   │   │   └── ShoppingQuickAddSheet.swift
│       │   │   ├── Sync
│       │   │   │   ├── SyncSettingsView.swift
│       │   │   │   ├── SyncStatusView.swift
│       │   │   │   └── SyncViewModel.swift
│       │   │   ├── Tasks
│       │   │   │   └── TaskListViewModel.swift
│       │   │   └── Vices
│       │   │       ├── VicesView.swift
│       │   │       └── VicesViewModel.swift
│       │   ├── Models
│       │   │   ├── CaptureCapabilityService.swift
│       │   │   ├── CaptureModels.swift
│       │   │   ├── CalendarBlockFocusModels.swift
│       │   │   ├── DebriefModels.swift
│       │   │   ├── FitnessModels.swift
│       │   │   ├── HealthModels.swift
│       │   │   ├── HomeWidgetModels.swift
│       │   │   ├── MusicPracticeModels.swift
│       │   │   ├── MyTask.swift
│       │   │   ├── MyTaskFormData.swift
│       │   │   ├── PeopleMemoryModels.swift
│       │   │   ├── PromiseModels.swift
│       │   │   ├── RoutineModels.swift
│       │   │   ├── SchedulingModels.swift
│       │   │   ├── ShoppingModels.swift
│       │   │   ├── TaskListPresentation.swift
│       │   │   └── ViceModels.swift
│       │   ├── Persistence
│       │   │   ├── ModelContainerFactory.swift
│       │   │   ├── Repositories
│       │   │   │   ├── DebriefRepository.swift
│       │   │   │   ├── FinanceRepository.swift
│       │   │   │   ├── FitnessRepository.swift
│       │   │   │   ├── HealthRepository.swift
│       │   │   │   ├── HomeLayoutRepository.swift
│       │   │   │   ├── MusicPracticeRepository.swift
│       │   │   │   ├── PeopleMemoryRepository.swift
│       │   │   │   ├── PromiseRepository.swift
│       │   │   │   ├── RoutineRepository.swift
│       │   │   │   ├── ScheduledBlockRepository.swift
│       │   │   │   ├── SettingsRepository.swift
│       │   │   │   ├── ShoppingRepository.swift
│       │   │   │   ├── TaskRepository.swift
│       │   │   │   └── ViceRepository.swift
│       │   │   ├── SwiftDataModels
│       │   │   │   ├── AppSettingsRecord.swift
│       │   │   │   ├── CalendarBlockFocusRecord.swift
│       │   │   │   ├── CalendarDebriefRecordModel.swift
│       │   │   │   ├── ExerciseSessionRecord.swift
│       │   │   │   ├── FinanceCategoryRecord.swift
│       │   │   │   ├── FinanceTransactionRecord.swift
│       │   │   │   ├── FitnessExerciseRecord.swift
│       │   │   │   ├── FitnessRouteRecord.swift
│       │   │   │   ├── HomeLayoutRecord.swift
│       │   │   │   ├── MealLogRecord.swift
│       │   │   │   ├── PVTSessionRecord.swift
│       │   │   │   ├── PersonMemoryRecord.swift
│       │   │   │   ├── PersonTagRecord.swift
│       │   │   │   ├── PracticePieceRecord.swift
│       │   │   │   ├── PracticeSessionRecord.swift
│       │   │   │   ├── PromiseRecord.swift
│       │   │   │   ├── RoutineCompletionLogRecord.swift
│       │   │   │   ├── RoutineRecord.swift
│       │   │   │   ├── ScheduledBlockRecord.swift
│       │   │   │   ├── ShoppingItemRecord.swift
│       │   │   │   ├── SleepCheckInRecord.swift
│       │   │   │   ├── SyncConflictRecord.swift
│       │   │   │   ├── SyncStateRecord.swift
│       │   │   │   ├── SyncTombstoneRecord.swift
│       │   │   │   ├── TaskRecord.swift
│       │   │   │   ├── ViceGoalRecord.swift
│       │   │   │   ├── ViceLogRecord.swift
│       │   │   │   ├── ViceRecord.swift
│       │   │   │   ├── ViceSessionRecord.swift
│       │   │   │   ├── WorkoutLogRecord.swift
│       │   │   │   └── WorkoutTemplateRecord.swift
│       │   │   └── SwiftDataRepositories
│       │   │       ├── SwiftDataCalendarBlockFocusRepository.swift
│       │   │       ├── SwiftDataDebriefRepository.swift
│       │   │       ├── SwiftDataFinanceRepository.swift
│       │   │       ├── SwiftDataFitnessRepository.swift
│       │   │       ├── SwiftDataHealthRepository.swift
│       │   │       ├── SwiftDataHomeLayoutRepository.swift
│       │   │       ├── SwiftDataMusicPracticeRepository.swift
│       │   │       ├── SwiftDataPeopleMemoryRepository.swift
│       │   │       ├── SwiftDataPromiseRepository.swift
│       │   │       ├── SwiftDataRoutineRepository.swift
│       │   │       ├── SwiftDataScheduledBlockRepository.swift
│       │   │       ├── SwiftDataSettingsRepository.swift
│       │   │       ├── SwiftDataShoppingRepository.swift
│       │   │       ├── SwiftDataTaskRepository.swift
│       │   │       └── SwiftDataViceRepository.swift
│       │   ├── Planner
│       │   │   ├── Models
│       │   │   │   └── PlanningContracts.swift
│       │   │   └── PlannerEngine.swift
│       │   ├── Sync
│       │   │   ├── SyncBackupPolicy.swift
│       │   │   ├── SyncChangeBatch.swift
│       │   │   ├── SyncCoders.swift
│       │   │   ├── SyncConflict.swift
│       │   │   ├── SyncDeviceIdentity.swift
│       │   │   ├── SyncEngine.swift
│       │   │   ├── SyncFolderAccess.swift
│       │   │   ├── SyncManifest.swift
│       │   │   ├── SyncService.swift
│       │   │   ├── SyncSnapshot.swift
│       │   │   └── SyncStatus.swift
│       │   ├── Views
│       │   │   ├── EstimatedDurationControl.swift
│       │   │   ├── PlannerCalendarSetupCard.swift
│       │   │   ├── PlannerView.swift
│       │   │   ├── TaskFormView.swift
│       │   │   ├── TaskListView.swift
│       │   │   └── TaskQuickAddView.swift
│       │   ├── task-manager-ios.entitlements
│       │   ├── task-manager.entitlements
│       │   └── task_managerApp.swift
│       ├── task-manager.xcodeproj
│       │   ├── project.pbxproj
│       │   ├── project.xcworkspace
│       │   │   ├── contents.xcworkspacedata
│       │   │   ├── xcshareddata
│       │   │   │   └── swiftpm
│       │   │   │       └── configuration
│       │   │   └── xcuserdata
│       │   │       └── campshelor.xcuserdatad
│       │   │           └── UserInterfaceState.xcuserstate
│       │   ├── xcshareddata
│       │   │   └── xcschemes
│       │   │       └── task-manager.xcscheme
│       │   └── xcuserdata
│       │       └── campshelor.xcuserdatad
│       │           └── xcschemes
│       │               └── xcschememanagement.plist
│       └── task-managerTests
│           ├── Calendar
│           │   ├── CalendarProjectMatcherTests.swift
│           │   └── EventKitCalendarServicesTests.swift
│           ├── Debrief
│           │   ├── DebriefComposerViewModelTests.swift
│           │   ├── DebriefModelTests.swift
│           │   ├── DebriefQueueFlowTests.swift
│           │   ├── DebriefQueueViewModelTests.swift
│           │   └── DebriefQueueServiceTests.swift
│           ├── Features
│           │   └── TaskListViewModelTests.swift
│           ├── Finance
│           │   ├── FinanceModelTests.swift
│           │   ├── FinanceSummaryServiceTests.swift
│           │   └── SwiftDataFinanceRepositoryTests.swift
│           ├── Fitness
│           │   ├── FitnessModelTests.swift
│           │   ├── FitnessViewModelTests.swift
│           │   └── SwiftDataFitnessRepositoryTests.swift
│           ├── Health
│           │   ├── HealthModelTests.swift
│           │   ├── HealthViewModelTests.swift
│           │   └── SwiftDataHealthRepositoryTests.swift
│           ├── Home
│           │   ├── HomeExecutionViewModelTests.swift
│           │   └── HomeLayoutViewModelTests.swift
│           ├── Models
│           │   ├── CaptureCapabilityTests.swift
│           │   ├── HomeWidgetModelTests.swift
│           │   ├── MyTaskCollectionTests.swift
│           │   ├── MyTaskFormDataTests.swift
│           │   ├── MyTaskTests.swift
│           │   └── TaskListPresentationTests.swift
│           ├── MusicPractice
│           │   ├── MusicPracticeModelTests.swift
│           │   ├── MusicPracticeViewModelTests.swift
│           │   └── SwiftDataMusicPracticeRepositoryTests.swift
│           ├── PeopleMemory
│           │   ├── PeopleMemoryModelTests.swift
│           │   ├── PeopleMemoryViewModelTests.swift
│           │   └── SwiftDataPeopleMemoryRepositoryTests.swift
│           ├── Persistence
│           │   ├── SwiftDataCalendarBlockFocusRepositoryTests.swift
│           │   ├── SwiftDataDebriefRepositoryTests.swift
│           │   ├── SwiftDataHomeLayoutRepositoryTests.swift
│           │   ├── SwiftDataScheduledBlockRepositoryTests.swift
│           │   ├── SwiftDataSettingsRepositoryTests.swift
│           │   └── SwiftDataTaskRepositoryTests.swift
│           ├── Planner
│           │   ├── PlannerEngineTests.swift
│           │   ├── PlannerTimelineGridTests.swift
│           │   └── PlannerViewModelTests.swift
│           ├── Promises
│           │   ├── PromiseModelTests.swift
│           │   └── SwiftDataPromiseRepositoryTests.swift
│           ├── Routines
│           │   ├── RoutineModelTests.swift
│           │   └── SwiftDataRoutineRepositoryTests.swift
│           ├── Settings
│           │   └── SettingsViewModelTests.swift
│           ├── Shopping
│           │   ├── ShoppingListViewModelTests.swift
│           │   ├── ShoppingModelTests.swift
│           │   └── SwiftDataShoppingRepositoryTests.swift
│           └── Vices
│               ├── SwiftDataViceRepositoryTests.swift
│               ├── ViceModelTests.swift
│               └── VicesViewModelTests.swift
├── docs
│   ├── domains
│   │   ├── calendar_block_focus.md
│   │   ├── debriefs.md
│   │   ├── future-modules
│   │   │   ├── budgeting.md
│   │   │   ├── fitness.md
│   │   │   ├── future_widgets.md
│   │   │   ├── health.md
│   │   │   ├── journaling_reflection.md
│   │   │   ├── life_logs.md
│   │   │   ├── music_practice.md
│   │   │   ├── nutrition.md
│   │   │   ├── people_memory.md
│   │   │   ├── sleep_pvt.md
│   │   │   ├── task_evolution.md
│   │   │   └── vices.md
│   │   ├── promises.md
│   │   ├── routines.md
│   │   ├── shopping.md
│   │   └── today_dashboard.md
│   ├── iphone_product_scope.md
│   ├── life_assistant_vision.md
│   ├── manual_test_session_template.md
│   ├── product_direction.md
│   ├── test_sessions
│   │   ├── .gitkeep
│   │   ├── 2026-03-19_14-33-12_manual_test.md
│   │   ├── 2026-03-19_14-40-34_manual_test.md
│   │   ├── 2026-03-19_14-45-02_manual_test.md
│   │   ├── 2026-03-19_14-45-23_manual_test.md
│   │   ├── 2026-03-19_15-11-14_manual_test.md
│   │   ├── 2026-03-22_18-07-23_manual_test.md
│   │   ├── 2026-03-22_18-23-52_manual_test.md
│   │   ├── 2026-03-22_18-39-34_manual_test.md
│   │   └── 2026-04-10_iphone_simulator_launch_smoke.md
│   └── testing_workflow.md
└── scripts
    ├── check_swift_typecheck_complexity.sh
    ├── diagnose_ios_dev_env.sh
    └── manual_test_session.sh
```

## README Maintenance Rule

If you change repository structure, entry points, architecture contracts, verification commands, or the set of meaningful feature areas, update this README in the same change. If you add, move, or remove files/folders that materially affect orientation, refresh the repo tree section too.
