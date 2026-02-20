#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/repeat_n_times.sh"

if [[ ! -f "$TARGET_SCRIPT" ]]; then
  echo "Target script not found: $TARGET_SCRIPT" >&2
  exit 1
fi

TMP_ROOT="${TMPDIR:-/tmp}/repeat_n_times_smoke_${RANDOM}_$$"
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT"

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL: %s\n' "$1"
}

run_capture() {
  local out_var="$1"
  local status_var="$2"
  shift 2

  local out
  local status
  set +e
  out="$("$@" 2>&1)"
  status=$?
  set -e

  printf -v "$out_var" '%s' "$out"
  printf -v "$status_var" '%s' "$status"
}

assert_status() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected status $expected, got $actual)"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

assert_file_contains() {
  local file_path="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file_path"; then
    pass "$label"
  else
    fail "$label (missing in $file_path: $needle)"
  fi
}

printf 'Running repeat_n_times smoke tests with temp root: %s\n' "$TMP_ROOT"

# Case 1: New dry run generates run folder and writes iteration entries.
REPORTS_DIR_1="${TMP_ROOT}/reports_case_1"
mkdir -p "$REPORTS_DIR_1"
run_capture case1_out case1_status \
  bash "$TARGET_SCRIPT" \
  --task "smoke test task" \
  --iterations 2 \
  --output-root "$REPORTS_DIR_1" \
  --dry-run

assert_status "$case1_status" "0" "case1 exits successfully"
assert_contains "$case1_out" "Run folder:" "case1 prints run folder"
assert_contains "$case1_out" "Dry run enabled: codex calls will be skipped." "case1 reports dry-run mode"

case1_run_dir="$(printf '%s\n' "$case1_out" | awk -F': ' '/^Run folder:/ {print $2; exit}')"
if [[ -n "${case1_run_dir:-}" && -d "$case1_run_dir" ]]; then
  pass "case1 run folder exists"
else
  fail "case1 run folder was not created"
fi

case1_progress="${case1_run_dir}/progress.txt"
if [[ -f "$case1_progress" ]]; then
  pass "case1 progress file exists"
  assert_file_contains "$case1_progress" "- [1] Dry run at " "case1 iteration 1 logged"
  assert_file_contains "$case1_progress" "- [2] Dry run at " "case1 iteration 2 logged"
else
  fail "case1 progress file missing"
fi

# Case 2: Resume completed run should no-op.
run_capture case2_out case2_status \
  bash "$TARGET_SCRIPT" \
  --resume "$case1_run_dir" \
  --dry-run

assert_status "$case2_status" "0" "case2 exits successfully"
assert_contains "$case2_out" "Resuming from iteration: 3" "case2 computes next iteration from progress"
assert_contains "$case2_out" "No remaining iterations to run." "case2 no-op when all iterations complete"

# Case 3: Resume forbids task arguments.
run_capture case3_out case3_status \
  bash "$TARGET_SCRIPT" \
  --resume "$case1_run_dir" \
  --task "unexpected" \
  --dry-run

if [[ "$case3_status" != "0" ]]; then
  pass "case3 fails as expected"
else
  fail "case3 should fail when --resume and --task are both provided"
fi
assert_contains "$case3_out" "When using --resume, do not pass --task" "case3 prints resume/task validation error"

# Case 4: Resume forbids output-shaping options that are ignored in resume mode.
run_capture case4_out case4_status \
  bash "$TARGET_SCRIPT" \
  --resume "$case1_run_dir" \
  --output-root "$TMP_ROOT" \
  --dry-run

if [[ "$case4_status" != "0" ]]; then
  pass "case4 fails as expected"
else
  fail "case4 should fail when --resume and --output-root are both provided"
fi
assert_contains "$case4_out" "--output-root and --max-tree-files cannot be used with --resume." "case4 prints resume/output-root validation error"

# Case 5: Resume forbids max-tree-files option.
run_capture case5_out case5_status \
  bash "$TARGET_SCRIPT" \
  --resume "$case1_run_dir" \
  --max-tree-files 10 \
  --dry-run

if [[ "$case5_status" != "0" ]]; then
  pass "case5 fails as expected"
else
  fail "case5 should fail when --resume and --max-tree-files are both provided"
fi
assert_contains "$case5_out" "--output-root and --max-tree-files cannot be used with --resume." "case5 prints resume/max-tree-files validation error"

# Case 6: Missing value is rejected.
run_capture case6_out case6_status \
  bash "$TARGET_SCRIPT" \
  --task \
  --dry-run

if [[ "$case6_status" != "0" ]]; then
  pass "case6 fails as expected"
else
  fail "case6 should fail for missing --task value"
fi
assert_contains "$case6_out" "Missing value for --task." "case6 prints missing value error"

# Case 7: Resume from partial progress starts at next missing iteration.
PARTIAL_RUN_DIR="${TMP_ROOT}/manual_partial_resume"
mkdir -p "$PARTIAL_RUN_DIR"
cat > "${PARTIAL_RUN_DIR}/report.txt" <<'EOF'
# Report

## Primary Task

manual partial resume
EOF

cat > "${PARTIAL_RUN_DIR}/system_prompt.txt" <<'EOF'
placeholder system prompt
EOF

cat > "${PARTIAL_RUN_DIR}/progress.txt" <<'EOF'
# Progress

- Session started: 2026-02-20T00:00:00-05:00
- Target iterations: 3
- Report file: manual/report.txt
- Task summary: manual partial resume

## Iteration Log
- [0] Session initialized.
- [1] Seed iteration.
EOF

run_capture case7_out case7_status \
  bash "$TARGET_SCRIPT" \
  --resume "$PARTIAL_RUN_DIR" \
  --dry-run

assert_status "$case7_status" "0" "case7 exits successfully"
assert_contains "$case7_out" "Resuming from iteration: 2" "case7 resumes from next expected iteration"
assert_file_contains "${PARTIAL_RUN_DIR}/progress.txt" "- [2] Dry run at " "case7 logs resumed iteration 2"
assert_file_contains "${PARTIAL_RUN_DIR}/progress.txt" "- [3] Dry run at " "case7 logs resumed iteration 3"

# Case 8: Resume guards against inconsistent iteration ceiling.
INCONSISTENT_RUN_DIR="${TMP_ROOT}/manual_inconsistent_resume"
mkdir -p "$INCONSISTENT_RUN_DIR"
cat > "${INCONSISTENT_RUN_DIR}/report.txt" <<'EOF'
# Report

## Primary Task

manual inconsistent resume
EOF

cat > "${INCONSISTENT_RUN_DIR}/system_prompt.txt" <<'EOF'
placeholder system prompt
EOF

cat > "${INCONSISTENT_RUN_DIR}/progress.txt" <<'EOF'
# Progress

- Session started: 2026-02-20T00:00:00-05:00
- Target iterations: 5
- Report file: manual/report.txt
- Task summary: manual inconsistent resume

## Iteration Log
- [0] Session initialized.
- [4] Existing iteration.
EOF

run_capture case8_out case8_status \
  bash "$TARGET_SCRIPT" \
  --resume "$INCONSISTENT_RUN_DIR" \
  --iterations 3 \
  --dry-run

if [[ "$case8_status" != "0" ]]; then
  pass "case8 fails as expected"
else
  fail "case8 should fail when last logged iteration exceeds --iterations"
fi
assert_contains "$case8_out" "Last logged iteration (4) exceeds requested --iterations (3)." "case8 prints iteration ceiling validation error"

# Case 9: Resume with explicit --iterations updates target metadata for future resumes.
OVERRIDE_RUN_DIR="${TMP_ROOT}/manual_override_resume"
mkdir -p "$OVERRIDE_RUN_DIR"
cat > "${OVERRIDE_RUN_DIR}/report.txt" <<'EOF'
# Report

## Primary Task

manual override resume
EOF

cat > "${OVERRIDE_RUN_DIR}/system_prompt.txt" <<'EOF'
placeholder system prompt
EOF

cat > "${OVERRIDE_RUN_DIR}/progress.txt" <<'EOF'
# Progress

- Session started: 2026-02-20T00:00:00-05:00
- Target iterations: 2
- Report file: manual/report.txt
- Task summary: manual override resume

## Iteration Log
- [0] Session initialized.
- [1] Existing iteration.
EOF

run_capture case7a_out case7a_status \
  bash "$TARGET_SCRIPT" \
  --resume "$OVERRIDE_RUN_DIR" \
  --iterations 4 \
  --dry-run

assert_status "$case7a_status" "0" "case9a exits successfully"
assert_contains "$case7a_out" "Resuming from iteration: 2" "case9a resumes from expected next iteration"
assert_file_contains "${OVERRIDE_RUN_DIR}/progress.txt" "- Target iterations: 4" "case9a updates target iterations metadata"
assert_file_contains "${OVERRIDE_RUN_DIR}/progress.txt" "- [2] Dry run at " "case9a logs resumed iteration 2"
assert_file_contains "${OVERRIDE_RUN_DIR}/progress.txt" "- [3] Dry run at " "case9a logs resumed iteration 3"
assert_file_contains "${OVERRIDE_RUN_DIR}/progress.txt" "- [4] Dry run at " "case9a logs resumed iteration 4"

run_capture case7b_out case7b_status \
  bash "$TARGET_SCRIPT" \
  --resume "$OVERRIDE_RUN_DIR" \
  --dry-run

assert_status "$case7b_status" "0" "case9b exits successfully"
assert_contains "$case7b_out" "Resuming from iteration: 5" "case9b uses updated target metadata"
assert_contains "$case7b_out" "No remaining iterations to run." "case9b no-ops after completion"

printf '\nResult: %d passed, %d failed\n' "$pass_count" "$fail_count"

if (( fail_count > 0 )); then
  exit 1
fi
