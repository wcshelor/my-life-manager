#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="apple_app/task-manager/task-manager.xcodeproj"
scheme="task-manager"
derived_data_path="/tmp/task-manager-diagnostic-derived-data"
temp_write_dir="/tmp/task-manager-diagnostic-write-test"
profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

pass_count=0
fail_count=0
warn_count=0

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf '[PASS] %s\n' "$1"
  pass_count=$((pass_count + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  fail_count=$((fail_count + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  warn_count=$((warn_count + 1))
}

section "Toolchain"
if xcodebuild -version >/dev/null 2>&1; then
  pass "xcodebuild is available"
  xcodebuild -version
else
  fail "xcodebuild is not available"
fi

if xcode-select -p >/dev/null 2>&1; then
  pass "xcode-select has a developer directory"
  xcode-select -p
else
  fail "xcode-select could not locate Xcode"
fi

section "Workspace Write Access"
if mkdir -p "$temp_write_dir" && touch "$temp_write_dir/write-test" && rm -f "$temp_write_dir/write-test"; then
  pass "Can write to /tmp"
else
  fail "Cannot write to /tmp"
fi

derived_data_home="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$derived_data_home" ]]; then
  if mkdir -p "$derived_data_home" 2>/dev/null && touch "$derived_data_home/.task-manager-write-test" 2>/dev/null; then
    rm -f "$derived_data_home/.task-manager-write-test"
    pass "Can write to Xcode DerivedData"
  else
    fail "Cannot write to Xcode DerivedData at $derived_data_home"
    ls -ld "$HOME/Library/Developer/Xcode" "$derived_data_home" 2>/dev/null || true
  fi
else
  warn "Xcode DerivedData directory does not exist yet"
fi

section "Cached Build State"
active_task_manager_derived_data="$(find "$derived_data_home" -maxdepth 1 -type d -name 'task-manager-*' 2>/dev/null | head -n 1 || true)"
if [[ -n "$active_task_manager_derived_data" ]]; then
  if touch "$active_task_manager_derived_data/.task-manager-write-test" 2>/dev/null; then
    rm -f "$active_task_manager_derived_data/.task-manager-write-test"
    pass "Can write into existing task-manager DerivedData"
  else
    fail "Cannot write into existing task-manager DerivedData at $active_task_manager_derived_data"
    ls -ld "$active_task_manager_derived_data" 2>/dev/null || true
  fi
else
  warn "No existing task-manager DerivedData folder found"
fi

if [[ -d "$profile_dir" ]]; then
  bad_profiles=0
  profile_count=0
  while IFS= read -r -d '' profile_path; do
    profile_count=$((profile_count + 1))
    if ! security cms -D -i "$profile_path" >/tmp/task-manager-profile.plist 2>/tmp/task-manager-profile.err; then
      bad_profiles=$((bad_profiles + 1))
      fail "Provisioning profile could not be decoded: ${profile_path##*/}"
      sed -n '1,40p' /tmp/task-manager-profile.err 2>/dev/null || true
      continue
    fi

    if ! /usr/bin/plutil -extract UUID raw -o - /tmp/task-manager-profile.plist >/dev/null 2>&1; then
      bad_profiles=$((bad_profiles + 1))
      fail "Provisioning profile is missing UUID: ${profile_path##*/}"
    fi
  done < <(find "$profile_dir" -maxdepth 1 -name '*.mobileprovision' -print0 2>/dev/null)

  if [[ "$profile_count" -eq 0 ]]; then
    warn "No cached provisioning profiles found in Xcode UserData"
  elif [[ "$bad_profiles" -eq 0 ]]; then
    pass "Cached provisioning profiles decoded cleanly"
  fi
else
  warn "Xcode provisioning profile cache directory does not exist"
fi

section "Simulator Services"
if xcrun simctl list runtimes >/tmp/task-manager-runtimes.txt 2>/tmp/task-manager-simctl.err; then
  pass "simctl can list runtimes"
  if [[ -s /tmp/task-manager-runtimes.txt ]]; then
    sed -n '1,80p' /tmp/task-manager-runtimes.txt
  else
    warn "No runtime text returned"
  fi
else
  fail "simctl could not list runtimes"
  sed -n '1,80p' /tmp/task-manager-simctl.err 2>/dev/null || true
fi

if xcrun simctl list devices available >/tmp/task-manager-devices.txt 2>/tmp/task-manager-devices.err; then
  pass "simctl can list available devices"
  if grep -q "iPhone" /tmp/task-manager-devices.txt; then
    pass "At least one iPhone simulator is available"
  else
    warn "No iPhone device appears in the available simulator list"
  fi
else
  fail "simctl could not list available devices"
  sed -n '1,80p' /tmp/task-manager-devices.err 2>/dev/null || true
fi

if launchctl print "gui/$UID/com.apple.CoreSimulator.CoreSimulatorService" >/tmp/task-manager-core-sim.txt 2>/tmp/task-manager-core-sim.err; then
  pass "CoreSimulatorService responds to launchctl"
else
  warn "CoreSimulatorService did not respond to launchctl"
  sed -n '1,80p' /tmp/task-manager-core-sim.err 2>/dev/null || true
fi

section "Xcode Build Dry Run"
if (cd "$repo_root" && xcodebuild -project "$project_path" -scheme "$scheme" -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath "$derived_data_path" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build >/tmp/task-manager-build.txt 2>/tmp/task-manager-build.err); then
  pass "iOS build completed with a writable temporary DerivedData path"
else
  fail "iOS build failed with a writable temporary DerivedData path"
  if grep -q "Unable to write to info file\|You don’t have permission\|Operation not permitted" /tmp/task-manager-build.err 2>/dev/null; then
    warn "Build log still points to a DerivedData permission issue"
  fi
  if grep -q "ProvisioningProfileManager\|Failed to load profile" /tmp/task-manager-build.err 2>/dev/null; then
    warn "Build log still points to a provisioning profile cache issue"
  fi
  if grep -q "CoreSimulatorService\|simdiskimaged" /tmp/task-manager-build.err 2>/dev/null; then
    warn "Build log still points to CoreSimulator service issues"
  fi
  sed -n '1,120p' /tmp/task-manager-build.err 2>/dev/null || true
fi

section "Summary"
printf 'Pass: %d\nWarn: %d\nFail: %d\n' "$pass_count" "$warn_count" "$fail_count"

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
