#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="apple_app/task-manager/task-manager.xcodeproj"
scheme="task-manager"
derived_data_path="/tmp/task-manager-typecheck-derived-data"
log_path="$(mktemp /tmp/task-manager-typecheck-guard.XXXX.log)"
expression_limit_ms="${TYPECHECK_EXPRESSION_LIMIT_MS:-200}"
body_limit_ms="${TYPECHECK_BODY_LIMIT_MS:-400}"
other_swift_flags="\$(inherited) -Xfrontend -warn-long-expression-type-checking=${expression_limit_ms} -Xfrontend -warn-long-function-bodies=${body_limit_ms}"

trap 'rm -f "$log_path"' EXIT

echo "Swift compiler complexity guard"
echo "==============================="
echo "Repo: $repo_root"
echo "Expression warning threshold: ${expression_limit_ms}ms"
echo "Function/body warning threshold: ${body_limit_ms}ms"
echo

set +e
(
  cd "$repo_root" &&
  xcodebuild \
    -project "$project_path" \
    -scheme "$scheme" \
    -sdk iphonesimulator \
    build-for-testing \
    -derivedDataPath "$derived_data_path" \
    OTHER_SWIFT_FLAGS="$other_swift_flags"
) 2>&1 | tee "$log_path"
build_status=${PIPESTATUS[0]}
set -e

if [[ "$build_status" -ne 0 ]]; then
  echo
  echo "Build-for-testing failed before the complexity guard could evaluate warnings."
  exit "$build_status"
fi

typecheck_warnings="$(rg -n "warning: .* took .*ms to type-check" "$log_path" || true)"

if [[ -n "$typecheck_warnings" ]]; then
  echo
  echo "Swift compiler complexity warnings detected:"
  echo "$typecheck_warnings"
  echo
  echo "Split the reported SwiftUI body or expression into smaller subviews/helpers before merging."
  exit 1
fi

echo "No long Swift type-check warnings detected."
