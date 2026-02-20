#!/usr/bin/env bash
set -euo pipefail

ITERATIONS=5
TASK=""
TASK_FILE=""
OUTPUT_ROOT="claude/reports/repeat_n_times"
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
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
  --skill-file <path>         Add skill file contents to report.txt (repeatable).
  --context-file <path>       Add extra context file contents to report.txt (repeatable).
  --output-root <path>        Run folder parent path (default: claude/reports/repeat_n_times).
  --include-codebase          Append file listing snapshot to report.txt.
  --max-tree-files <number>   Max file paths in codebase snapshot (default: 250).
  --dry-run                   Generate files/prompts but skip codex execution.
  --help, -h                  Show this help text.
EOF
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task|-t)
      TASK="${2:-}"
      shift 2
      ;;
    --task-file)
      TASK_FILE="${2:-}"
      shift 2
      ;;
    --iterations|-n)
      ITERATIONS="${2:-}"
      shift 2
      ;;
    --skill-file)
      SKILL_FILES+=("${2:-}")
      shift 2
      ;;
    --context-file)
      CONTEXT_FILES+=("${2:-}")
      shift 2
      ;;
    --output-root)
      OUTPUT_ROOT="${2:-}"
      shift 2
      ;;
    --include-codebase)
      INCLUDE_CODEBASE=true
      shift
      ;;
    --max-tree-files)
      MAX_TREE_FILES="${2:-}"
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

if [[ "$DRY_RUN" != true ]] && ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found on PATH. Install it or run with --dry-run." >&2
  exit 2
fi

timestamp="$(date +"%Y%m%d_%H%M%S")"
run_slug="$(slugify "$TASK")"
run_dir="${OUTPUT_ROOT}/${timestamp}_${run_slug}"
mkdir -p "$run_dir"

report_path="${run_dir}/report.txt"
progress_path="${run_dir}/progress.txt"
system_prompt_path="${run_dir}/system_prompt.txt"

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

echo "Run folder: $run_dir"
echo "Iterations: $ITERATIONS"
echo "System prompt: $system_prompt_path"
echo "Report: $report_path"
echo "Progress: $progress_path"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled: codex calls will be skipped."
fi

for ((i=1; i<=ITERATIONS; i++)); do
  iteration_id="$(printf "%02d" "$i")"
  iteration_prompt_path="${run_dir}/iteration_${iteration_id}_prompt.txt"
  iteration_output_path="${run_dir}/iteration_${iteration_id}_output.log"

  before_mtime="$(file_mtime "$progress_path")"

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
    echo "Iteration $i failed. See $iteration_output_path for details." >&2
    exit 1
  fi

  after_mtime="$(file_mtime "$progress_path")"
  if [[ "$before_mtime" == "$after_mtime" ]]; then
    echo "- [$i] System note: runner finished but no progress update was detected at $(iso_now)." >> "$progress_path"
  fi
done

echo "All iterations completed."
echo "Final progress file: $progress_path"
