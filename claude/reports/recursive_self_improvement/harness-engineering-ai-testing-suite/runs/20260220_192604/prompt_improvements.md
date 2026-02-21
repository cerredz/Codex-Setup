# Prompt Improvements

## Prompt Version 1

You are a senior software engineer and QA architect. I need to design a comprehensive testing suite for a project that makes heavy use of AI automation. Help me:

1. Decompose the exact steps required to build a robust testing suite for an AI-assisted codebase.
2. Identify what categories of tests are needed beyond a standard suite (unit, integration, e2e).
3. Explain how to test AI-generated code and AI-driven automation pipelines.
4. Outline how to ensure nothing breaks when AI modifies or generates code.

Focus on harness engineering — the scaffolding, fixtures, runners, and automation infrastructure that makes testing reliable at scale.

### Fidelity Check
- Original intent: comprehensive testing suite for AI-heavy projects in the harness engineering domain.
- Covers: decomposing steps, going beyond regular test suites, AI-specific concerns.
- No scope drift: stays within testing infrastructure and AI validation.

---

## Prompt Version 2

You are a principal QA architect specializing in AI-integrated software systems. I need a step-by-step blueprint for building a **comprehensive, robust, and secure** testing suite for a codebase where AI is heavily used to automate tasks. The suite must go far beyond standard testing practices.

Produce a structured plan covering:

1. **Test harness architecture** — directory layout, runner configuration, fixture management, and CI/CD integration.
2. **AI-specific test categories** — prompt regression testing, output determinism/non-determinism handling, model behavior contracts, and AI output validation.
3. **Security testing layer** — prompt injection detection, data leakage prevention, sandboxed AI execution, and adversarial input testing.
4. **Codebase integrity guardrails** — pre/post AI-edit diff validation, static analysis hooks, type-checking enforcement, and rollback triggers.
5. **Observability and traceability** — logging AI decisions, capturing prompt/response pairs, and audit trails for AI-generated changes.

For each category, list concrete tools, file structures, and example test patterns.

### Fidelity Check
- Original intent: comprehensive, robust, secure testing suite for AI-heavy harness engineering.
- Adds structure to the "decompose exact steps" requirement with 5 explicit categories.
- Security layer directly addresses "robust and secure" from the original.
- AI-specific categories address "far more extensive than regular" testing.
- No scope drift: purely testing infrastructure and AI validation.

---

## Prompt Version 3

You are a principal QA architect and AI systems engineer. My codebase relies heavily on AI automation — AI writes code, runs scripts, and modifies files. I need a **comprehensive, step-by-step blueprint** for building a testing suite that is significantly more extensive and secure than a standard software test suite, purpose-built for AI-driven workflows.

Structure your response as an actionable implementation guide with these sections:

### Section 1: Test Harness Architecture
- Recommended directory layout for an AI-aware test suite.
- Runner configuration (e.g., pytest, Jest, or a custom harness).
- Fixture and mock strategies for AI outputs.
- CI/CD integration points and gate criteria.

### Section 2: AI Output Validation
- Prompt regression tests: how to detect when a prompt change breaks expected behavior.
- Determinism controls: handling non-deterministic AI outputs reliably in tests.
- Schema/contract testing for AI-generated artifacts (code, JSON, markdown).
- Golden file comparisons and snapshot testing for AI outputs.

### Section 3: Codebase Integrity Guardrails
- Pre/post AI-edit diff validation workflows.
- Static analysis, linting, and type-checking as mandatory gates.
- Test coverage enforcement after AI-generated code is merged.
- Rollback and revert triggers when validation fails.

### Section 4: Security Testing Layer
- Prompt injection and jailbreak detection tests.
- Data leakage and PII exposure checks for AI inputs/outputs.
- Sandboxed execution environments for AI-generated code.
- Adversarial and fuzzing tests for AI pipelines.

### Section 5: Observability and Audit
- Structured logging of prompt/response pairs.
- Decision tracing for AI-driven automation steps.
- Audit trail schema for all AI-generated changes.
- Alerting on anomalous AI behavior patterns.

For each section: list specific tools, provide a sample file structure or test pattern, and identify the key risk each addresses.

### Fidelity Check
- Original intent: comprehensive, robust, secure testing for AI-heavy harness engineering.
- Fully preserves "decompose exact steps" — each section is a concrete, ordered implementation step.
- Adds specificity to Version 2 by requiring tools, file structures, and risk identification per section.
- "Far more extensive than regular" addressed by Sections 2–5 which have no equivalent in standard suites.
- Security emphasis preserved and expanded.
- No scope drift: everything is about testing infrastructure and AI validation.

---

## Prompt Version 4

You are a principal QA architect and AI systems security engineer. I am building a production-grade codebase where AI is the primary automation engine — it writes code, edits files, runs scripts, and orchestrates workflows. I need a **complete, step-by-step implementation blueprint** for a testing suite that is substantially more extensive and secure than a conventional software test suite, designed specifically for the risks and failure modes unique to AI-driven systems.

Treat this as a formal engineering specification. For every section, you must provide:
- **Why** this layer exists (the specific AI risk it addresses).
- **What** to implement (concrete test types, tools, configuration).
- **How** to implement it (sample code, directory layout, or configuration snippet).
- **Pass/fail criteria** (what determines this gate is healthy).

---

### Section 1: Test Harness Architecture & CI/CD Integration
- Directory layout for an AI-aware test suite (separate dirs for unit, integration, AI-contract, security, golden-files).
- Runner selection rationale and configuration for AI-heavy workflows.
- CI/CD pipeline gates: which tests must pass before AI-generated changes can merge.
- Fixture and mock strategies: how to mock AI model calls deterministically for fast tests.

### Section 2: AI Output Contract & Regression Testing
- Prompt contract tests: lock expected behavior for each prompt template; fail if behavior drifts.
- Golden file / snapshot tests for AI-generated artifacts (code, JSON, reports).
- Schema validation for structured AI outputs.
- Non-determinism handling: statistical sampling strategy to catch flaky AI behavior over N runs.

### Section 3: Codebase Integrity Guardrails
- Pre-merge diff validation: automated check that AI edits stay within declared scope.
- Static analysis, linting, and strict type-checking as mandatory CI gates.
- Coverage enforcement: AI-generated code must meet or exceed baseline coverage threshold.
- Rollback protocol: automated revert procedure when any gate fails post-merge.

### Section 4: Security & Adversarial Testing Layer
- Prompt injection and jailbreak test cases: a catalog of adversarial inputs run against every AI endpoint.
- PII and data leakage scanning on all AI inputs and outputs.
- Sandboxed execution: policy for running AI-generated code in isolated environments before promotion.
- Supply-chain checks: verify AI-generated dependency additions against a security policy.
- Adversarial fuzzing strategy for AI pipelines.

### Section 5: Observability, Traceability & Audit
- Structured log schema for every prompt/response pair (fields, retention, indexing).
- Decision trace format for multi-step AI automation runs.
- Immutable audit trail for all AI-generated changes (what changed, which model, which prompt, which run).
- Anomaly detection: thresholds and alerts for unexpected AI output patterns.

### Section 6: Maintenance & Evolution Protocol
- How to update prompt contracts when intentional behavior changes are made.
- Versioning strategy for prompt templates and their associated test suites.
- Runbook for investigating and triaging AI-introduced regressions.
- Metrics and KPIs to track the health of the AI testing suite over time.

Provide a **prioritized implementation order** at the end: which sections to build first given limited time, and why.

### Fidelity Check
- Original intent: comprehensive, robust, secure testing suite for AI-heavy harness engineering.
- Fully preserves all original goals: decompose steps, extensive beyond normal, AI-specific, nothing breaks.
- Version 4 vs Version 3 improvements: adds "Why/What/How/Pass-fail" requirement per section (forces actionable specificity), adds Section 6 (maintenance/evolution — critical for long-running AI projects), adds supply-chain security, adds prioritized implementation order.
- Security emphasis significantly strengthened.
- No scope drift: entirely within testing infrastructure, AI validation, and harness engineering.

---

## Final Selected Prompt

<<<FINAL_PROMPT_START>>>
You are a principal QA architect and AI systems security engineer. I am building a production-grade codebase where AI is the primary automation engine — it writes code, edits files, runs scripts, and orchestrates workflows. I need a **complete, step-by-step implementation blueprint** for a testing suite that is substantially more extensive and secure than a conventional software test suite, designed specifically for the risks and failure modes unique to AI-driven systems.

Treat this as a formal engineering specification. For every section, you must provide:
- **Why** this layer exists (the specific AI risk it addresses).
- **What** to implement (concrete test types, tools, configuration).
- **How** to implement it (sample code, directory layout, or configuration snippet).
- **Pass/fail criteria** (what determines this gate is healthy).

---

### Section 1: Test Harness Architecture & CI/CD Integration
- Directory layout for an AI-aware test suite (separate dirs for unit, integration, AI-contract, security, golden-files).
- Runner selection rationale and configuration for AI-heavy workflows.
- CI/CD pipeline gates: which tests must pass before AI-generated changes can merge.
- Fixture and mock strategies: how to mock AI model calls deterministically for fast tests.

### Section 2: AI Output Contract & Regression Testing
- Prompt contract tests: lock expected behavior for each prompt template; fail if behavior drifts.
- Golden file / snapshot tests for AI-generated artifacts (code, JSON, reports).
- Schema validation for structured AI outputs.
- Non-determinism handling: statistical sampling strategy to catch flaky AI behavior over N runs.

### Section 3: Codebase Integrity Guardrails
- Pre-merge diff validation: automated check that AI edits stay within declared scope.
- Static analysis, linting, and strict type-checking as mandatory CI gates.
- Coverage enforcement: AI-generated code must meet or exceed baseline coverage threshold.
- Rollback protocol: automated revert procedure when any gate fails post-merge.

### Section 4: Security & Adversarial Testing Layer
- Prompt injection and jailbreak test cases: a catalog of adversarial inputs run against every AI endpoint.
- PII and data leakage scanning on all AI inputs and outputs.
- Sandboxed execution: policy for running AI-generated code in isolated environments before promotion.
- Supply-chain checks: verify AI-generated dependency additions against a security policy.
- Adversarial fuzzing strategy for AI pipelines.

### Section 5: Observability, Traceability & Audit
- Structured log schema for every prompt/response pair (fields, retention, indexing).
- Decision trace format for multi-step AI automation runs.
- Immutable audit trail for all AI-generated changes (what changed, which model, which prompt, which run).
- Anomaly detection: thresholds and alerts for unexpected AI output patterns.

### Section 6: Maintenance & Evolution Protocol
- How to update prompt contracts when intentional behavior changes are made.
- Versioning strategy for prompt templates and their associated test suites.
- Runbook for investigating and triaging AI-introduced regressions.
- Metrics and KPIs to track the health of the AI testing suite over time.

Provide a **prioritized implementation order** at the end: which sections to build first given limited time, and why.
<<<FINAL_PROMPT_END>>>

## Selection Rationale

Version 4 was selected as the final prompt for the following reasons:

1. **Actionable specificity**: The Why/What/How/Pass-fail requirement per section forces the responding agent to produce concrete, implementable output rather than abstract advice. This directly addresses "decompose the exact steps."

2. **Most comprehensive coverage**: It is the only version that includes Section 6 (Maintenance & Evolution), which is critical for AI-heavy projects where prompts and models evolve continuously.

3. **Strongest security posture**: Adds supply-chain checks for AI-generated dependency additions — a real attack surface that earlier versions omitted.

4. **Prioritized implementation order**: Forces the response to be practical by acknowledging limited resources and sequencing the work.

5. **Fidelity to original**: Preserves every element of the original task (comprehensive, robust, secure, AI-specific, harness engineering, far beyond standard suites) while adding structure that makes the response more useful, not different in goal.
