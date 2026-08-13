# Documentation Hub

This is the quickest map of the repo's documentation. If you are an agent, read this file after `AGENTS.md` and `README.md`.

The goal of this hub is fast scoping, not exhaustive explanation. Start with the smallest doc that answers the question, then only drill deeper if the task touches that area.

## Fast Reading Order

1. `AGENTS.md` for repo-specific instructions.
2. `README.md` for the main repo briefing and source-tree map.
3. `docs/README.md` (this file) for the documentation map.
4. `docs/testing_workflow.md` for the current verification battery.
5. The domain or feature note that matches the area you are touching.

If you already know the area, you can skip directly to the matching domain or feature note, but do not skip `README.md` or `docs/testing_workflow.md` when you need repo-wide orientation or verification guidance.

## Orientation Docs

- `README.md`
  - Current repo briefing, implementation surface, architecture boundaries, verification guidance, and a repo tree snapshot.
- `docs/life_assistant_vision.md`
  - High-level product vision for the active Swift app, including current module coverage and longer-range direction.
- `docs/product_direction.md`
  - Frozen product contract for tasks, planner, and daily execution support.
- `docs/iphone_product_scope.md`
  - Historical iPhone migration scope and the constraints that shaped the shared app shell.
- `docs/testing_workflow.md`
  - Default build/test/manual QA workflow, area-specific checks, environment failure guidance, and the preferred verification order for agents.
- `docs/manual_test_session_template.md`
  - Template for recording a manual QA pass and the current checklist items to verify by area.

## Domain Docs

These are the main domain references for implemented or actively evolving surfaces.

- `docs/domains/calendar_block_focus.md`
  - App-owned focus metadata for calendar work blocks and how it relates to EventKit.
- `docs/domains/debriefs.md`
  - Reflection records, queue-first debrief flow, source types, and the relationship to Block Focus and vice sessions.
- `docs/domains/promises.md`
  - Promise/check-in behavior and the interaction with Home, Tasks, and Planner.
- `docs/domains/routines.md`
  - Routine objects, completion logs, and the current relationship to tasks and scheduled work.
- `docs/domains/shopping.md`
  - Shopping capture, organization, and list-versus-wish-list behavior.
- `docs/domains/today_dashboard.md`
  - The Home / Today dashboard framing and the current execution-board surface.

### Future-Module Docs

These files are the best quick references for active work-in-progress and planned module areas.

- `docs/domains/future-modules/budgeting.md`
  - Lightweight spending awareness and purchase-decision support.
- `docs/domains/future-modules/fitness.md`
  - Standalone exercise logging, workout structure, and the current Fitness module direction.
- `docs/domains/future-modules/future_widgets.md`
  - Home widget design notes and the current widget-board direction.
- `docs/domains/future-modules/health.md`
  - Health as a personal pattern-awareness surface, including sleep, PVT, nutrition, and workout context.
- `docs/domains/future-modules/journaling_reflection.md`
  - Journaling and reflection direction, including prompt-based writing and follow-up capture.
- `docs/domains/future-modules/life_logs.md`
  - Generic record-keeping direction for lightweight personal logs.
- `docs/domains/future-modules/music_practice.md`
  - Music practice logging, repertoire tracking, and practice-routine direction.
- `docs/domains/future-modules/nutrition.md`
  - Nutrition as a Health subdomain and the lightweight meal-logging shape.
- `docs/domains/future-modules/people_memory.md`
  - Memory-aid workflows for names, contexts, tags, and study review.
- `docs/domains/future-modules/sleep_pvt.md`
  - Sleep and vigilance tracking, including the morning PVT direction.
- `docs/domains/future-modules/task_evolution.md`
  - How the task system could grow without losing fast capture.
- `docs/domains/future-modules/vices.md`
  - Vice logging, goals, friction, and pattern review.

## Feature Notes

These notes live beside the Swift feature code and are useful when you need a short explanation of why a folder exists.

- `apple_app/task-manager/task-manager/Features/Home/HomeFeatureNotes.md`
  - Home dashboard responsibilities, current objects, and planning boundaries.
- `apple_app/task-manager/task-manager/Features/InboxReview/InboxReviewFeatureNotes.md`
  - Standalone sticky-note review flow, intake registry ownership, and the Home handoff boundary.
- `apple_app/task-manager/task-manager/Features/Logs/LogsFeatureNotes.md`
  - Placeholder logging surface and why it remains a scaffold.
- `apple_app/task-manager/task-manager/Features/Practice/PracticeFeatureNotes.md`
  - Historical Practice scaffold that now maps to the Music Practice foundation.
- `apple_app/task-manager/task-manager/Features/Reflection/ReflectionFeatureNotes.md`
  - Historical reflection scaffold and the direction it points toward.
- `apple_app/task-manager/task-manager/Features/Routines/RoutinesFeatureNotes.md`
  - Routines feature context, current objects, and task/calendar boundaries.

## Manual QA Artifacts

- `docs/test_sessions/`
  - Timestamped manual QA notes and smoke-test writeups.

## What To Update When Behavior Changes

When you change product behavior, keep the relevant documentation in sync:

- update `README.md` for repo structure, implementation surface, or verification changes
- update `docs/testing_workflow.md` for battery changes, recurring failures, or manual QA expectations
- update the matching domain doc for the behavior you changed
- update the matching feature note when the implementation folder needs a short local explainer

When the repo gains a new major surface, new folder, or new recurring workflow, update this hub first so future agents still have a fast entry point.
