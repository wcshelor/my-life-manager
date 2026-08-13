# Fitness Module

## Purpose

Fitness is now a standalone Home-reachable module for structured exercise logging.

It is separate from the older generic Health workout log. In v1 there is no migration, no shared writes, and no Apple Health integration.

## V1 Product Shape

The gym workflow is:

- open Fitness from Home
- pick a workout or an exercise
- review the last one to three sessions
- log the current session with the date auto-stamped
- reuse a saved route when a distance field is present

The main screen has two surfaces:

- `Workouts`: user-facing containers built from saved exercise order in a 3-column board
- `Exercise Library`: the full exercise list with Recent, A-Z, and Tag sorting
- the workout editor has its own `Add Existing` sort control that is independent from the library sort

## Durable Objects

- `FitnessExercise`
- `WorkoutTemplate`
- `ExerciseSession`
- `StrengthSet`
- `FitnessRoute`

User-facing label: `Workout`

Internal durable type: `WorkoutTemplate`

## Exercise Rules

- Every exercise requires exactly one tag: `legs`, `push`, `pull`, or `cardio`.
- Every exercise requires one tracking style.
- `strengthSets` exercises store ordered sets with whole or half-step reps and optional weight.
- `metricSummary` exercises store a non-empty subset of:
  - `durationMinutes`
  - `difficultyLevel`
  - `averageRPM`
  - `distance`
- preset cardio styles exist for `stationaryBike`, `normalBike`, and `walk`
- preset cardio exercises keep `metricSummary` as the custom escape hatch rather than replacing it

## Unit Rules

- Units are stored per exercise, not app-wide.
- Strength exercises require `lb` or `kg`.
- Metric-summary exercises require `miles` or `kilometers` only when distance is enabled.
- cardio presets that include distance also require a stored distance unit
- saved routes are unit-scoped; mile routes only appear for mile-based fields and kilometer routes only appear for kilometer-based fields

## Workout Rules

- A workout must have a non-empty name and at least one exercise.
- It stores an ordered, unique list of exercise IDs.
- Duplicate exercise IDs are normalized away while preserving the first occurrence order.
- The same exercise can appear in multiple workouts.

## Session Rules

- Every session stores `exerciseID`, `performedAt`, `createdAt`, and `updatedAt`.
- New sessions auto-stamp `performedAt`.
- Editing preserves the original `performedAt`.
- Logged-today state is derived from any same-day session for that exercise.
- sessions can also store optional notes
- saved-session history should route back into the same editor used for creation
- V1 has no workout-completion object, plan object, charts, archive flow, or Health sync.

## Route Rules

- A route stores `name`, `distance`, and `distanceUnit`.
- Route names are required and distances must be positive.
- Route selection fills the current distance field without converting units.
- Creating a route from a session form should prefill the active distance unit from that form.

## Persistence Shape

Fitness owns its own repository and SwiftData records:

```text
Models/
  FitnessModels.swift

Persistence/
  Repositories/
    FitnessRepository.swift
  SwiftDataModels/
    FitnessExerciseRecord.swift
    FitnessRouteRecord.swift
    WorkoutTemplateRecord.swift
    ExerciseSessionRecord.swift
  SwiftDataRepositories/
    SwiftDataFitnessRepository.swift

Features/Fitness/
  FitnessViewModel.swift
  FitnessView.swift
```

The repository is intentionally simple. View models do recent-session grouping and filtering in memory because the expected data volume is small.

## Relationship To Health

- Health still owns the older lightweight generic workout log.
- Fitness now owns structured exercise progression, workouts, per-exercise history, and saved route reuse.
- A later migration can consolidate those systems, but that is explicitly deferred.

## Status

Implemented work in progress. Fitness has its own Home module entry, SwiftData persistence, workout editing, exercise detail/history, route reuse, draft quick-log seeding from the most recent session, and shared create/edit session logging, but still needs broader manual QA and product polish.
