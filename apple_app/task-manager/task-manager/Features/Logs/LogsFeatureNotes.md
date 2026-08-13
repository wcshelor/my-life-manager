# Logs Feature

Scaffold only. No general logging UI, model, persistence, or view model is implemented yet.

## Purpose

Future feature area for lightweight personal records such as workouts, meals, mood notes, meditation, and generic life logs.

Use `docs/domains/future-modules/life_logs.md` for the generic log direction and `docs/domains/future-modules/health.md` for the Health-owned structured-log surfaces.

## Likely Future Objects

- generic log entry
- workout log
- meal log
- mood log
- meditation log

## Interaction With Tasks / Planner

Logs can inform planning and pattern review, but they should not directly schedule calendar events. Use dedicated models when a log type needs structured data.
