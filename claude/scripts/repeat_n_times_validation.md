# repeat_n_times.sh Validation

This document defines a minimal, repeatable validation flow for `claude/scripts/repeat_n_times.sh`.

## Prerequisites

- Bash shell available (`bash --version`)
- `codex` CLI is optional when running dry-run checks

## Fast Smoke Test

Run the bundled smoke test harness:

```bash
bash claude/scripts/repeat_n_times_smoke_test.sh
```

What it checks:

- New dry-run execution creates run files and logs all iterations.
- Resume on a completed run no-ops cleanly.
- Resume rejects incompatible task arguments.
- Resume rejects output-shaping options (`--output-root`, `--max-tree-files`) that do not apply to existing runs.
- Missing option value handling returns a validation error.
- Resume from partial progress continues from the next missing iteration.
- Resume guard rejects `--iterations` lower than last logged iteration.
- Resume with explicit `--iterations` updates progress metadata for future resume runs.

## Manual Command Matrix

Run these manually in a Bash-capable environment when you want explicit command-level verification.

```bash
# New run, dry mode
bash claude/scripts/repeat_n_times.sh --task "manual check" --iterations 2 --dry-run

# Resume same run directory (replace RUN_DIR)
bash claude/scripts/repeat_n_times.sh --resume "RUN_DIR" --dry-run

# Resume with an explicit higher iteration target
bash claude/scripts/repeat_n_times.sh --resume "RUN_DIR" --iterations 4 --dry-run

# Expected validation failure
bash claude/scripts/repeat_n_times.sh --resume "RUN_DIR" --task "should fail" --dry-run

# Expected validation failure (resume-only option guard)
bash claude/scripts/repeat_n_times.sh --resume "RUN_DIR" --output-root "tmp/reports" --dry-run
```

Expected outcomes:

- First command prints run paths and appends `[1]` and `[2]` dry-run log entries in `progress.txt`.
- Second command prints `No remaining iterations to run.` when all iterations are complete.
- Third command updates `- Target iterations:` and logs dry-run entries up to the requested iteration.
- Fourth command exits non-zero with a resume/task argument validation message.
- Fifth command exits non-zero with an option-compatibility validation message for resume mode.
