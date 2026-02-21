#!/usr/bin/env bash
set -euo pipefail

TASK=""
TASK_FILE=""
TASK_NAME=""
IDEAS_COUNT=7
OUTPUT_ROOT="claude/reports/branch_elevate_and_merge"
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
DRY_RUN=false
SKILL_FILES=()
CONTEXT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  ./claude/scripts/branch_elevate_and_merge.sh --task "your task" [options]
  ./claude/scripts/branch_elevate_and_merge.sh "your task" [options]

Options:
  --task, -t <text>           Task text to execute.
  --task-file <path>          Read task text from file.
  --task-name <name>          Optional folder-safe task name override.
  --ideas-count <5-10>        Number of distinct ideas to generate (default: 7).
  --skill-file <path>         Add skill file contents to report.txt (repeatable).
  --context-file <path>       Add extra context file contents to report.txt (repeatable).
  --output-root <path>        Run folder parent path (default: claude/reports/branch_elevate_and_merge).
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
    --ideas-count)
      IDEAS_COUNT="${2:-}"
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

if ! [[ "$IDEAS_COUNT" =~ ^[0-9]+$ ]] || [[ "$IDEAS_COUNT" -lt 5 ]] || [[ "$IDEAS_COUNT" -gt 10 ]]; then
  echo "--ideas-count must be an integer between 5 and 10." >&2
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
ideas_dir="${task_dir}/branch_ideas"
selected_dir="${task_dir}/selected_branch"
implementation_dir="${task_dir}/implementation_summaries"
mkdir -p "$run_dir" "$ideas_dir" "$selected_dir" "$implementation_dir"

report_path="${run_dir}/report.txt"
ideas_path="${ideas_dir}/${timestamp}.md"
selected_branch_path="${selected_dir}/${timestamp}.md"
implementation_summary_path="${implementation_dir}/${timestamp}.md"
evaluator_system_prompt_path="${run_dir}/evaluator_system_prompt.txt"

call1_prompt_path="${run_dir}/call_1_brainstorm_prompt.txt"
call2_prompt_path="${run_dir}/call_2_evaluate_prompt.txt"
call3_prompt_path="${run_dir}/call_3_implement_prompt.txt"
call1_log_path="${run_dir}/call_1_brainstorm_output.log"
call2_log_path="${run_dir}/call_2_evaluate_output.log"
call3_log_path="${run_dir}/call_3_implement_output.log"

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

cat > "$evaluator_system_prompt_path" <<'EOF'
<Identity>
You are a branch evaluator specialized in selecting the strongest strategy among multiple candidate approaches across software, operations, research, data, and content tasks. You evaluate options for feasibility, expected quality, risk, implementation cost, and alignment to the original objective. You avoid local-minima choices by explicitly comparing trade-offs rather than choosing the most obvious first option. You produce selection outputs that are specific enough to execute without re-planning.
</Identity>

<Goal>
Your goal is to evaluate all candidate branches and choose exactly one best branch that maximizes expected outcome quality while keeping risk and execution complexity acceptable for the task constraints. You must explain why the selected branch wins, why key alternatives were rejected, and provide a concrete execution plan that can be implemented directly in a follow-up call.

After reading your output, an implementation agent should have a clear branch choice, a justified rationale, and an actionable step sequence.
</Goal>

<Input>
You will receive the original task, a context report, and a markdown file containing 5-10 distinct branch ideas. Evaluate these branches and write one final selected-branch document.
</Input>
EOF

cat > "$call1_prompt_path" <<EOF
$TASK

Use this file for optional attached context: $report_path.
Generate exactly $IDEAS_COUNT different ideas (branches) to solve this task, and make them genuinely distinct from each other to avoid local minima.
For each idea, include: branch name, core approach, expected strengths, expected weaknesses/risks, and why it could succeed.
Write the full output to $ideas_path as markdown. Do not implement any branch in this call.
EOF

cat > "$call2_prompt_path" <<EOF
$(cat "$evaluator_system_prompt_path")

Original task:
$TASK

Attached context file: $report_path
Candidate branch ideas file: $ideas_path

Evaluate all branch ideas and select exactly one best branch.
Write your output to $selected_branch_path in markdown with:
1) selected branch,
2) selection rationale,
3) rejected alternatives summary,
4) concrete implementation steps.
Do not implement in this call.
EOF

cat > "$call3_prompt_path" <<EOF
$TASK

Use this file for optional attached context: $report_path.
Use this brainstormed branch set as context: $ideas_path.
Use this selected best branch as the implementation plan of record: $selected_branch_path.
Implement the selected branch now.
When done, write a concise implementation summary to $implementation_summary_path, including files changed and key outcomes.
EOF

echo "Run folder: $run_dir"
echo "Task folder: $task_dir"
echo "Report: $report_path"
echo "Ideas output: $ideas_path"
echo "Selected branch output: $selected_branch_path"
echo "Implementation summary: $implementation_summary_path"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled: codex calls will be skipped."
fi

echo "Call 1/3: brainstorm branches"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 1 skipped at $(iso_now)." > "$call1_log_path"
  {
    echo "# Branch Ideas"
    echo
    for n in $(seq 1 "$IDEAS_COUNT"); do
      echo "## Idea $n: Placeholder Branch $n"
      echo "- Approach: Placeholder approach for dry run."
      echo "- Strengths: Placeholder strengths."
      echo "- Risks: Placeholder risks."
      echo "- Why it could succeed: Placeholder reasoning."
      echo
    done
  } > "$ideas_path"
else
  codex exec --full-auto "$(cat "$call1_prompt_path")" > "$call1_log_path" 2>&1
fi

echo "Call 2/3: evaluate branches"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 2 skipped at $(iso_now)." > "$call2_log_path"
  {
    echo "# Selected Branch"
    echo
    echo "## Winner"
    echo "- Idea 1 (placeholder)"
    echo
    echo "## Rationale"
    echo "- Placeholder rationale for dry run."
    echo
    echo "## Rejected Alternatives"
    echo "- Placeholder alternatives summary."
    echo
    echo "## Implementation Steps"
    echo "1. Placeholder step one."
    echo "2. Placeholder step two."
  } > "$selected_branch_path"
else
  codex exec --full-auto "$(cat "$call2_prompt_path")" > "$call2_log_path" 2>&1
fi

echo "Call 3/3: implement selected branch"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 3 skipped at $(iso_now)." > "$call3_log_path"
  {
    echo "# Implementation Summary"
    echo
    echo "- Dry run placeholder summary generated at $(iso_now)."
    echo "- No repository changes were made."
  } > "$implementation_summary_path"
else
  codex exec --full-auto "$(cat "$call3_prompt_path")" > "$call3_log_path" 2>&1
fi

echo "Run complete."
echo "Logs:"
echo "- $call1_log_path"
echo "- $call2_log_path"
echo "- $call3_log_path"
