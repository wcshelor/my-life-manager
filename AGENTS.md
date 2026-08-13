# AGENTS.md

- Read `AGENTS.md` first, then `README.md`, then `docs/README.md`.
- Read `docs/testing_workflow.md` before choosing verification steps or changing the documented test battery.
- Treat `README.md` as the repo briefing for future agents.
- Treat `docs/README.md` as the documentation map for faster repo assessment.
- Keep `README.md` detailed and current when repo structure, architecture, feature surface, or verification guidance changes.
- Keep `docs/README.md` current when the doc set changes or a new orientation path would help future agents.
- Keep `docs/testing_workflow.md` current when the standard battery, targeted checks, recurring failure guidance, or manual QA surface changes.
- Refresh the repo tree in `README.md` whenever files or folders materially change.
- Make the smallest correct change and do not refactor unrelated code.
- Prefer existing patterns over new abstractions.
- Keep business logic outside SwiftUI views when possible.
- Keep planner logic testable and deterministic.
- SwiftData owns app data; EventKit writes stay inside Planner / ScheduledBlock flows.
- Prefer targeted deterministic checks over full-suite or simulator-first validation.
- Do not spend time repeatedly attempting simulator runs when CoreSimulator is unavailable; use build-only verification and report the limitation instead.
- Use the standard test battery from `docs/testing_workflow.md` and run the narrowest relevant subset for the area you touched.
- If you touch a large or deeply nested SwiftUI body, include `bash scripts/check_swift_typecheck_complexity.sh` in the verification plan unless an environment limitation prevents it.
- Avoid simulator testing by default to conserve tokens; only use it when the change genuinely requires runtime UI verification and the host has working Simulator runtimes.
- Remember the coding agent may be running in a sandboxed environment with restricted simulator, UI, filesystem, or OS-service access. Do not waste time repeatedly debugging or "fixing" environment limitations the agent cannot control; identify the limitation clearly, report it, and move on to the narrowest useful verification the agent can actually perform.
- If `xcodebuild` fails with CoreSimulator, `actool`, provisioning-profile, or DerivedData permission errors, use `bash scripts/diagnose_ios_dev_env.sh` when it is relevant and otherwise report the limitation instead of looping on the same failure.
- If the failure is `No available simulator runtimes for platform iphonesimulator` or `SimServiceContext supportedRuntimes=[]`, stop retrying simulator commands and stick to build-only confidence.
- Do not claim manual/UI verification unless you actually performed it.
- Stop and ask before changing architecture, adding dependencies, touching sync behavior, broadly changing persistence, or editing many unrelated files.

## Documentation Map

- `README.md`
  - repo briefing, implementation surface, architecture boundaries, verification guidance, and repo tree snapshot
- `docs/README.md`
  - documentation hub and fast reading order
- `docs/life_assistant_vision.md`
  - current product vision and active module inventory
- `docs/product_direction.md`
  - frozen product contract and source-of-truth rules
- `docs/iphone_product_scope.md`
  - historical iPhone migration scope
- `docs/testing_workflow.md`
  - baseline checks, targeted verification, manual QA, and recurring failure guidance
- `docs/manual_test_session_template.md`
  - manual QA note template and checklist
- `docs/domains/`
  - active domain notes for implemented or evolving behavior
- `docs/domains/future-modules/`
  - future-module sketches and active work-in-progress domain notes
- `apple_app/task-manager/task-manager/Features/*FeatureNotes.md`
  - feature-local notes for Home, Logs, Practice, Reflection, and Routines
- `docs/test_sessions/`
  - archived manual test notes and smoke-test writeups
