#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
note_path="$repo_root/docs/test_sessions/${timestamp}_manual_test.md"
project_path="apple_app/task-manager/task-manager.xcodeproj"
scheme="task-manager"
derived_data_path="${TASK_MANAGER_DERIVED_DATA_PATH:-/tmp/task-manager-manual-test-derived-data}"
simulator_test_exit=0
iphone_build_exit=0
typecheck_guard_exit=0
simulator_test_status="skipped"
typecheck_guard_status="not run"
run_simulator_tests="${RUN_IOS_SIMULATOR_TESTS:-0}"

mkdir -p "$repo_root/docs/test_sessions"

echo "Task Manager Swift QA Session"
echo "============================="
echo "Repo: $repo_root"
echo "Note: $note_path"
echo "DerivedData: $derived_data_path"
echo

if [[ "$run_simulator_tests" == "1" ]]; then
  echo "Checking iOS simulator availability..."
  if xcrun simctl list devices available >/dev/null 2>&1; then
    echo "Running iOS simulator Swift tests..."
    if (cd "$repo_root" && xcodebuild -project "$project_path" -scheme "$scheme" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath "$derived_data_path" test); then
      simulator_test_exit=0
      simulator_test_status="passed"
    else
      simulator_test_exit=$?
      simulator_test_status="failed"
    fi
  else
    simulator_test_exit=1
    simulator_test_status="skipped (CoreSimulator unavailable)"
    echo "Skipping simulator tests: CoreSimulator is unavailable on this machine."
  fi
else
  simulator_test_status="skipped (set RUN_IOS_SIMULATOR_TESTS=1 to enable)"
  echo "Skipping iOS simulator Swift tests by default."
fi

echo
echo "Running iPhone simulator build..."
if (cd "$repo_root" && xcodebuild -project "$project_path" -scheme "$scheme" -sdk iphonesimulator -derivedDataPath "$derived_data_path" build); then
  iphone_build_exit=0
else
  iphone_build_exit=$?
fi

echo
echo "Running Swift compiler complexity guard..."
if (cd "$repo_root" && bash scripts/check_swift_typecheck_complexity.sh); then
  typecheck_guard_exit=0
  typecheck_guard_status="passed"
else
  typecheck_guard_exit=$?
  typecheck_guard_status="failed"
fi

cat > "$note_path" <<NOTE
# Manual Test Session - $timestamp

## Automated Checks

- iOS simulator Swift tests: exit code $simulator_test_exit
- iOS simulator Swift tests status: $simulator_test_status
- iPhone simulator build: exit code $iphone_build_exit
- Swift compiler complexity guard: exit code $typecheck_guard_exit
- Swift compiler complexity guard status: $typecheck_guard_status

## Current Product Path

- [ ] Opened \`apple_app/task-manager/task-manager.xcodeproj\`
- [ ] Ran the \`task-manager\` scheme
- [ ] Confirmed the app opens to Home

## Home / Promises / Widgets

- [ ] Confirmed Home widgets render and launch the expected destination flows
- [ ] Confirmed pending Debrief / Vices / Fitness / People summaries refresh after data changes
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
- [ ] Completed and reopened a task
- [ ] Checked search, sort, and grouping
- [ ] Confirmed task-like captures still route through Capture Review when relevant

## Capture Review / Inbox

- [ ] Loaded or created a raw capture
- [ ] Confirmed candidate groups appear for Tasks, Shopping, and Music Practice when applicable
- [ ] Converted one capture into a task
- [ ] Converted one capture into a shopping item
- [ ] Converted one capture into a practice piece

## Calendar / Planner

- [ ] Checked calendar permission state
- [ ] Loaded readable calendars
- [ ] Selected a write calendar
- [ ] Generated planner suggestions
- [ ] Accepted a suggestion and confirmed calendar writeback
- [ ] Canceled/deleted an accepted block
- [ ] Confirmed promises and routines do not write directly to Apple Calendar

## Health / Fitness / Practice / Shopping / People

- [ ] Opened Health from Home and saved a quick check-in or log
- [ ] Opened Shopping from Home and added an item
- [ ] Opened Fitness from Home and confirmed quick-log draft seeding plus workout-day history refresh
- [ ] Opened Music Practice from Home and checked recent summaries
- [ ] Opened People from Home and checked search or study review

## Debriefs / Block Focus / Vices / Finance

- [ ] Completed a Debrief from a quick outcome
- [ ] Added an optional quick note and reopened detailed prompts when relevant
- [ ] Confirmed Block Focus-backed task outcomes can be reviewed without calendar writes
- [ ] Logged a vice hit and undid it within the undo window
- [ ] Confirmed repeated vice hits aggregate into one active session and queue at most one Vice Session Debrief
- [ ] Opened Finance from Home, added one income and one expense, and confirmed totals refresh

## Notes

-
NOTE

echo
echo "Manual test note created:"
echo "$note_path"
echo
echo "Recommended next steps:"
echo "  1. Review failing automated checks before manual QA."
echo "  2. Open the Xcode project and work through the generated checklist."
echo "  3. Add findings under the Notes section in the generated session note."
