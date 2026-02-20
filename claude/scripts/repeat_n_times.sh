#!/usr/bin/env bash
set -euo pipefail

ITERATIONS=5
ITERATIONS_SET=false
TASK=""
TASK_FILE=""
OUTPUT_ROOT="claude/reports/repeat_n_times"
OUTPUT_ROOT_SET=false
RESUME_DIR=""
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
MAX_TREE_FILES_SET=false
DRY_RUN=false
SKILL_FILES=()
CONTEXT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  ./claude/scripts/repeat_n_times.sh --task "your task" [options]
  ./claude/scripts/repeat_n_times.sh "your task" [options]

Options:
  --task, -t <text>           Task text to execute.
  --task-file <path>          Read task text from file.
  --iterations, -n <number>   Number of iterations (default: 5).
  --resume <run-dir>          Resume an existing run directory.
  --skill-file <path>         Add skill file contents to report.txt (repeatable).
  --context-file <path>       Add extra context file contents to report.txt (repeatable).
  --output-root <path>        Run folder parent path (default: claude/reports/repeat_n_times).
  --include-codebase          Append file listing snapshot to report.txt.
  --max-tree-files <number>   Max file paths in codebase snapshot (default: 250).
  --dry-run                   Generate files/prompts but skip codex execution.
  --help, -h                  Show this help text.
EOF
}

require_option_value() {
  local option_name="$1"
  local option_value="${2-}"

  case "$option_value" in
    ""|--task|-t|--task-file|--iterations|-n|--resume|--skill-file|--context-file|--output-root|--include-codebase|--max-tree-files|--dry-run|--help|-h|--)
      echo "Missing value for $option_name." >&2
      exit 2
      ;;
  esac

  if [[ -z "$option_value" ]]; then
    echo "Missing value for $option_name." >&2
    exit 2
  fi
}

slugify() {
  local input="$1"
  local slug
  slug="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-60)"
  if [[ -z "$slug" ]]; then
    slug="task"
  fi
  printf '%s' "$slug"
}

iso_now() {
  if date -Iseconds >/dev/null 2>&1; then
    date -Iseconds
  else
    date +"%Y-%m-%dT%H:%M:%S"
  fi
}

file_mtime() {
  local path="$1"
  if stat -c %Y "$path" >/dev/null 2>&1; then
    stat -c %Y "$path"
  else
    stat -f %m "$path"
  fi
}

file_fingerprint() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    printf '%s:%s' "$(file_mtime "$path")" "$(wc -c < "$path" | tr -d '[:space:]')"
  fi
}

extract_target_iterations() {
  local path="$1"
  awk '
    $0 ~ /^- Target iterations:[[:space:]]*[0-9]+[[:space:]]*$/ {
      line = $0
      sub(/^- Target iterations:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      target = line
    }
    END {
      if (target != "") {
        printf "%s", target
      }
    }
  ' "$path"
}

sync_target_iterations() {
  local path="$1"
  local new_target="$2"
  local temp_path="${path}.tmp.$$"

  if grep -Eq '^- Target iterations:[[:space:]]*[0-9]+[[:space:]]*$' "$path"; then
    awk -v new_target="$new_target" '
      BEGIN { replaced = 0 }
      {
        if (replaced == 0 && $0 ~ /^- Target iterations:[[:space:]]*[0-9]+[[:space:]]*$/) {
          print "- Target iterations: " new_target
          replaced = 1
          next
        }
        print
      }
    ' "$path" > "$temp_path"
  else
    awk -v new_target="$new_target" '
      BEGIN { inserted = 0 }
      {
        print
        if (inserted == 0 && $0 ~ /^- Session started:/) {
          print "- Target iterations: " new_target
          inserted = 1
        }
      }
      END {
        if (inserted == 0) {
          print "- Target iterations: " new_target
        }
      }
    ' "$path" > "$temp_path"
  fi

  mv "$temp_path" "$path"
}

last_logged_iteration() {
  local path="$1"
  local last
  last="$(grep -Eo '^- \[[0-9]+\]' "$path" | grep -Eo '[0-9]+' | sort -n | tail -n 1 || true)"
  if [[ -z "$last" ]]; then
    last=0
  fi
  printf '%s' "$last"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task|-t)
      require_option_value "$1" "${2-}"
      TASK="${2:-}"
      shift 2
      ;;
    --task-file)
      require_option_value "$1" "${2-}"
      TASK_FILE="${2:-}"
      shift 2
      ;;
    --iterations|-n)
      require_option_value "$1" "${2-}"
      ITERATIONS="${2:-}"
      ITERATIONS_SET=true
      shift 2
      ;;
    --resume)
      require_option_value "$1" "${2-}"
      RESUME_DIR="${2:-}"
      shift 2
      ;;
    --skill-file)
      require_option_value "$1" "${2-}"
      SKILL_FILES+=("${2:-}")
      shift 2
      ;;
    --context-file)
      require_option_value "$1" "${2-}"
      CONTEXT_FILES+=("${2:-}")
      shift 2
      ;;
    --output-root)
      require_option_value "$1" "${2-}"
      OUTPUT_ROOT="${2:-}"
      OUTPUT_ROOT_SET=true
      shift 2
      ;;
    --include-codebase)
      INCLUDE_CODEBASE=true
      shift
      ;;
    --max-tree-files)
      require_option_value "$1" "${2-}"
      MAX_TREE_FILES="${2:-}"
      MAX_TREE_FILES_SET=true
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      if [[ -z "$TASK" ]]; then
        TASK="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -n "$RESUME_DIR" ]]; then
  if [[ -n "$TASK" || -n "$TASK_FILE" ]]; then
    echo "When using --resume, do not pass --task, positional task, or --task-file." >&2
    exit 2
  fi

  if ((${#SKILL_FILES[@]} > 0)) || ((${#CONTEXT_FILES[@]} > 0)) || [[ "$INCLUDE_CODEBASE" == true ]]; then
    echo "--skill-file, --context-file, and --include-codebase cannot be used with --resume." >&2
    exit 2
  fi

  if [[ "$OUTPUT_ROOT_SET" == true || "$MAX_TREE_FILES_SET" == true ]]; then
    echo "--output-root and --max-tree-files cannot be used with --resume." >&2
    exit 2
  fi
else
  if [[ -n "$TASK_FILE" && -n "$TASK" ]]; then
    echo "Provide either --task/positional task or --task-file, not both." >&2
    exit 2
  fi

  if [[ -n "$TASK_FILE" ]]; then
    if [[ ! -f "$TASK_FILE" ]]; then
      echo "Task file not found: $TASK_FILE" >&2
      exit 2
    fi
    TASK="$(cat "$TASK_FILE")"
  fi

  if [[ -z "${TASK// }" ]]; then
    echo "Task is required. Use --task, positional task, or --task-file." >&2
    exit 2
  fi
fi

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$ITERATIONS" -lt 1 ]]; then
  echo "--iterations must be an integer >= 1." >&2
  exit 2
fi

if ! [[ "$MAX_TREE_FILES" =~ ^[0-9]+$ ]] || [[ "$MAX_TREE_FILES" -lt 1 ]]; then
  echo "--max-tree-files must be an integer >= 1." >&2
  exit 2
fi

for skill_file in "${SKILL_FILES[@]}"; do
  if [[ ! -f "$skill_file" ]]; then
    echo "Skill file not found: $skill_file" >&2
    exit 2
  fi
done

for context_file in "${CONTEXT_FILES[@]}"; do
  if [[ ! -f "$context_file" ]]; then
    echo "Context file not found: $context_file" >&2
    exit 2
  fi
done

start_iteration=1

if [[ -n "$RESUME_DIR" ]]; then
  run_dir="$RESUME_DIR"
  report_path="${run_dir}/report.txt"
  progress_path="${run_dir}/progress.txt"
  system_prompt_path="${run_dir}/system_prompt.txt"

  if [[ ! -d "$run_dir" ]]; then
    echo "Run directory not found: $run_dir" >&2
    exit 2
  fi

  if [[ ! -f "$report_path" || ! -f "$progress_path" || ! -f "$system_prompt_path" ]]; then
    echo "Resume directory must contain report.txt, progress.txt, and system_prompt.txt: $run_dir" >&2
    exit 2
  fi

  extracted_iterations="$(extract_target_iterations "$progress_path")"

  if [[ "$ITERATIONS_SET" != true ]]; then
    if [[ -z "$extracted_iterations" ]]; then
      echo "Could not determine target iterations from $progress_path. Pass --iterations explicitly." >&2
      exit 2
    fi
    ITERATIONS="$extracted_iterations"
  elif [[ -z "$extracted_iterations" || "$extracted_iterations" != "$ITERATIONS" ]]; then
    sync_target_iterations "$progress_path" "$ITERATIONS"
  fi

  last_iteration="$(last_logged_iteration "$progress_path")"
  if [[ "$last_iteration" =~ ^[0-9]+$ ]] && [[ "$ITERATIONS" =~ ^[0-9]+$ ]] && (( last_iteration > ITERATIONS )); then
    echo "Last logged iteration ($last_iteration) exceeds requested --iterations ($ITERATIONS)." >&2
    echo "Use --iterations >= $last_iteration or omit --iterations when resuming." >&2
    exit 2
  fi
  start_iteration="$((last_iteration + 1))"
else
  timestamp="$(date +"%Y%m%d_%H%M%S")"
  run_slug="$(slugify "$TASK")"
  run_dir="${OUTPUT_ROOT}/${timestamp}_${run_slug}"
  mkdir -p "$run_dir"

  report_path="${run_dir}/report.txt"
  progress_path="${run_dir}/progress.txt"
  system_prompt_path="${run_dir}/system_prompt.txt"
fi

if [[ "$DRY_RUN" != true ]] && ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found on PATH. Install it or run with --dry-run." >&2
  exit 2
fi

if [[ -z "$RESUME_DIR" ]]; then
cat > "$system_prompt_path" <<'EOF'
<Identity>
You are a senior implementation agent specialized in executing real code and workflow tasks over multiple iterative turns while preserving continuity from persistent files rather than chat memory. You treat report.txt as source-of-truth requirements and use progress.txt as the live state handoff between iterations. You prioritize concrete implementation progress in every run, and when required work is complete you shift to quality improvements without losing traceability. You are explicit, disciplined, and outcome-focused.
</Identity>

<Goal>
Your goal is to complete the task described in report.txt by taking concrete action in the repository and recording precise iteration updates in progress.txt so each new call can continue seamlessly from the latest state. You must update progress.txt every iteration with what changed, which files were touched, remaining work, and immediate next steps.

If the core task is complete, improve the implementation for robustness and quality, and still record those improvements in progress.txt before ending the turn.
</Goal>

<Input>
You will receive iteration metadata plus paths to report.txt and progress.txt. Read those files directly, execute the work, and then append an iteration entry to progress.txt.
</Input>
EOF

{
  echo "# Report"
  echo
  echo "## Primary Task"
  echo
  printf '%s\n' "$TASK"
  echo

  if ((${#SKILL_FILES[@]} > 0)); then
    echo "## Skill Files"
    echo
    for skill_file in "${SKILL_FILES[@]}"; do
      echo "## Skill Context: $skill_file"
      echo "<<<BEGIN_FILE:$skill_file>>>"
      cat "$skill_file"
      echo "<<<END_FILE:$skill_file>>>"
      echo
    done
  fi

  if ((${#CONTEXT_FILES[@]} > 0)); then
    echo "## Additional Context Files"
    echo
    for context_file in "${CONTEXT_FILES[@]}"; do
      echo "## Context: $context_file"
      echo "<<<BEGIN_FILE:$context_file>>>"
      cat "$context_file"
      echo "<<<END_FILE:$context_file>>>"
      echo
    done
  fi

  if [[ "$INCLUDE_CODEBASE" == true ]]; then
    echo "## Codebase Snapshot"
    echo
    if command -v rg >/dev/null 2>&1; then
      rg --files | head -n "$MAX_TREE_FILES"
    else
      find . -type f | sed 's#^\./##' | head -n "$MAX_TREE_FILES"
    fi
    echo
  fi
} > "$report_path"

cat > "$progress_path" <<EOF
# Progress

- Session started: $(iso_now)
- Target iterations: $ITERATIONS
- Report file: $report_path
- Task summary: $TASK

## Iteration Log
- [0] Session initialized.
EOF
fi

echo "Run folder: $run_dir"
echo "Iterations: $ITERATIONS"
echo "System prompt: $system_prompt_path"
echo "Report: $report_path"
echo "Progress: $progress_path"
if [[ -n "$RESUME_DIR" ]]; then
  echo "Resuming from iteration: $start_iteration"
fi
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled: codex calls will be skipped."
fi

if ((start_iteration > ITERATIONS)); then
  echo "No remaining iterations to run."
  exit 0
fi

for ((i=start_iteration; i<=ITERATIONS; i++)); do
  iteration_id="$(printf "%02d" "$i")"
  iteration_prompt_path="${run_dir}/iteration_${iteration_id}_prompt.txt"
  iteration_output_path="${run_dir}/iteration_${iteration_id}_output.log"

  before_fingerprint="$(file_fingerprint "$progress_path")"

  cat > "$iteration_prompt_path" <<EOF
$(cat "$system_prompt_path")

<RunMetadata>
Iteration: $i/$ITERATIONS
ReportPath: $report_path
ProgressPath: $progress_path
</RunMetadata>

<MandatoryRules>
1. Read report.txt and progress.txt from disk first.
2. Treat report.txt as static requirements and progress.txt as live handoff state.
3. Implement real progress in this repository now.
4. Append an iteration log entry to progress.txt before finishing.
5. If core work is done, improve quality and still update progress.txt.
6. Include files changed and specific actions in your progress update.
</MandatoryRules>

<ExecutionInstruction>
Start now. Execute the work, then update progress.txt for iteration $i.
</ExecutionInstruction>
EOF

  echo "Starting iteration $i/$ITERATIONS..."

  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: codex execution skipped for iteration $i." > "$iteration_output_path"
    echo "- [$i] Dry run at $(iso_now): prompt generated, runner execution skipped." >> "$progress_path"
    continue
  fi

  if ! codex exec --full-auto "$(cat "$iteration_prompt_path")" > "$iteration_output_path" 2>&1; then
    echo "- [$i] System note: runner failed at $(iso_now). See $iteration_output_path for details." >> "$progress_path"
    echo "Iteration $i failed. See $iteration_output_path for details." >&2
    exit 1
  fi

  after_fingerprint="$(file_fingerprint "$progress_path")"
  if [[ "$before_fingerprint" == "$after_fingerprint" ]]; then
    echo "- [$i] System note: runner finished but no progress update was detected at $(iso_now)." >> "$progress_path"
  fi
done

echo "All iterations completed."
echo "Final progress file: $progress_path"
