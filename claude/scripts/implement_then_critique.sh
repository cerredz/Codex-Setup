#!/usr/bin/env bash
set -euo pipefail

TASK=""
TASK_FILE=""
OUTPUT_ROOT="claude/reports/implement_then_critique"
INCLUDE_CODEBASE=false
MAX_TREE_FILES=250
DRY_RUN=false
SKILL_FILES=()
CONTEXT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  ./claude/scripts/implement_then_critique.sh --task "your task" [options]
  ./claude/scripts/implement_then_critique.sh "your task" [options]

Options:
  --task, -t <text>           Task text to execute.
  --task-file <path>          Read task text from file.
  --skill-file <path>         Add skill file contents to report.txt (repeatable).
  --context-file <path>       Add extra context file contents to report.txt (repeatable).
  --output-root <path>        Run folder parent path (default: claude/reports/implement_then_critique).
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
task_slug="$(slugify "$TASK")"
task_dir="${OUTPUT_ROOT}/${task_slug}"
run_dir="${task_dir}/${timestamp}"
mkdir -p "$run_dir"

report_path="${run_dir}/report.txt"
updated_files_path="${run_dir}/${task_slug}_updated_files.txt"
critique_path="${task_dir}/critique.md"
critiquer_system_prompt_path="${run_dir}/critiquer_system_prompt.txt"
call1_prompt_path="${run_dir}/call_1_implement_prompt.txt"
call2_prompt_path="${run_dir}/call_2_critique_prompt.txt"
call3_prompt_path="${run_dir}/call_3_reimplement_prompt.txt"
call1_log_path="${run_dir}/call_1_implement_output.log"
call2_log_path="${run_dir}/call_2_critique_output.log"
call3_log_path="${run_dir}/call_3_reimplement_output.log"

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

cat > "$updated_files_path" <<EOF
# Updated Files

Task slug: $task_slug
Created: $(iso_now)

Format:
- path/to/file.ext | short summary of what changed

Entries:
- (none yet)
EOF

cat > "$critiquer_system_prompt_path" <<'EOF'
<Identity>
You are a rigorous critique agent with deep expertise in evaluating implementation outcomes across domains including software, data workflows, research outputs, operations tasks, and content artifacts. You assess work against original requirements with strict attention to correctness, completeness, quality, and practical usefulness. You are highly effective at identifying hidden gaps, risk areas, weak assumptions, and quality issues that survive a first implementation pass. You communicate findings with clear evidence, prioritized severity, and concrete remediation guidance. You optimize for critiques that can be directly executed in a follow-up implementation pass.
</Identity>

<Goal>
Your goal is to produce a high-signal markdown critique that evaluates the current implementation state against the original task, using the provided change ledger and execution output as evidence of what was done, then identifying the most important gaps, risks, and improvement opportunities in priority order with clear next actions. The critique must be specific enough that another implementation pass can apply feedback directly without rediscovering context.

After reading your output, an implementation agent should know exactly what to change next, why those changes matter, and what acceptance criteria indicate the critique has been fully addressed, regardless of domain.
</Goal>

<Input>
You will receive the original task, an attached context report, an implementation change ledger, and execution output from the first pass. Use those inputs to critique implementation quality and output markdown to the target critique file path.
</Input>
EOF

cat > "$call1_prompt_path" <<EOF
$TASK

Use this file for optional attached context: $report_path.
Implement the task now and keep track of all files you updated in $updated_files_path.
Before finishing call 1, overwrite $updated_files_path using one line per file in the format "- path | what changed".
EOF

cat > "$call2_prompt_path" <<EOF
$(cat "$critiquer_system_prompt_path")

Original task:
$TASK

Attached context file: $report_path
Implementation ledger file: $updated_files_path
Implementation output log from call 1: $call1_log_path

Read the task, implementation ledger, and first-pass output log, then produce a markdown critique and write it to $critique_path.
Focus on requirement gaps, quality issues, risk areas, and concrete prioritized next changes.
EOF

cat > "$call3_prompt_path" <<EOF
$TASK

Use this file for optional attached context: $report_path.
Use this implementation ledger as prior-change context: $updated_files_path.
Use this critique feedback as required follow-up work: $critique_path.
Implement the critique feedback now and then overwrite $updated_files_path so it reflects the final post-critique implementation state.
EOF

echo "Run folder: $run_dir"
echo "Task folder: $task_dir"
echo "Report: $report_path"
echo "Updated files ledger: $updated_files_path"
echo "Critique output: $critique_path"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled: codex calls will be skipped."
fi

echo "Call 1/3: implement"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 1 skipped at $(iso_now)." > "$call1_log_path"
  {
    echo "# Updated Files"
    echo
    echo "Task slug: $task_slug"
    echo "Updated: $(iso_now)"
    echo
    echo "Entries:"
    echo "- dry-run/example_file.txt | Placeholder for first implementation pass."
  } > "$updated_files_path"
else
  codex exec --full-auto "$(cat "$call1_prompt_path")" > "$call1_log_path" 2>&1
fi

echo "Call 2/3: critique"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 2 skipped at $(iso_now)." > "$call2_log_path"
  {
    echo "# Critique"
    echo
    echo "- Dry run placeholder critique generated at $(iso_now)."
    echo "- No real implementation was executed."
  } > "$critique_path"
else
  codex exec --full-auto "$(cat "$call2_prompt_path")" > "$call2_log_path" 2>&1
fi

echo "Call 3/3: implement critique feedback"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: call 3 skipped at $(iso_now)." > "$call3_log_path"
  {
    echo "# Updated Files"
    echo
    echo "Task slug: $task_slug"
    echo "Updated: $(iso_now)"
    echo
    echo "Entries:"
    echo "- dry-run/example_file.txt | Placeholder from call 1."
    echo "- dry-run/example_file_2.txt | Placeholder post-critique implementation update."
  } > "$updated_files_path"
else
  codex exec --full-auto "$(cat "$call3_prompt_path")" > "$call3_log_path" 2>&1
fi

echo "Run complete."
echo "Logs:"
echo "- $call1_log_path"
echo "- $call2_log_path"
echo "- $call3_log_path"
