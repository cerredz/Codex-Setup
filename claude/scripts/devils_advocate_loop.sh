#!/usr/bin/env bash
set -euo pipefail

TASK=""
TASK_FILE=""
TASK_NAME=""
AUTO_IMPLEMENT="false"
OUTPUT_ROOT="claude/reports/devils_advocate_loop"
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
DRY_RUN=false
SKILL_FILES=()
CONTEXT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  ./claude/scripts/devils_advocate_loop.sh --task "your task" [options]
  ./claude/scripts/devils_advocate_loop.sh "your task" [options]

Options:
  --task, -t <text>           Task text to execute.
  --task-file <path>          Read task text from file.
  --task-name <name>          Optional folder-safe task name override.
  --auto-implement <bool>     true|false (default: false). If true, run final implementation call.
  --skill-file <path>         Add skill file contents to report.txt (repeatable).
  --context-file <path>       Add extra context file contents to report.txt (repeatable).
  --output-root <path>        Run folder parent path (default: claude/reports/devils_advocate_loop).
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

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
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
    --auto-implement)
      AUTO_IMPLEMENT="${2:-}"
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

AUTO_IMPLEMENT="$(to_lower "$AUTO_IMPLEMENT")"
if [[ "$AUTO_IMPLEMENT" != "true" && "$AUTO_IMPLEMENT" != "false" ]]; then
  echo "--auto-implement must be true or false." >&2
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
plans_dir="${run_dir}/plans"
critiques_dir="${run_dir}/devils_advocate_critiques"
prompts_dir="${run_dir}/prompts"
logs_dir="${run_dir}/logs"
mkdir -p "$run_dir" "$plans_dir" "$critiques_dir" "$prompts_dir" "$logs_dir"

report_path="${run_dir}/report.txt"
final_plan_path="${task_dir}/final_plan.md"
implementation_summary_path="${task_dir}/implementation_summary.md"
devils_system_prompt_path="${prompts_dir}/devils_advocate_system_prompt.txt"
planner_system_prompt_path="${prompts_dir}/planner_system_prompt.txt"
implementer_system_prompt_path="${prompts_dir}/implementer_system_prompt.txt"

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

cat > "$planner_system_prompt_path" <<'EOF'
<Identity>
You are a world-class planning strategist with deep expertise in decomposing complex objectives into execution-ready, high-clarity plans across software, operations, research, and analytical workstreams. You are known for building plans that are specific enough to execute directly while remaining adaptable to real constraints and evolving information. Your background includes cross-functional delivery in ambiguous environments where plan quality determines implementation success and failure rates. Your unique strength is translating broad prompts into structured, dependency-aware action paths that eliminate vagueness and reduce execution risk. You consistently optimize for plans that are understandable, testable, and outcome-oriented.
</Identity>

<Goal>
Your goal is to generate a concrete, in-depth plan that is tightly aligned to the original task, with clear sequencing, dependency-aware ordering, and sufficient detail for immediate execution without guesswork, while avoiding speculative or irrelevant steps that do not contribute to the requested outcome. The plan must be explicit about what should be done, in what order, and why that order matters so that downstream implementation can proceed with minimal ambiguity and maximal confidence.

After reading your output, the user should have a practical plan that can be executed step by step, with each section mapping directly to the task's objective, constraints, and expected deliverables.
</Goal>

<Input>
You will receive the original task and a context report file path. Use those inputs to produce a detailed implementation plan in markdown at the specified output path.
</Input>
EOF

cat > "$devils_system_prompt_path" <<'EOF'
<Identity>
You are a rigorous devil's advocate evaluator who specializes in stress-testing plans for hidden weaknesses, faulty assumptions, ambiguous instructions, and misalignment to stated objectives across technical and non-technical domains. You are trained to challenge confident but fragile plans by surfacing failure modes and uncovering where apparent completeness masks critical gaps. Your expertise includes risk analysis, quality review, dependency scrutiny, and argument-level critique that improves plan resilience before execution begins. Your unique strength is producing highly specific objections that are actionable, evidence-based, and directly tied to the original task requirements. You are uncompromising about clarity, coherence, and alignment.
</Identity>

<Goal>
Your goal is to critique the provided plan against the original task by identifying material weaknesses, such as invalid assumptions, missing detail, unclear sequencing, risk blind spots, and places where the plan fails to fully satisfy the prompt, then produce prioritized findings with concrete corrective guidance that can be applied in the next revision pass. The critique must focus on issues that impact execution quality and outcome reliability, rather than stylistic preferences or low-value commentary.

After reading your output, the next planner should know exactly what to fix, why each issue matters, and how to revise the plan to better match the original task with higher confidence and lower risk.
</Goal>

<Input>
You will receive the original task, a current plan file path, and a context report file path. Use these to produce a prioritized markdown critique at the specified output path.
</Input>
EOF

cat > "$implementer_system_prompt_path" <<'EOF'
<Identity>
You are an expert implementation executor who turns finalized plans into concrete, high-quality outcomes while preserving alignment to the original task and constraints. You are experienced in translating planning artifacts into precise execution steps and validating progress as you go to prevent drift and regression. Your background includes delivering complex, multi-step implementations where correctness, traceability, and completeness are critical. Your unique strength is disciplined execution that follows the selected plan without losing awareness of task intent. You produce clear implementation summaries that make changes and decisions auditable.
</Identity>

<Goal>
Your goal is to implement the original task using the finalized plan as the execution blueprint, carrying out the work in a coherent sequence, maintaining fidelity to the objective, and avoiding unnecessary scope expansion, while producing a concise summary of what was changed and how outcomes were validated. You must execute what is needed to satisfy the task and ensure the resulting state is understandable and defensible for review.

After reading your output, the user should have both the completed implementation and a concise summary of files changed, key decisions, and validation checks performed.
</Goal>

<Input>
You will receive the original task, a final plan file path, and a context report file path. Use those inputs to implement the task and write a concise execution summary to the specified summary path.
</Input>
EOF

echo "Run folder: $run_dir"
echo "Task folder: $task_dir"
echo "Report: $report_path"
echo "Final plan output: $final_plan_path"
echo "Auto implement: $AUTO_IMPLEMENT"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled: codex calls will be skipped."
fi

# Call 1: initial plan
plan_input_path="${plans_dir}/plan_round_0.md"
call1_prompt_path="${prompts_dir}/call_1_initial_plan_prompt.txt"
call1_log_path="${logs_dir}/call_1_initial_plan.log"

cat > "$call1_prompt_path" <<EOF
$(cat "$planner_system_prompt_path")

Original task:
$TASK

Context report file: $report_path

Create an in-depth implementation plan for this task and write it to $plan_input_path as markdown.
The plan should be clear, specific, and implementation-ready.
EOF

echo "Call 1/7: initial plan generation"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 1 skipped at $(iso_now)." > "$call1_log_path"
  {
    echo "# Plan Round 0"
    echo
    echo "1. Placeholder initial plan step."
    echo "2. Placeholder initial plan step."
    echo "3. Placeholder initial plan step."
  } > "$plan_input_path"
else
  codex exec --full-auto "$(cat "$call1_prompt_path")" > "$call1_log_path" 2>&1
fi

# Three devil's advocate loops:
# For each round i:
# - Critique plan_round_(i-1) -> critique_round_i
# - Revise using critique -> plan_round_i
for i in 1 2 3; do
  prev_plan_path="${plans_dir}/plan_round_$((i-1)).md"
  critique_path="${critiques_dir}/critique_round_${i}.md"
  revised_plan_path="${plans_dir}/plan_round_${i}.md"
  critique_prompt_path="${prompts_dir}/call_$((2*i))_critique_round_${i}.txt"
  revise_prompt_path="${prompts_dir}/call_$((2*i+1))_revise_round_${i}.txt"
  critique_log_path="${logs_dir}/call_$((2*i))_critique_round_${i}.log"
  revise_log_path="${logs_dir}/call_$((2*i+1))_revise_round_${i}.log"

  cat > "$critique_prompt_path" <<EOF
$(cat "$devils_system_prompt_path")

Original task:
$TASK

Current plan file: $prev_plan_path
Context report file: $report_path

Critique this plan in relation to the original task. Focus on:
- incorrect assumptions
- missing detail or ambiguity
- misalignment with task goals
- risk areas and edge cases
- sequencing/dependency issues

Write your critique to $critique_path as markdown with prioritized findings and concrete corrections.
EOF

  echo "Call $((2*i))/7: devil's advocate critique round $i"
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: critique round $i skipped at $(iso_now)." > "$critique_log_path"
    {
      echo "# Critique Round $i"
      echo
      echo "- Placeholder critique finding for round $i."
      echo "- Placeholder objection for round $i."
    } > "$critique_path"
  else
    codex exec --full-auto "$(cat "$critique_prompt_path")" > "$critique_log_path" 2>&1
  fi

  cat > "$revise_prompt_path" <<EOF
$(cat "$planner_system_prompt_path")

Original task:
$TASK

Current plan file: $prev_plan_path
Devil's advocate critique file: $critique_path
Context report file: $report_path

Revise the plan to address the critique while preserving alignment to the original task.
Write the revised plan to $revised_plan_path as markdown.
EOF

  echo "Call $((2*i+1))/7: revise plan round $i"
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: revise round $i skipped at $(iso_now)." > "$revise_log_path"
    {
      echo "# Plan Round $i"
      echo
      echo "1. Placeholder revised step for round $i."
      echo "2. Placeholder revised step for round $i."
      echo "3. Placeholder revised step for round $i."
    } > "$revised_plan_path"
  else
    codex exec --full-auto "$(cat "$revise_prompt_path")" > "$revise_log_path" 2>&1
  fi
done

cp "${plans_dir}/plan_round_3.md" "$final_plan_path"
echo "Final plan written to: $final_plan_path"

if [[ "$AUTO_IMPLEMENT" == "true" ]]; then
  impl_prompt_path="${prompts_dir}/call_8_implement_final_plan.txt"
  impl_log_path="${logs_dir}/call_8_implement_final_plan.log"

  cat > "$impl_prompt_path" <<EOF
$(cat "$implementer_system_prompt_path")

Original task:
$TASK

Final plan file: $final_plan_path
Context report file: $report_path

Implement the task using the final plan.
When done, write a concise implementation summary to $implementation_summary_path with files changed, key decisions, and validation performed.
EOF

  echo "Call 8/8: auto-implement final plan"
  if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: auto-implement call skipped at $(iso_now)." > "$impl_log_path"
    {
      echo "# Implementation Summary"
      echo
      echo "- Dry run placeholder summary generated at $(iso_now)."
      echo "- No repository changes were made."
    } > "$implementation_summary_path"
  else
    codex exec --full-auto "$(cat "$impl_prompt_path")" > "$impl_log_path" 2>&1
  fi
else
  echo "Auto-implement disabled. Final plan is ready for manual review/edit before implementation."
fi

echo "Run complete."
echo "Outputs:"
echo "- Final plan: $final_plan_path"
echo "- Plans directory: $plans_dir"
echo "- Critiques directory: $critiques_dir"
if [[ "$AUTO_IMPLEMENT" == "true" ]]; then
  echo "- Implementation summary: $implementation_summary_path"
fi
