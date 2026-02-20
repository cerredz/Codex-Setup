---
description: Comprehensive monitoring, observability, and alerting standards for maintaining high-reliability systems. Covers SLOs, structured logging, metrics, tracing, and alert strategy.
---

# Monitoring & Observability Standards

This document outlines the core principles for building observable systems. These standards ensure we can detect, debug, and resolve issues proactively rather than reacting to user complaints.

## A. Set the Right Targets (SLOs)

### 1. Start with SLOs, Not Alerts

**Principle:** Define what "healthy" means for the user first.

- **Action:** Establish Service Level Objectives (SLOs) for Availability (e.g., 99.9%), Latency (e.g., p95 < 200ms), and Correctness.
- **Why:** Alerts should fire when these objectives are threatened, not just when a CPU spikes.

### 2. Pick Golden Signals

**Principle:** Monitor the four critical health indicators per service.

- **Signals:**
  1. **Latency:** Time taken to service a request.
  2. **Traffic:** Demand placed on the system (req/sec).
  3. **Errors:** Rate of failed requests (HTTP 5xx, application errors).
  4. **Saturation:** How "full" the service is (CPU, memory, pool depth).

### 3. Measure from User's POV

**Principle:** Internal health doesn't matter if the user can't load the page.

- **Strategy:** Instrument the Frontend/Client in addition to the Backend. A "200 OK" from the API can still be a white screen for the user if the JS crashes.

### 4. Track Tail Latency (p95/p99)

**Principle:** Averages hide problems.

- **Action:** Ignore the "Average" (p50). Optimize for the p95 and p99.
- **Insight:** Slow outliers are often the first sign of resource contention or database locking.

### 5. Define "Correctness" Metrics

**Principle:** "The server is up" doesn't mean "The feature works".

- **Metric examples:** Failed payment count, dropped background jobs, mismatched accounting totals, empty search results.

### 6. Use Error Budgets

**Principle:** 100% reliability is impossible and too expensive.

- **Usage:** An "Error Budget" is the allowed failure rate (e.g., 0.1%).
- **Policy:** If you burn the budget, freeze deployments and focus on reliability. If you have budget left, move faster.

### 7. Instrument Dependencies as First-Class

**Principle:** You are only as fast as your slowest dependency.

- **Action:** Every call to a Database, Cache, Queue, or External API must emit metrics (latency, error rate).

### 8. Align Dashboards to Incident Questions

**Principle:** Dashboards are for answering questions under pressure.

- **Layout:** Organize by: "Is it real?" (Top-level health) -> "Where is it?" (Service/Region breakdown) -> "What changed?" (Deploy markers) -> "Impact?" (Blast radius).

---

## B. Logs That Are Actually Useful

### 9. Structured Logs (JSON)

**Rule:** Strings are for humans; JSON is for machines.

- **Format:** Always output logs in JSON format.
- **Keys:** Ensure consistent keys (`user_id`, not `uid` in one place and `userId` in another).

### 10. Correlation IDs Everywhere

**Rule:** No orphan logs.

- **Implementation:** Every log line must include `trace_id` and `request_id`.
- **Context:** Include `user_id` or `session_id` (if not PII) to trace specific user journeys.

### 11. Log Events, Not Paragraphs

**Rule:** Logs should be discrete events.

- **Bad:** `logger.info("User clicked button and then we checked the db...")`
- **Good:** `logger.info("order_created", user_id=123, order_total=50.00)`

### 12. Standardize Log Levels

**Rule:** Levels have meaning.

- **DEBUG:** Verbose dev details. Safe to sample/drop in prod.
- **INFO:** Key lifecycle events (startup, job finish).
- **WARN:** Unexpected but handled issues (retries, soft limits).
- **ERROR:** Actionable failures requiring attention.

### 13. Never Log Secrets or PII

**Rule:** Logs are not a secure vault.

- **Defense:** Scrub/Redact passwords, API keys, and sensitive PII at the logger middleware level. Use allowlists for safe fields.

### 14. Log Errors with Context

**Rule:** A stack trace isn't enough.

- **Add:** Route name, dependency involved, duration before failure, retry attempt count, input parameters (if safe).

### 15. Capture Exceptions Centrally

**Pattern:** No swallowed errors.

- **Implementation:** Use global middleware or exception handlers to catch, log, and metricize every unhandled exception.

### 16. Use Sampling Intentionally

**Rule:** Signal to Noise ratio matters.

- **Strategy:** Keep 100% of ERROR logs. Sample INFO/DEBUG logs (e.g., 10%) for high-volume routes to save cost while maintaining visibility.

### 17. Add "Why" Fields

**Rule:** Explain the logic.

- **Example:** Instead of just "Request Rejected", log `{ "event": "request_rejected", "reason": "rate_limit_exceeded", "limit": 100 }`.

### 18. Keep Logs Actionable

**Rule:** If you don't use it, delete it.

- **Test:** During an incident, if a log doesn't help you find the constraint or root cause, it is noise.

---

## C. Metrics That Catch Problems Early

### 19. Consistent Metric Naming

**Rule:** Predictable namespace.

- **Schema:** `service.component.measure_unit`.
- **Examples:** `api.http_request.duration_ms`, `db.postgres.query.duration_ms`.

### 20. Prefer Histograms for Latency

**Rule:** You need percentiles.

- **Type:** Use Histograms (buckets) for timing data so you can calculate p50, p95, and p99 dynamically.

### 21. Use Tags/Labels Carefully

**Rule:** Watch Cardinality.

- **Warning:** Do NOT include high-cardinality data like `user_id` or `request_id` as metric tags. This will crash the metrics DB. Use `status_code`, `region`, `endpoint_group` instead.

### 22. Measure Success as a Rate

**Rule:** Counts are contextless.

- **Metric:** Track `success_rate = successful_requests / total_requests`.

### 23. Separate 4xx vs 5xx

**Rule:** Client errors != Server errors.

- **Breakdown:** Track top 4xx causes independently (Validation vs Auth vs Rate Limit). 5xx errors are almost always an internal pageable offense.

### 24. Track Saturation

**Rule:** Know your limits.

- **Metrics:** CPU %, Memory usage, Disk I/O, Connection Pool utilization, Queue depth, Event loop lag.

### 25. Track Dependency Health

**Rule:** Watch your downstream.

- **Metrics:** External API timeout rates, retry rates, and Circuit Breaker state changes (Open/Closed).

### 26. Track "Work Outcomes"

**Rule:** Business value metrics.

- **Examples:** "Emails sent", "Jobs processed successfully", "Webhooks delivered". A silent system might mean 0 errors but 0 work being done.

### 27. Track Data Integrity Signals

**Rule:** Catch corruption.

- **Signals:** Duplicate events detected, Out-of-order event counts, Missing records found during reconciliation.

### 28. Track Release Markers

**Rule:** Correlate code to chaos.

- **Practice:** Send a marker annotation to the metrics system on every deploy. "Error rate spiked right after v2.1.0 deploy".

---

## D. Tracing for Fast Root Cause

### 29. Distributed Tracing End-to-End

**Goal:** Full visibility.

- **Scope:** Trace from Client (Frontend) -> Load Balancer -> API -> Internal Services -> Database.

### 30. Propagate Context Everywhere

**Rule:** Do not break the chain.

- **Implementation:** Pass trace headers (`traceparent`, `b3`) through HTTP headers, async job payloads, and queue messages.

### 31. Use Spans for Each Dependency

**Rule:** Granular timing.

- **Detail:** Every DB query, Redis command, and external HTTP call gets its own child span with precise start/end times.

### 32. Tag Spans with Attributes

**Rule:** Searchable contexts.

- **Tags:** HTTP route, Status code, SQL query type (e.g., `SELECT`, `INSERT`), Dependency name.

### 33. Record Errors on Spans

**Rule:** Visible failures.

- **Action:** Attach exception types and safe error messages directly to the span.

### 34. Trace Sampling Strategy

**Rule:** Economics of tracing.

- **Strategy:** Head-based sampling creates gaps. Use tail-based sampling if possible (keep 100% of traces with errors or high latency).

### 35. Add "Business Spans"

**Rule:** Trace logic, not just IO.

- **Example:** Create spans for major logical blocks: `checkout.calculate_tax`, `report.generate_pdf`.

### 36. Link Logs ↔ Traces

**Rule:** Unified observability.

- **Integration:** Ensure your logging platform can deep-link to your tracing platform using the `trace_id` present in the log.

---

## E. Alerting That Doesn't Burn You Out

### 37. Alert on Symptoms, Not Causes

**Principle:** User pain is the trigger.

- **Rule:** Page if "Error Rate > 1%" or "Latency p95 > 2s". Do NOT page on "CPU > 80%" (unless it causes the former).

### 38. Multi-Window Burn Rates

**Principle:** Catch fast spikes and slow leaks.

- **Config:** Alert if error rate is high for 5 minutes (Spike). ALSO Alert if error rate is slightly elevated for 1 hour (Burn).

### 39. Page on SLO Threats Only

**Principle:** Protect sleep.

- **Action:** Page (Wake up) for SLO violations. Ticket (Jira/Email) for warnings or non-critical anomalies.

### 40. Define Severity Ladder

**Structure:**

- **SEV1:** Critical user impact (System Down). Page immediately 24/7.
- **SEV2:** Major impact / degradation. Page immediately.
- **SEV3:** Minor issue / internal error. Ticket for next business day.

### 41. Deduplicate Alerts

**Rule:** One incident = One page.

- **Grouping:** Group alerts by Service, Region, or Environment to prevent a storm of 100 notifications for one DB outage.

### 42. Alert Runbook Links

**Rule:** Don't make me guess at 3 AM.

- **Requirement:** Every alert description MUST include a link to a Runbook or Dashboard with triage steps.

### 43. Include Context in Alerts

**Rule:** Information radiator.

- **Payload:** Current value (e.g., "500 errors/sec"), Threshold ("10 errors/sec"), Top impacted endpoints, Link to recent deploys.

### 44. Dynamic thresholds

**Rule:** Context aware baselines.

- **Strategy:** Use relative alerts ("Traffic dropped 50% week-over-week") instead of static guesses where appropriate.

### 45. Rate-Limit Notifications

**Rule:** Prevent fatigue.

- **Config:** Throttle notifications. If a check fails every minute, notify once and then silence for X minutes or until resolution.

### 46. Continuously Prune

**Rule:** No zombie alerts.

- **Process:** If an alert fires and no action is taken (or it was a false positive), delete it or tune it immediately.

---

## F. Detection Beyond "Service is Down"

### 47. Canaries / Synthetic Checks

**Pattern:** Simulated users.

- **Implementation:** Run a script every minute that logs in, searches for an item, and adds to cart.
- **Value:** Fails _before_ real users complain if a specific flow breaks.

### 48. Anomaly Detection on Key Rates

**Pattern:** Statistical deviation.

- **Monitors:** Sudden spike in retry rates, queue depth growing linearly (leak), or memory usage sawtooth pattern.

### 49. Change Detection

**Pattern:** What just happened?

- **Correlation:** Overlay incidents with Deploys, Feature Flag toggles, Config updates, and Schema migrations.

### 50. Close the Loop with Postmortems

**Pattern:** Learn from failure.

- **Rule:** Every Sev1/Sev2 incident MUST result in a new monitor, alert, or test case to prevent that specific failure mode from happening silently again.
