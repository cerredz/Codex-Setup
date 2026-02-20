Generates executable Bash wrapper scripts that orchestrate multi-step, sequential codex exec pipelines across any domain. Invoke this skill any time a user wants to automate a multi-stage task, chain LLM calls, or build a hands-free workflow.Goal
Generate production-ready, executable Bash scripts that orchestrate multiple isolated codex exec calls into a fully automated pipeline. This is the standard approach for any complex, multi-stage task — not a niche trick. Whether the task is software development, data engineering, content creation, system administration, or research, the same underlying pattern applies. Generated scripts are to be put inside of the .claude/scripts folder (create this folder if it does not exist).

The user should be able to run a single command and walk away while the entire workflow completes unattended.

Core Design Principles
Why Not One Big Prompt?
A single prompt that asks for multiple things is fragile. The model may skip steps, conflate stages, or run out of context. Separating concerns into discrete codex exec calls means:

Each agent has a single, focused responsibility
Context is clean and bounded per stage
Failures are isolated and debuggable — you know exactly which stage broke
Stages can be rerun independently without restarting the whole pipeline

The File-Based Handoff Pattern
Never rely on conversational memory between codex exec calls — there is none. Instead, use the filesystem as the communication channel between stages.
Each stage reads its input from a file, does its work, writes its output to a file, and cleans up what it no longer needs. This makes the pipeline stateless, reproducible, and easy to inspect mid-run.
The Universal Three-Stage Architecture
Every pipeline you generate must map to this structure, regardless of domain:
┌──────────────────┐     .handoff file      ┌──────────────────┐     final artifact     ┌──────────────────┐
│  Stage 1         │ ──────────────────────▶ │  Stage 2         │ ──────────────────────▶ │  Stage 3         │
│  GATHER          │                         │  EXECUTE         │                         │  VALIDATE        │
│  Explore / Plan  │                         │  Implement /     │                         │  Audit / Review  │
│                  │                         │  Transform       │                         │  (read-only)     │
└──────────────────┘                         └──────────────────┘                         └──────────────────┘

Stage 1 — Gather: Reads the initial state, gathers context, and writes a structured plan or data summary to a .handoff file. Does not implement anything.
Stage 2 — Execute: Reads the handoff, performs the core work (writing code, transforming data, drafting content, etc.), and produces the final artifact. Deletes the handoff file on success.
Stage 3 — Validate: Reviews the artifact against the original goal. Reports findings to the terminal. Cannot modify anything.

Some tasks warrant a 4-stage pipeline (e.g., Gather → Plan → Implement → Audit). Use judgment. Never collapse stages to save lines — isolation is the point.

Required Flags
Always apply these flags correctly. They are not optional.
FlagStagePurpose--full-autoStage 2 (Executor)Bypasses interactive Y/N file-write prompts so the script runs unattended--sandbox read-onlyStage 3 (Validator)Enforces OS-level read-only access — the agent physically cannot write files
Omitting --full-auto from Stage 2 will cause the script to hang waiting for user input. Omitting --sandbox read-only from Stage 3 risks the auditor making unintended changes.

Script Template
Use this as the base structure for every generated pipeline:
bash#!/bin/bash

# ─── Input ───────────────────────────────────────────────────────────────────
TASK="$1"

if [ -z "$TASK" ]; then
  echo "Usage: ./pipeline.sh \"<your task description>\""
  exit 1
fi

echo ""
echo "🚀 Starting pipeline for: $TASK"
echo "────────────────────────────────────────"

# ─── Stage 1: Gather ──────────────────────────────────────────────────────────
echo ""
echo "🔍 Stage 1: Gathering context..."
codex exec "You are a planner. [Stage 1 instructions]. Write your findings to '.codex_handoff.md'. Do not implement anything yet."

# ─── Stage 2: Execute ─────────────────────────────────────────────────────────
echo ""
echo "⚙️  Stage 2: Executing..."
codex exec --full-auto "You are an expert [role]. Read '.codex_handoff.md'. [Stage 2 instructions]. Delete '.codex_handoff.md' when done."

# ─── Stage 3: Validate ────────────────────────────────────────────────────────
echo ""
echo "🧐 Stage 3: Validating..."
codex exec --sandbox read-only "You are a strict [auditor/reviewer]. [Stage 3 instructions]. Output your findings to the terminal. Do not modify any files."

echo ""
echo "✅ Pipeline complete."

Workflow: How to Generate a Pipeline
When a user asks for a pipeline or automation script, follow these steps:

Identify the domain — Is this a coding task? Data task? Content task? Ops task?
Map to the three stages — What does Gather, Execute, and Validate mean in this specific context?
Name the handoff files descriptively — .codex_handoff.md is fine for simple cases; use .etl_plan.md, .refactor_plan.md, etc. when it aids clarity.
Write role-specific prompts — Each codex exec prompt should include a role ("You are a strict security auditor...") and a single clear responsibility.
Output the complete script — Include the shebang, input validation, echo statements, and a usage example.
Provide the chmod command — Always remind the user to run chmod +x pipeline.sh before executing.


Examples & Scenarios
The following examples are intentionally drawn from different domains to demonstrate that this pattern is universal. The structure is identical in every case — only the prompts and file names change.

Scenario 1: Codebase Feature Implementation (Software Engineering)
User Request: "I want a script where I give it a feature description, it explores my codebase, implements the feature, then audits what it wrote."
Stage Mapping: Explore codebase → Write code → Audit for bugs/security issues
bash#!/bin/bash

FEATURE="$1"

if [ -z "$FEATURE" ]; then
  echo "Usage: ./implement_feature.sh \"<feature description>\""
  exit 1
fi

echo ""
echo "🚀 Starting feature pipeline for: $FEATURE"
echo "────────────────────────────────────────"

echo ""
echo "🔍 Stage 1: Exploring codebase..."
codex exec "You are a senior software architect. Explore the codebase to understand its structure, conventions, and relevant modules for implementing: '$FEATURE'. Do NOT write any code. Write a detailed implementation plan — including which files to create or modify — to '.feature_plan.md'."

echo ""
echo "⚙️  Stage 2: Implementing feature..."
codex exec --full-auto "You are an expert developer. Read '.feature_plan.md'. Implement the feature: '$FEATURE' exactly as planned. Follow existing code conventions. Delete '.feature_plan.md' when the implementation is complete."

echo ""
echo "🧐 Stage 3: Auditing implementation..."
codex exec --sandbox read-only "You are a strict code reviewer. Audit the changes just made for the feature: '$FEATURE'. Look for unhandled edge cases, missing tests, security vulnerabilities, and deviations from the plan. Write a detailed markdown report to the terminal."

echo ""
echo "✅ Feature pipeline complete."
Usage:
bashchmod +x implement_feature.sh
./implement_feature.sh "Add rate limiting to the /api/login endpoint"

Scenario 2: Data Cleaning & Reporting (Data Engineering / ETL)
User Request: "I have messy CSV exports from our CRM. I want a script that analyzes the file, cleans it up, and gives me a validation report."
Stage Mapping: Analyze schema/anomalies → Transform and write clean output → Validate output integrity
bash#!/bin/bash

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
  echo "Usage: ./clean_data.sh \"<path/to/input.csv>\""
  exit 1
fi

echo ""
echo "🚀 Starting data pipeline for: $INPUT_FILE"
echo "────────────────────────────────────────"

echo ""
echo "📊 Stage 1: Analyzing data structure..."
codex exec "You are a data analyst. Open and inspect '$INPUT_FILE'. Identify all structural issues: malformed rows, inconsistent column names, missing values, incorrect data types, duplicate records. Write a detailed cleaning plan to '.etl_plan.md'. Do not modify the source file."

echo ""
echo "⚙️  Stage 2: Cleaning and transforming..."
codex exec --full-auto "You are a data engineer. Read '.etl_plan.md' and '$INPUT_FILE'. Apply all transformations from the plan and output the cleaned data to 'output_clean.csv'. Then delete '.etl_plan.md'."

echo ""
echo "✅ Stage 3: Validating output..."
codex exec --sandbox read-only "You are a data quality auditor. Compare 'output_clean.csv' against '$INPUT_FILE'. Verify row counts, confirm no unintended data was dropped, and check that all originally identified issues were resolved. Output a summary report to the terminal."

echo ""
echo "✅ Data pipeline complete."
Usage:
bashchmod +x clean_data.sh
./clean_data.sh "exports/crm_contacts_march.csv"

Scenario 3: Automated Test-Failure Repair (QA / CI)
User Request: "My test suite is failing. I want a script that runs the tests, reads the errors, fixes the code, then re-runs to confirm."
Stage Mapping: Run tests and capture output → Fix failing code → Re-run tests to confirm (read-only verdict)
bash#!/bin/bash

TEST_DIR="${1:-.}"  # Default to current directory if not specified

echo ""
echo "🚀 Starting test repair pipeline in: $TEST_DIR"
echo "────────────────────────────────────────"

echo ""
echo "🧪 Stage 1: Running test suite..."
# Capture both stdout and stderr; allow non-zero exit without halting the script
pytest "$TEST_DIR" > .test_results.log 2>&1 || true
echo "Test run complete. Results saved to .test_results.log"

echo ""
echo "🛠️  Stage 2: Repairing failing tests..."
codex exec --full-auto "You are an expert developer. Read '.test_results.log'. Identify every failing test and trace each failure back to its root cause in the source code under '$TEST_DIR'. Fix the source code — do not modify the test files. Delete '.test_results.log' when done."

echo ""
echo "✅ Stage 3: Confirming repairs..."
codex exec --sandbox read-only "Run pytest '$TEST_DIR' and report the results to the terminal. Confirm how many tests now pass versus fail. Do not attempt to fix any remaining failures — only report them."

echo ""
echo "✅ Test repair pipeline complete."
Usage:
bashchmod +x fix_tests.sh
./fix_tests.sh "src/tests"

Scenario 4: Technical Documentation Generation (Content / DevRel)
User Request: "I want a script that takes a module path, reads the source code, and writes a full markdown documentation page for it."
Stage Mapping: Read and outline the module's API → Write formatted documentation → Proofread for accuracy and completeness
bash#!/bin/bash

MODULE_PATH="$1"

if [ -z "$MODULE_PATH" ]; then
  echo "Usage: ./document_module.sh \"<path/to/module>\""
  exit 1
fi

echo ""
echo "🚀 Starting documentation pipeline for: $MODULE_PATH"
echo "────────────────────────────────────────"

echo ""
echo "🔍 Stage 1: Reading and outlining module..."
codex exec "You are a technical writer. Read all source files in '$MODULE_PATH'. Extract every public function, class, method, and parameter. Write a structured outline of the full public API to '.doc_outline.md'. Do not write the final documentation yet."

echo ""
echo "✍️  Stage 2: Writing documentation..."
codex exec --full-auto "You are an expert technical writer. Read '.doc_outline.md'. Write a comprehensive, developer-facing markdown documentation page and save it to 'docs/${MODULE_PATH//\//_}.md'. Include usage examples for every major function. Delete '.doc_outline.md' when done."

echo ""
echo "🧐 Stage 3: Proofreading..."
codex exec --sandbox read-only "You are a documentation reviewer. Read 'docs/${MODULE_PATH//\//_}.md'. Check for missing parameters, inaccurate descriptions, broken formatting, and unclear examples. Output a specific, actionable review to the terminal."

echo ""
echo "✅ Documentation pipeline complete."
Usage:
bashchmod +x document_module.sh
./document_module.sh "src/auth"

Scenario 5: Security Log Incident Response (DevOps / SysAdmin)
User Request: "I want to feed in a server error log and have it diagnose the incident, write a remediation script, and then review the script for safety before I run it."
Stage Mapping: Diagnose root cause → Write remediation script → Security review before execution
bash#!/bin/bash

LOG_FILE="$1"

if [ -z "$LOG_FILE" ]; then
  echo "Usage: ./incident_response.sh \"<path/to/server.log>\""
  exit 1
fi

echo ""
echo "🚀 Starting incident response pipeline for: $LOG_FILE"
echo "────────────────────────────────────────"

echo ""
echo "🚨 Stage 1: Diagnosing incident..."
codex exec "You are a senior site reliability engineer. Analyze all error stack traces, patterns, and timestamps in '$LOG_FILE'. Identify the most likely root cause. Write a structured incident report and a step-by-step remediation plan to '.incident_plan.md'."

echo ""
echo "🛠️  Stage 2: Writing remediation script..."
codex exec --full-auto "You are a DevOps engineer. Read '.incident_plan.md'. Write a bash script named 'apply_patch.sh' that executes the full remediation plan. Make it idempotent where possible. Add inline comments explaining each command. Make the file executable. Delete '.incident_plan.md' when done."

echo ""
echo "🛡️  Stage 3: Security review..."
codex exec --sandbox read-only "You are a security engineer. Review 'apply_patch.sh' line by line. Flag any commands that are destructive, irreversible, or potentially dangerous. Confirm the script is safe to run — or list the exact lines that must be reviewed by a human before execution. Output to the terminal only."

echo ""
echo "⚠️  Review Stage 3 output carefully before running apply_patch.sh"
echo "✅ Incident response pipeline complete."
Usage:
bashchmod +x incident_response.sh
./incident_response.sh "logs/server_error_2024-06-01.log"

Scenario 6: Dependency Migration (Refactoring / Modernization)
User Request: "I want to migrate a codebase from one library to another. Script it so it maps the old API first, then does the migration, then checks for anything it missed."
Stage Mapping: Map old API usage across codebase → Rewrite all usages to new API → Scan for any remaining references
bash#!/bin/bash

OLD_LIB="$1"
NEW_LIB="$2"

if [ -z "$OLD_LIB" ] || [ -z "$NEW_LIB" ]; then
  echo "Usage: ./migrate_library.sh \"<old-library>\" \"<new-library>\""
  exit 1
fi

echo ""
echo "🚀 Starting migration pipeline: $OLD_LIB → $NEW_LIB"
echo "────────────────────────────────────────"

echo ""
echo "🔍 Stage 1: Mapping all usages of $OLD_LIB..."
codex exec "You are a codebase analyst. Search the entire codebase for every import, usage, and pattern related to '$OLD_LIB'. For each usage, identify the equivalent in '$NEW_LIB'. Write a complete migration mapping to '.migration_plan.md'. Do not change any files."

echo ""
echo "⚙️  Stage 2: Performing migration..."
codex exec --full-auto "You are a refactoring expert. Read '.migration_plan.md'. Systematically replace every instance of '$OLD_LIB' with the '$NEW_LIB' equivalent across the codebase, following the mapping exactly. Delete '.migration_plan.md' when every substitution is complete."

echo ""
echo "🧐 Stage 3: Scanning for stragglers..."
codex exec --sandbox read-only "You are a code auditor. Search the entire codebase for any remaining references to '$OLD_LIB' — imports, comments, configuration files, and documentation. Report every occurrence to the terminal with the file path and line number."

echo ""
echo "✅ Migration pipeline complete."
Usage:
bashchmod +x migrate_library.sh
./migrate_library.sh "moment.js" "date-fns"
./migrate_library.sh "axios" "native fetch API"
./migrate_library.sh "CommonJS require()" "ES Module import"

Anti-Patterns to Avoid
Do not use a single codex exec for a multi-stage task. The model will conflate stages or lose track of constraints mid-response.
Do not pass context between stages via command-line arguments. Large context (plans, data, code) must go through files. Arguments are for short identifiers only ($1).
Do not skip the Validate stage to save time. The validator is cheap to run and has caught real issues in every domain scenario above. Always include it.
Do not use --full-auto on the Validator. This defeats the purpose of the safety check entirely.
Do not delete handoff files in Stage 1. They exist to survive into Stage 2. Only the Executor (Stage 2) cleans up handoff files.Share