# Home Feature

First-pass Home dashboard support is implemented as the app's first tab.

## Purpose

Home screen / secretary dashboard for surfacing what matters today across promises, routines, tasks, scheduled blocks, practice, and recovery.
Home also hosts module-launch cards plus a small set of in-place command quick actions when a widget definition supports them.
Capture review is launched from Home, but the sticky-note inbox flow now lives in the dedicated Inbox Review feature.

## Current Objects

- `HomeExecutionViewModel`
- `HomeLayoutViewModel`
- `HomeActionFeedback`
- `HomeRoutineProgress`
- `HomeWelcomeMessageCatalog`
- `PromisePresenceViewModel`
- `HomeWidgetRegistry`
- `HomeWidgetDefinition`
- `HomeWidgetConfiguration`

Future objects may include:

- richer Home summary presentation models
- dashboard card view models
- quick-capture state
- more explicit command-routing helpers for in-place widget actions

## Interaction With Tasks / Planner

Home should aggregate from existing domains and delegate actions back to Tasks, Planner, and future domain view models. It should not own task scheduling or calendar writeback logic. It also owns the Home widget board, quick actions, and the command-style module shortcuts that sit on top of other domains.
