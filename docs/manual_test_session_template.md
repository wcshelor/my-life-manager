# Manual Test Session - <timestamp>

## Automated Checks

- iOS simulator Swift tests:
- iPhone simulator build:
- iPhone build-for-testing:

## Current Product Path

- [ ] Opened `apple_app/task-manager/task-manager.xcodeproj`
- [ ] Ran the `task-manager` scheme
- [ ] Confirmed the app opens to Home

## Home / Promises

- [ ] Created a new promise
- [ ] Confirmed the promise appears on Home
- [ ] Confirmed the active-promise banner appears on Tasks and Planner
- [ ] Checked in as kept
- [ ] Created another promise and checked in as missed
- [ ] Added a short recovery reflection
- [ ] Created a reset promise from the missed check-in
- [ ] Confirmed kept/missed counts update

## Routines

- [ ] Created a daily routine with multiple items
- [ ] Created a selected-weekday routine
- [ ] Confirmed today's active routines appear on Home
- [ ] Completed and uncompleted routine items
- [ ] Relaunched the app and confirmed completion state persists for today

## Tasks

- [ ] Created a task
- [ ] Edited a task
- [ ] Deleted a task
- [ ] Checked search behavior
- [ ] Checked sort behavior
- [ ] Checked grouping behavior
- [ ] Completed and reopened a task

## Capture Review / Inbox

- [ ] Created or loaded a raw capture
- [ ] Confirmed candidate groups appear for Tasks, Shopping, and Music Practice when applicable
- [ ] Converted one capture into a task
- [ ] Converted one capture into a shopping item
- [ ] Converted one capture into a practice piece
- [ ] Confirmed processed captures leave the active review queue

## Calendar / Planner

- [ ] Checked calendar permission state
- [ ] Loaded readable calendars
- [ ] Selected a write calendar
- [ ] Generated planner suggestions
- [ ] Accepted a suggestion and confirmed calendar writeback
- [ ] Edited, moved, canceled, and deleted accepted blocks where relevant
- [ ] Confirmed promises and routines do not write directly to Apple Calendar

## Banners

- [ ] Opened Banners from Settings
- [ ] Created a Banner for a Morning Routine or Night Routine
- [ ] Edited the scheduling mode, time or window, and selected weekdays
- [ ] Switched between normal and Time Sensitive urgency
- [ ] Switched between full and title-only privacy
- [ ] Changed the app-wide Notifications settings for quiet hours, daily nudge cap, and busy-calendar avoidance
- [ ] Enabled and disabled a Banner and confirmed notifications reschedule or cancel
- [ ] Deleted a Banner and confirmed the pending notifications disappear
- [ ] Confirmed notification permission onboarding appears on the first save or first enable
- [ ] Tapped the notification and confirmed it opens the intended destination

## Debriefs / Block Focus

- [ ] Completed a Debrief from a quick outcome without opening detailed prompts
- [ ] Confirmed Debriefs are presented one at a time like Capture Review
- [ ] Confirmed tapping a quick debrief button saves immediately and advances to the next candidate
- [ ] Confirmed the optional Later action moves the current candidate to the back of the in-memory queue
- [ ] Reopened the same Debrief into the detailed prompt flow
- [ ] Confirmed a detailed Debrief save advances to the next candidate
- [ ] Confirmed template inference matches the source type when applicable
- [ ] Confirmed selected-task outcomes can be reviewed without writing to Apple Calendar when a Block Focus-backed work block exists

## Vices

- [ ] Created or edited a vice
- [ ] Logged a hit from the main vice card
- [ ] Added or edited a vice limit with the end-of-day shortcut
- [ ] Created a pre-vice routine from a vice card
- [ ] Linked an existing routine and confirmed the vice receives a copied vice-linked routine
- [ ] Tapped a gated vice without an active unlock and confirmed the routine opens instead of logging the vice
- [ ] Completed the pre-vice routine and confirmed the vice becomes loggable during the unlock window
- [ ] Repeated the most recent active vice from Home and confirmed the Home summary updates without navigation
- [ ] Confirmed the repeat-last Home quick action shows a gentle inline message when no prior active vice log exists
- [ ] Undid a recent hit inside the undo window
- [ ] Confirmed repeated hits inside the session window aggregate into one active session
- [ ] Confirmed session closure creates at most one pending Vice Session Debrief candidate

## Finance

- [ ] Opened Finance from Home
- [ ] Added one income and one expense from the plus/minus buttons
- [ ] Confirmed amount entry does not save until Choose Category -> category tap
- [ ] Confirmed the date picker value is preserved into the saved transaction
- [ ] Confirmed creating a category from the category picker immediately saves and dismisses back to Finance
- [ ] Confirmed the monthly balance updates
- [ ] Confirmed category summaries and transaction history refresh
- [ ] Confirmed delete flows still update the dashboard totals

## Health

- [ ] Created a sleep check-in
- [ ] Saved a completed PVT session
- [ ] Added a meal log
- [ ] Added a generic Health workout log
- [ ] Confirmed Health history and delete flows still work

## Shopping

- [ ] Opened Shopping from Home
- [ ] Added a shopping item from the module
- [ ] Added a shopping item from the Home quick-add widget
- [ ] Marked an item bought, skipped, archived, and reopened
- [ ] Checked shopping search and history

## Fitness

- [ ] Opened Fitness from Home
- [ ] Created Push Day, Pull Day, and Leg Day workouts
- [ ] Created a strength exercise
- [ ] Created a named cardio preset exercise and a custom-metric exercise
- [ ] Added existing exercises to a workout
- [ ] Logged at least one session from an exercise detail screen
- [ ] Logged at least one session from a workout flow
- [ ] Edited a saved strength session from history
- [ ] Used the partial-rep control and weight wheel
- [ ] Selected an existing route from a distance field and created a new route from the picker
- [ ] Confirmed last-session references update immediately
- [ ] Confirmed logged-today badges appear
- [ ] Checked Recent, A-Z, and Tag sorting, plus the workout editor's `Add Existing` sort
- [ ] Confirmed the older Health workout log still behaves unchanged

## Music Practice

- [ ] Opened Music Practice from Home
- [ ] Added a practice piece
- [ ] Logged a practice session
- [ ] Confirmed recent summaries update

## People Memory

- [ ] Opened People from Home
- [ ] Added a person with tags
- [ ] Searched by name, detail, and tag
- [ ] Ran a study card and applied a rating
- [ ] Confirmed Home summary counts update

## iPhone Runtime

- [ ] App launches
- [ ] Home layout is readable
- [ ] Home widgets and quick actions behave correctly
- [ ] Promise sheets are usable
- [ ] Routine builder/checklist sheets are usable
- [ ] Task quick add works
- [ ] Planner layout is usable

## Notes

-
