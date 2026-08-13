# Practice Feature

This scaffold has evolved into the lightweight Music Practice foundation in `Features/MusicPractice`. See `docs/domains/future-modules/music_practice.md` for the fuller product shape.

## Purpose

Future feature area for piano goals, active pieces, practice skills, and practice sessions.

## Implemented Foundation

- `PracticePiece`
- `PracticeSession`
- `MusicPracticeRepository`
- `MusicPracticeViewModel`
- simple session and piece capture UI
- capture-review conversion into practice pieces

## Interaction With Tasks / Planner

Practice goals may create tasks. Practice sessions should be persisted as app-owned data. Scheduled practice time should go through Planner / ScheduledBlock.
