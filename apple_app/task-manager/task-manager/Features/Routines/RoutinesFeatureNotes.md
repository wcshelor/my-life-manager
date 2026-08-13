# Routines Feature

First-pass Routines support is implemented through shared domain models, SwiftData persistence, Home view-model aggregation, and Home UI.

## Purpose

Feature area for morning, night, and custom routines with gentle completion tracking.

## Current Objects

- `Routine`
- `RoutineItem`
- `RoutineCompletionLog`
- `RoutineRepository`
- `HomeExecutionViewModel` routine aggregation
- `RoutinesFeatureViews` for the dedicated routine screens
- vice-linked routine support through the shared routine models

## Interaction With Tasks / Planner

Routine items may link to tasks. Scheduled routine time should flow through Planner / ScheduledBlock instead of writing directly to Apple Calendar. Routines also power the pre-vice gate flow and the routine-step module links that open module landing pages instead of the Home default action.
