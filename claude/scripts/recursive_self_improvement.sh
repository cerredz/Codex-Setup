#!/usr/bin/env bash
set -euo pipefail

TASK=""
TASK_FILE=""
TASK_NAME=""
IMPROVEMENT_ROUNDS=4
OUTPUT_ROOT="claude/reports/recursive_self_improvement"
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
DRY_RUN=false
SKILL_FILES=()
CONTEXT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  ./claude/scripts/recursive_self_improvement.sh --task "your task" [options]
  ./claude/scripts/recursive_self_improvement.sh "your task" [options]

Options:
  --task, -t <text>               Task text to execute.
  --task-file <path>              Read task text from file.
  --task-name <name>              Optional folder-safe task name override.
  --improvement-rounds <3-5>      Number of recursive prompt improvements (default: 4).
  --skill-file <path>             Add skill file contents to report.txt (repeatable).
  --context-file <path>           Add extra context file contents to report.txt (repeatable).
  --output-root <path>            Run folder parent path (default: claude/reports/recursive_self_improvement).
  --include-codebase              Append file listing snapshot to report.txt.
  --max-tree-files <number>       Max file paths in codebase snapshot (default: 250).
  --dry-run                       Generate files/prompts but skip codex execution.
  --help, -h                      Show this help text.
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

extract_final_prompt() {
  local source_file="$1"
  local target_file="$2"

  awk '
    /<<<FINAL_PROMPT_START>>>/ { capture = 1; next }
    /<<<FINAL_PROMPT_END>>>/ { capture = 0; exit }
    capture { print }
  ' "$source_file" > "$target_file"
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
    --task-name)
      TASK_NAME="${2:-}"
      shift 2
      ;;
    --improvement-rounds)
      IMPROVEMENT_ROUNDS="${2:-}"
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

if ! [[ "$IMPROVEMENT_ROUNDS" =~ ^[0-9]+$ ]] || [[ "$IMPROVEMENT_ROUNDS" -lt 3 ]] || [[ "$IMPROVEMENT_ROUNDS" -gt 5 ]]; then
  echo "--improvement-rounds must be an integer between 3 and 5." >&2
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
task_slug="$(slugify "${TASK_NAME:-$TASK}")"
task_dir="${OUTPUT_ROOT}/${task_slug}"
run_dir="${task_dir}/runs/${timestamp}"
mkdir -p "$run_dir"

report_path="${run_dir}/report.txt"
improvements_path="${run_dir}/prompt_improvements.md"
final_prompt_path="${run_dir}/final_selected_prompt.txt"
execution_summary_path="${run_dir}/execution_summary.md"

call1_prompt_path="${run_dir}/call_1_refine_prompt.txt"
call2_prompt_path="${run_dir}/call_2_execute_prompt.txt"
call1_log_path="${run_dir}/call_1_refine_output.log"
call2_log_path="${run_dir}/call_2_execute_output.log"

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

cat > "$call1_prompt_path" <<EOF
You are a recursive self-improvement prompt engineer.

Original task:
$TASK

Context report file: $report_path

Generate exactly $IMPROVEMENT_ROUNDS improved prompt versions that iteratively refine the prior version while preserving strict fidelity to the original task.
This is prompt enhancement, not prompt rewriting into a different style or workflow.

Hard constraints:
1) Keep the same core objective, deliverables, and scope as the original task.
2) Preserve the user's writing style and tone; the result should read like an improved extension of the original prompt, not a new template.
3) Do NOT add new requests, new goals, extra deliverables, new personas, new sections, or additional workflow requirements that were not in the original task.
4) Allowed changes are limited to clarity improvements, ambiguity reduction, better ordering, and tighter phrasing while keeping meaning constant.
5) If a candidate improvement introduces new requirements, reject it and revise.

Output requirements:
1) Write all versions to $improvements_path as markdown.
2) Include sections:
   - "## Prompt Version 1" ... through "## Prompt Version $IMPROVEMENT_ROUNDS"
   - For each version, include:
     - "Fidelity Check" (alignment to original objective/scope),
     - "Style Preservation Check" (how it keeps original writing style),
     - "Added Requirements Check" (must explicitly list "None" if no additions).
3) After the versions, include:
   - "## Final Selected Prompt"
   - A block delimited by:
     <<<FINAL_PROMPT_START>>>
     [full final prompt text here]
     <<<FINAL_PROMPT_END>>>
   - "## Selection Rationale"

Do not execute the task in this call; only produce improved prompts.
EOF

echo "Run folder: $run_dir"
echo "Task folder: $task_dir"
echo "Report: $report_path"
echo "Prompt improvements: $improvements_path"
echo "Final selected prompt: $final_prompt_path"
echo "Execution summary: $execution_summary_path"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled: codex calls will be skipped."
fi

echo "Call 1/2: recursive prompt improvement"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 1 skipped at $(iso_now)." > "$call1_log_path"
  {
    echo "# Prompt Improvements"
    echo
    for n in $(seq 1 "$IMPROVEMENT_ROUNDS"); do
      echo "## Prompt Version $n"
      echo "Placeholder improved prompt version $n for dry run."
      echo
      echo "### Fidelity Check"
      echo "- Placeholder fidelity check for version $n."
      echo
    done
    echo "## Final Selected Prompt"
    echo "<<<FINAL_PROMPT_START>>>"
    echo "You are an implementation agent. Execute the original task exactly as specified, using attached report context, and produce high-quality results."
    echo "<<<FINAL_PROMPT_END>>>"
    echo
    echo "## Selection Rationale"
    echo "- Placeholder rationale for dry run."
  } > "$improvements_path"
else
  codex exec --full-auto "$(cat "$call1_prompt_path")" > "$call1_log_path" 2>&1
fi

extract_final_prompt "$improvements_path" "$final_prompt_path"
if [[ ! -s "$final_prompt_path" ]]; then
  echo "Failed to extract final prompt from $improvements_path." >&2
  echo "Ensure call 1 output includes <<<FINAL_PROMPT_START>>> and <<<FINAL_PROMPT_END>>>." >&2
  exit 1
fi

cat > "$call2_prompt_path" <<EOF
Execute the final selected prompt below exactly as written.
Do not add extra goals, constraints, structure, personas, or side requests beyond the prompt itself.

<<<FINAL_PROMPT_TO_EXECUTE>>>
$(cat "$final_prompt_path")
<<<END_FINAL_PROMPT_TO_EXECUTE>>>

Available context report (task + skill-file context): $report_path
Prompt improvement provenance (reference only): $improvements_path

After completing execution, write a concise execution summary to $execution_summary_path including files changed, key decisions, and validation performed.
EOF

echo "Call 2/2: execute final selected prompt"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 2 skipped at $(iso_now)." > "$call2_log_path"
  {
    echo "# Execution Summary"
    echo
    echo "- Dry run placeholder summary generated at $(iso_now)."
    echo "- No repository changes were made."
  } > "$execution_summary_path"
else
  codex exec --full-auto "$(cat "$call2_prompt_path")" > "$call2_log_path" 2>&1
fi

echo "Run complete."
echo "Logs:"
echo "- $call1_log_path"
echo "- $call2_log_path"
