# Health: Nutrition Subdomain

## Purpose

Nutrition tracking should help the user notice useful food, meal, energy, sleep, and planning patterns without becoming a full calorie-counting app.

This is a subdomain of Health. The first version should focus on lightweight meal logging and practical connections to sleep quality, workouts, shopping, routines, budget, and energy.

## Product Shape

The core flow should be quick meal capture:

- what meal happened
- roughly when it happened
- what kind of meal it was
- how it felt or affected energy
- optional notes

Avoid requiring a strict calorie-counting workflow or a heavyweight food database in the first pass. The current app already stores per-serving nutrient snapshots and a small searchable food catalog, so future work should stay focused on useful capture and review rather than exhaustive logging.

## Current Implementation

Health's Nutrition surface already has first-pass Swift support:

- multi-entry meal logs
- per-serving nutrient snapshots
- starter searchable food catalog items
- persisted custom foods
- meal-derived debrief reminder timing
- lightweight quick-entry and history/delete flows

The doc remains a product sketch for future nutrition UX, but it should be read alongside `docs/domains/future-modules/health.md` and `README.md` so the current code shape is not understated.

## Possible Log Fields

A `MealLog` might include:

- timestamp
- meal type: breakfast, lunch, dinner, snack, drink, other
- title or short description
- tags, such as homemade, takeout, heavy, light, protein, late-night, skipped
- hunger before
- energy after
- mood after
- cost estimate, if useful
- notes

## Interaction With Shopping

Nutrition should be able to inform shopping without owning shopping behavior directly.

Examples:

- a recurring meal can suggest shopping items
- a meal prep plan can create shopping list items
- repeated missing staples can become shopping reminders
- takeout-heavy weeks can feed budget review

## Interaction With Health / Fitness / Routines / Home

Home can show simple nutrition prompts only when useful:

- "Log lunch"
- "Plan dinner"
- "Meal prep routine due"
- "You skipped breakfast yesterday" if this pattern is actually useful

Routines can include meal-related checklist items. Health can compare meal timing or rough meal quality with PVT results, sleep quality, workouts, and energy, but this should stay lightweight.

## Implementation Sketch

```text
Models/
  NutritionModels.swift
  MealLogModels.swift

Persistence/
  SwiftDataModels/
    MealLogRecord.swift
  Repositories/
    NutritionRepository.swift
  SwiftDataRepositories/
    SwiftDataNutritionRepository.swift

Features/Health/Nutrition/
  Quick meal log
  Meal history
  Simple pattern review
```

Start with structured meal logs. Add meal templates or meal planning only after logging is useful.

## Design Principles

- Keep capture lightweight.
- Avoid obsessive precision unless the user explicitly needs it later.
- Prefer pattern awareness over judgment.
- Connect to shopping and budget when it reduces real-life friction.

## Open Questions

- Should skipped meals be first-class logs or inferred from missing expected meals?
- Should meal photos be supported later?
- Should takeout spending belong here, Budgeting, or both?
- Should the app support planned meals, or only logged meals at first?

## Status

Active work in progress inside Health. The app now has a first-pass lightweight meal log with SwiftData persistence, quick entry, history/delete UI, neutral trend summaries, and the nutrient snapshot / food-catalog plumbing described above.

This is still intentionally not a calorie, macro, diet, or meal-planning system. Photos, templates, shopping integration, and richer review flows remain future work.
