#!/usr/bin/env bash
set -euo pipefail

TASK=""
TASK_FILE=""
TASK_NAME=""
RESUME_DIR=""
ANSWERS_FILE=""
OUTPUT_ROOT="claude/reports/ask_questions_decompose_conquer"
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
DRY_RUN=false
SKILL_FILES=()
CONTEXT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  # Phase 1: generate context + questions
  ./claude/scripts/ask_questions_decompose_conquer.sh --task "your task" [options]

  # Phase 2: after answering questions
  ./claude/scripts/ask_questions_decompose_conquer.sh --resume <run-dir> --answers-file <answers.md> [--dry-run]

Options:
  --task, -t <text>           Task text to execute.
  --task-file <path>          Read task text from file.
  --task-name <name>          Optional folder-safe task name override.
  --resume <run-dir>          Resume an existing run directory for calls 2 and 3.
  --answers-file <path>       Answers markdown path. Required for resume; optional for fresh run.
  --skill-file <path>         Add skill file contents to report.txt (repeatable).
  --context-file <path>       Add extra context file contents to report.txt (repeatable).
  --output-root <path>        Run folder parent path (default: claude/reports/ask_questions_decompose_conquer).
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
    --resume)
      RESUME_DIR="${2:-}"
      shift 2
      ;;
    --answers-file)
      ANSWERS_FILE="${2:-}"
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

if ! [[ "$MAX_TREE_FILES" =~ ^[0-9]+$ ]] || [[ "$MAX_TREE_FILES" -lt 1 ]]; then
  echo "--max-tree-files must be an integer >= 1." >&2
  exit 2
fi

if [[ -n "$RESUME_DIR" ]]; then
  if [[ -n "$TASK" || -n "$TASK_FILE" || -n "$TASK_NAME" ]]; then
    echo "When using --resume, do not pass task inputs." >&2
    exit 2
  fi
  if ((${#SKILL_FILES[@]} > 0)) || ((${#CONTEXT_FILES[@]} > 0)) || [[ "$INCLUDE_CODEBASE" == true ]]; then
    echo "When using --resume, do not pass --skill-file, --context-file, or --include-codebase." >&2
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
    echo "Task is required unless using --resume." >&2
    exit 2
  fi
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

if [[ -n "$RESUME_DIR" ]]; then
  run_dir="$RESUME_DIR"
  report_path="${run_dir}/report.txt"
  discovery_context_path="${run_dir}/discovery_context.md"
  questions_path="${run_dir}/questions.md"
  decomposed_plan_path="${run_dir}/decomposed_plan.md"
  call2_system_prompt_path="${run_dir}/call_2_decompose_system_prompt.txt"
  call3_system_prompt_path="${run_dir}/call_3_conquer_system_prompt.txt"

  if [[ ! -d "$run_dir" ]]; then
    echo "Run directory not found: $run_dir" >&2
    exit 2
  fi
  for required in "$report_path" "$discovery_context_path" "$questions_path" "$call2_system_prompt_path" "$call3_system_prompt_path"; do
    if [[ ! -f "$required" ]]; then
      echo "Resume directory missing required file: $required" >&2
      exit 2
    fi
  done

  if [[ -z "$ANSWERS_FILE" ]]; then
    ANSWERS_FILE="${run_dir}/answers.md"
  fi
  if [[ ! -f "$ANSWERS_FILE" ]]; then
    echo "Answers file not found: $ANSWERS_FILE" >&2
    echo "Provide --answers-file or create ${run_dir}/answers.md before resuming." >&2
    exit 2
  fi
  answers_path="$ANSWERS_FILE"

  call2_prompt_path="${run_dir}/call_2_decompose_prompt.txt"
  call3_prompt_path="${run_dir}/call_3_conquer_prompt.txt"
  call2_log_path="${run_dir}/call_2_decompose_output.log"
  call3_log_path="${run_dir}/call_3_conquer_output.log"
  implementation_summary_path="${run_dir}/implementation_summary.md"
else
  timestamp="$(date +"%Y%m%d_%H%M%S")"
  task_slug="$(slugify "${TASK_NAME:-$TASK}")"
  task_dir="${OUTPUT_ROOT}/${task_slug}"
  run_dir="${task_dir}/runs/${timestamp}"
  mkdir -p "$run_dir"

  report_path="${run_dir}/report.txt"
  discovery_context_path="${run_dir}/discovery_context.md"
  questions_path="${run_dir}/questions.md"
  answers_path="${ANSWERS_FILE:-${run_dir}/answers.md}"
  decomposed_plan_path="${run_dir}/decomposed_plan.md"
  implementation_summary_path="${run_dir}/implementation_summary.md"

  call1_system_prompt_path="${run_dir}/call_1_ask_questions_system_prompt.txt"
  call2_system_prompt_path="${run_dir}/call_2_decompose_system_prompt.txt"
  call3_system_prompt_path="${run_dir}/call_3_conquer_system_prompt.txt"

  call1_prompt_path="${run_dir}/call_1_ask_questions_prompt.txt"
  call2_prompt_path="${run_dir}/call_2_decompose_prompt.txt"
  call3_prompt_path="${run_dir}/call_3_conquer_prompt.txt"

  call1_log_path="${run_dir}/call_1_ask_questions_output.log"
  call2_log_path="${run_dir}/call_2_decompose_output.log"
  call3_log_path="${run_dir}/call_3_conquer_output.log"

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

  cat > "$call1_system_prompt_path" <<'EOF'
You are a requirements-clarification and discovery specialist. Before implementation, you must build understanding of the codebase and the task by inspecting relevant files and architecture context, then produce a focused set of clarifying questions where uncertainty remains. Ask questions only where they materially affect implementation choices, and ensure they are concrete and answerable. Prioritize high-impact ambiguities first, then secondary details.
EOF

  cat > "$call2_system_prompt_path" <<'EOF'
You are a problem decomposer and implementation planner. Break complex work into natural seams and independent components, then produce a sequenced plan that is executable step by step. The plan must identify dependencies, critical path, and clear sub-tasks that can be executed with minimal ambiguity. Focus on decomposition quality: each step should be meaningful, bounded, and connected to a concrete outcome.
EOF

  cat > "$call3_system_prompt_path" <<'EOF'
You are an implementation executor for a decomposed plan. Move deliberately, think longer before each major change, and execute in small steps with verification after each step. Do not rush through the entire task at once: complete one step, validate it, then continue. Preserve continuity with prior context files and ensure the final implementation aligns with the original task and answered clarifications.
EOF

  cat > "$call1_prompt_path" <<EOF
$(cat "$call1_system_prompt_path")

Original task:
$TASK

Context report: $report_path

Explore the codebase and relevant files first. Then output:
1) a concise but concrete understanding of the existing codebase and relevant components to $discovery_context_path,
2) clarifying questions needed for implementation to $questions_path.

Question quality rules:
- Ask only questions that affect architecture, behavior, interfaces, constraints, or acceptance criteria.
- Group questions by theme and include a short reason for each.
- Keep questions specific and actionable.
EOF

  echo "Run folder: $run_dir"
  echo "Report: $report_path"
  echo "Discovery context: $discovery_context_path"
  echo "Questions: $questions_path"
  echo "Answers expected at: $answers_path"
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run enabled: codex calls will be skipped."
  fi

  echo "Call 1/3: ask questions + codebase discovery"
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: call 1 skipped at $(iso_now)." > "$call1_log_path"
    {
      echo "# Discovery Context"
      echo
      echo "- Dry run placeholder context generated at $(iso_now)."
      echo "- No real exploration executed."
    } > "$discovery_context_path"
    {
      echo "# Clarifying Questions"
      echo
      echo "## Scope"
      echo "1. Placeholder question for dry run."
      echo
      echo "## Constraints"
      echo "2. Placeholder question for dry run."
    } > "$questions_path"
  else
    codex exec --full-auto "$(cat "$call1_prompt_path")" > "$call1_log_path" 2>&1
  fi

  # If answers file doesn't exist yet, stop after call 1 so user can answer.
  if [[ ! -f "$answers_path" ]]; then
    cat > "$answers_path" <<'EOF'
# Answers

Please answer the questions from questions.md here.
EOF
    echo
    echo "Phase 1 complete."
    echo "Please answer the questions in: $answers_path"
    echo "Then resume with:"
    echo "./claude/scripts/ask_questions_decompose_conquer.sh --resume \"$run_dir\" --answers-file \"$answers_path\""
    exit 0
  fi
fi

# Calls 2 and 3 (resume path, or fresh path with pre-provided answers file)
cat > "$call2_prompt_path" <<EOF
$(cat "$call2_system_prompt_path")

Original task:
$(awk 'BEGIN{print ""} {print} END{print ""}' "$report_path")

Discovery context file: $discovery_context_path
Questions file: $questions_path
Answers file: $answers_path

Create a decomposed implementation plan based on the task, discovered codebase context, and answered clarifications.
Write the plan to $decomposed_plan_path as markdown with:
1) decomposition into natural sub-problems,
2) dependency ordering / critical path,
3) concrete execution steps,
4) risks and mitigations per major phase.
Do not implement in this call.
EOF

cat > "$call3_prompt_path" <<EOF
$(cat "$call3_system_prompt_path")

Original task:
$(awk 'BEGIN{print ""} {print} END{print ""}' "$report_path")

Discovery context file: $discovery_context_path
Questions file: $questions_path
Answers file: $answers_path
Decomposed plan file: $decomposed_plan_path

Implement the solution now using the decomposed plan, incorporating the discovered codebase context and answered clarifications.
Work in small validated steps and keep alignment with the original task.
When done, write a concise implementation summary to $implementation_summary_path with files changed, major decisions, and validation performed.
EOF

echo "Call 2/3: decompose + plan"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 2 skipped at $(iso_now)." > "$call2_log_path"
  {
    echo "# Decomposed Plan"
    echo
    echo "1. Placeholder phase one."
    echo "2. Placeholder phase two."
    echo "3. Placeholder phase three."
  } > "$decomposed_plan_path"
else
  codex exec --full-auto "$(cat "$call2_prompt_path")" > "$call2_log_path" 2>&1
fi

echo "Call 3/3: conquer (implementation)"
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
echo "Run folder: $run_dir"
echo "Outputs:"
echo "- Discovery context: $discovery_context_path"
echo "- Questions: $questions_path"
echo "- Answers: $answers_path"
echo "- Decomposed plan: $decomposed_plan_path"
echo "- Implementation summary: $implementation_summary_path"
echo "Logs:"
echo "- $call2_log_path"
echo "- $call3_log_path"
