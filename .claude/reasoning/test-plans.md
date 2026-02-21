# Harness Engineering AI Testing Suite Plan

## Goal
Build a robust, security-first, AI-aware testing suite that catches system-breaking failures before merge/release, with explicit protection against state corruption, unsafe automation, data leakage, and orchestration regressions.

## Assumed Harness Components (for targeting tests)
- `POST /api/harness/run` (start task)
- `POST /api/harness/approve` (human gate)
- `GET /api/harness/runs/{id}` (status/artifacts)
- Orchestrator/service layer (prompt assembly, model routing, tool execution, retries)
- Worker/queue layer (async execution, retries, dead-letter)
- Audit/log middleware
- DB writes for runs, steps, approvals, artifacts (use Junk DB at `backend/database/connect.py`)

## Exact Build Steps
1. Define failure budgets and release gates.
2. Freeze a deterministic test baseline (`temperature=0`, fixed seeds, mocked clock, stable fixtures).
3. Create dedicated test envs: `unit`, `integration`, `e2e`, `stress`, each isolated and reproducible.
4. Enforce secret-safe test plumbing (never real keys, synthetic secrets only, log scrubbing enabled).
5. Add hermetic provider mocks for LLM/tool vendors and fault injectors (timeouts, malformed payloads, 5xx, slow streams).
6. Build fixture factories for runs/steps/approvals/artifacts with valid and adversarial variants.
7. Add contract tests for every internal boundary (API schema, orchestrator-tool contracts, queue message schema).
8. Implement critical unit tests first (policy, prompt assembly, state transitions, idempotency, redaction).
9. Implement integration tests for cross-component breakpoints (API->service->DB->queue->worker).
10. Implement adversarial e2e tests (prompt injection, exfiltration attempts, unsafe tool requests, partial-failure rollback).
11. Implement concurrency/race tests (duplicate deliveries, simultaneous approvals, lock contention, replay attacks).
12. Add chaos and stress tests (provider outage/latency spikes, queue lag, DB contention, large payload saturation).
13. Add security regression tests mapped to threat model (authz bypass, tenant isolation, audit tampering, PII leakage).
14. Wire CI gates by risk tier:
15. PR gate: lint + unit critical + integration critical + smoke e2e.
16. Nightly gate: full integration + full e2e + stress/chaos.
17. Release gate: security regressions + rollback drills + disaster recovery checks.
18. Add observability assertions in tests (metrics/log traces validated, not just HTTP codes).
19. Add mutation testing for policy/guardrail modules to ensure tests actually catch logic tampering.
20. Set flake budget and quarantine policy, then continuously harden flaky tests until below threshold.

## Test Plan by Phase

### Phase 1: Unit Tests (Critical Logic and Stateful Operations)

`backend/tests/harness_orchestrator/test_prompt_template_injection_guard.py`
- Scenario: User input attempts prompt-template escape and hidden-system-instruction override.
- Why critical: Could disable safety controls and execute unsafe automation.
- Involved logic: prompt builder/orchestrator guardrail functions.
- Failure manifestation: Model receives unsafe/system-overridden prompt.
- Fixtures/mocks: adversarial prompt fixtures, expected sanitized prompt snapshot.

`backend/tests/harness_orchestrator/test_model_router_policy_bypass.py`
- Scenario: Request attempts to force disallowed model/tool via crafted params.
- Why critical: Security and cost controls bypass.
- Involved logic: routing policy evaluator.
- Failure manifestation: router selects forbidden model/tool.
- Fixtures/mocks: allowed/denied policy matrix fixtures.

`backend/tests/harness_orchestrator/test_tool_call_path_traversal_block.py`
- Scenario: Tool args include path traversal (`../`, absolute paths).
- Why critical: File exfiltration or workspace tampering.
- Involved logic: tool arg validator/sandbox adapter.
- Failure manifestation: unauthorized file access allowed.
- Fixtures/mocks: malicious tool-arg payloads.

`backend/tests/harness_security/test_secret_redaction_on_logs.py`
- Scenario: Model output contains key-like tokens and connection strings.
- Why critical: Credential leakage via logs/telemetry.
- Involved logic: audit/log middleware + redaction utility.
- Failure manifestation: secrets appear in stored logs.
- Fixtures/mocks: synthetic secret corpus.

`backend/tests/harness_state/test_run_state_machine_invalid_transition.py`
- Scenario: Transition `FAILED -> RUNNING` or duplicate `APPROVED`.
- Why critical: Corrupt state and inconsistent downstream behavior.
- Involved logic: run state machine.
- Failure manifestation: illegal transition accepted.
- Fixtures/mocks: state transition table fixture.

`backend/tests/harness_state/test_idempotency_duplicate_run_submission.py`
- Scenario: Same idempotency key submitted concurrently.
- Why critical: duplicate execution and duplicate writes.
- Involved logic: request dedupe + run creation.
- Failure manifestation: >1 run created for same logical request.
- Fixtures/mocks: concurrent request harness, shared key.

`backend/tests/harness_resilience/test_retry_backoff_circuit_breaker.py`
- Scenario: upstream provider continuously fails then recovers.
- Why critical: retry storm, cascading failures, cost explosion.
- Involved logic: retry policy + circuit breaker.
- Failure manifestation: unbounded retries or no recovery.
- Fixtures/mocks: provider failure/recovery simulator.

`backend/tests/harness_policy/test_allow_deny_precedence.py`
- Scenario: conflicting policy rules exist for same action.
- Why critical: authorization ambiguity can allow unsafe execution.
- Involved logic: policy resolution engine.
- Failure manifestation: `allow` wins over explicit `deny`.
- Fixtures/mocks: overlapping policy fixtures.

### Phase 2: Integration Tests (Cross-Component Contract Breakpoints)

`backend/tests/harness_api/test_run_endpoint_authz_rate_limit_integration.py`
- Scenario: unauthenticated/over-limit caller hits `POST /api/harness/run`.
- Why critical: abuse and unauthorized execution risk.
- Involved routes/middleware: auth middleware, rate limiter, run controller.
- Failure manifestation: request accepted when it should be blocked.
- Fixtures/mocks: auth token variants, burst traffic generator.

`backend/tests/harness_integration/test_api_to_orchestrator_to_db_atomicity.py`
- Scenario: DB write fails after orchestration starts.
- Why critical: orphaned worker tasks and unrecoverable partial state.
- Involved flow: controller -> orchestrator -> run repository.
- Failure manifestation: task executes without persisted run record.
- Fixtures/mocks: DB failure injector (Junk DB via `backend/database/connect.py`).

`backend/tests/harness_integration/test_queue_retry_dead_letter_no_duplicate_side_effects.py`
- Scenario: message retries then dead-letters after max attempts.
- Why critical: duplicate side effects and data corruption.
- Involved flow: queue producer/consumer + persistence.
- Failure manifestation: repeated writes/actions across retries.
- Fixtures/mocks: queue emulator, retry counters.

`backend/tests/harness_integration/test_provider_failover_guardrails_preserved.py`
- Scenario: primary model fails; fallback model used.
- Why critical: failover must not disable policy filters.
- Involved flow: model client abstraction + guardrail middleware.
- Failure manifestation: fallback path skips validation/redaction.
- Fixtures/mocks: provider A outage + provider B fallback response.

`backend/tests/harness_integration/test_retrieval_prompt_assembly_tenant_isolation.py`
- Scenario: retrieval returns mixed-tenant context.
- Why critical: cross-tenant data exposure.
- Involved flow: retrieval service + prompt assembly.
- Failure manifestation: wrong-tenant docs in final prompt.
- Fixtures/mocks: multi-tenant fixture dataset.

`backend/tests/harness_integration/test_artifact_writer_atomic_commit_and_rollback.py`
- Scenario: artifact write partially succeeds then fails.
- Why critical: corrupted artifacts and inconsistent run status.
- Involved flow: artifact service + run finalizer.
- Failure manifestation: run marked success with incomplete artifacts.
- Fixtures/mocks: filesystem/object-store partial failure injector.

`backend/tests/harness_integration/test_audit_log_tamper_evidence.py`
- Scenario: modified historical audit entry.
- Why critical: compliance and incident forensics failure.
- Involved flow: audit middleware + integrity checks.
- Failure manifestation: tampering undetected.
- Fixtures/mocks: signed log fixture with intentional modification.

### Phase 3: End-to-End Tests (Real Workflow Safety)

`backend/tests/harness_e2e/test_full_run_happy_path_with_human_approval.py`
- Scenario: complete run from `POST /api/harness/run` to approval to finalized artifacts.
- Why critical: validates core user journey and system wiring.
- Involved routes/services: run/approve/status endpoints, orchestrator, DB, queue.
- Failure manifestation: workflow stalls, status mismatch, missing artifacts.
- Fixtures/mocks: standard request fixture, mocked model/tool outputs.

`backend/tests/harness_e2e/test_prompt_injection_exfiltration_blocked.py`
- Scenario: adversarial prompt requests secrets/file exfiltration.
- Why critical: direct security breach vector in AI-heavy automation.
- Involved flow: input filters, prompt guardrails, tool policy layer.
- Failure manifestation: secret/tool exfiltration succeeds.
- Fixtures/mocks: red-team prompt corpus.

`backend/tests/harness_e2e/test_dependency_outage_graceful_degradation.py`
- Scenario: model provider outage during active run.
- Why critical: must fail safely with clear recoverable state.
- Involved flow: provider client, retry/circuit breaker, run finalizer.
- Failure manifestation: hung run, inconsistent final status.
- Fixtures/mocks: outage injector, recovery timeout config.

`backend/tests/harness_e2e/test_partial_failure_rollback_integrity.py`
- Scenario: one step fails after prior steps wrote state.
- Why critical: prevents persistent inconsistent state.
- Involved flow: orchestrator step transaction boundaries + compensating actions.
- Failure manifestation: stale/contradictory records after rollback.
- Fixtures/mocks: step failure trigger at controlled point.

`backend/tests/harness_e2e/test_replay_attack_idempotency_enforced.py`
- Scenario: attacker replays signed request payload.
- Why critical: duplicate/unauthorized re-execution.
- Involved flow: request signature validation + idempotency store.
- Failure manifestation: replayed request accepted/executed.
- Fixtures/mocks: captured signed request replay fixture.

### Phase 4: Stress/Chaos Tests (Reliability Under Pressure)

`backend/tests/harness_stress/test_high_concurrency_run_submission_race_conditions.py`
- Scenario: burst of concurrent run requests for same project/user.
- Why critical: lock contention, duplicate runs, queue collapse.
- Involved flow: API ingress, idempotency, queue producer, DB transactions.
- Failure manifestation: duplicate runs, deadlocks, high error rate.
- Fixtures/mocks: load generator, contention telemetry hooks.

`backend/tests/harness_stress/test_long_running_worker_memory_growth.py`
- Scenario: sustained processing over long duration.
- Why critical: memory leaks cause worker crashes and retry storms.
- Involved flow: worker execution loop + provider streaming client.
- Failure manifestation: monotonic memory growth beyond threshold.
- Fixtures/mocks: long-sequence workload fixture.

`backend/tests/harness_stress/test_token_budget_exhaustion_safe_failure.py`
- Scenario: oversized prompt/context drives token overrun.
- Why critical: runaway cost and provider hard-fail.
- Involved flow: token estimator + budget guard middleware.
- Failure manifestation: request executes despite budget breach.
- Fixtures/mocks: oversized context fixtures.

`backend/tests/harness_stress/test_provider_latency_spike_backpressure.py`
- Scenario: upstream latency spikes + partial packet loss.
- Why critical: queue backlog and SLA collapse.
- Involved flow: async workers, queue consumer concurrency controls.
- Failure manifestation: no backpressure, uncontrolled queue growth.
- Fixtures/mocks: latency/packet-loss fault injector.

`backend/tests/harness_stress/test_db_contention_and_recovery.py`
- Scenario: lock-heavy DB workload while runs are active.
- Why critical: transaction failures can corrupt state.
- Involved flow: repositories + transaction retry policy (Junk DB at `backend/database/connect.py`).
- Failure manifestation: partial commits, unrecoverable run state.
- Fixtures/mocks: lock contention scenarios, retry telemetry.

## Security Regression Set (Must Always Run in PR Gate)
- Authn/Authz bypass attempts across all harness endpoints.
- Tenant isolation checks in retrieval, artifacts, status APIs.
- Secret leakage checks in logs, traces, and returned artifacts.
- Tool sandbox escape/path traversal checks.
- Audit tamper detection checks.

## CI/CD Gating Strategy
- Tier 0 (every commit): deterministic unit critical set.
- Tier 1 (every PR): Tier 0 + integration critical + security regression set + e2e smoke.
- Tier 2 (nightly): full integration/e2e + stress/chaos + mutation tests on policy modules.
- Tier 3 (pre-release): rollback/disaster drills + full security + performance SLO validation.

## Exit Criteria (Suite Readiness)
- No critical/high findings in security regression set.
- 0 failing tests in Tier 1.
- Flake rate under agreed threshold (example: <1% over 7 days).
- Stress tests meet SLO/error-budget targets.
- All high-risk components mapped to at least one destructive-path test.
