---
description: Comprehensive reliability and infrastructure standards for backend services, covering API design, FastAPI patterns, middleware, and Next.js server actions.
---

# Backend Infrastructure & Reliability Standards

This document outlines the core principles and practices for building robust, secure, and scalable systems. These standards apply to all backend services, API routes, and full-stack integration points.

## A. Service and Route Design Fundamentals

### 1. Validate at the Boundary, Trust Inside

**Principle:** Input validation must happen strictly at the edge of the service.

- **Implementation:** Parse and validate all request inputs (using Pydantic, Zod, etc.) immediately upon entry.
- **Internal Logic:** Once past the boundary, internal functions should receive strongly-typed, valid objects. Do not pass raw dictionaries deep into the application.

### 2. Make Writes Idempotent

**Principle:** Network failures happen. Clients _will_ retry. Ensure these retries are safe.

- **Implementation:**
  - **CREATE/UPDATE:** Support **Idempotency Keys** for critical transactions.
  - **Database:** Leverage unique constraints (e.g., `unique(user_id, resource_id)`) to handle race conditions naturally.
- **Goal:** Processing the same request twice should produce the same result and side effects as processing it once.

### 3. Use Explicit Timeouts Everywhere

**Principle:** A default "no timeout" is a license for the system to hang forever.

- **Scope:** Apply timeouts to everything: HTTP clients, Database connections, Redis calls, and External Service integrations.
- **Strategy:** Set aggressive timeouts for user-facing paths. It is better to fail fast than to lock up resources indefinitely.

### 4. Fail Fast on Dependency Slowness

**Principle:** Do not let a degraded dependency cascade into a total system outage.

- **Implementation:** If a dependency (e.g., a payment provider) is responding slowly, prefer a quick "Try Later" failure over waiting for a long timeout.
- **Pattern:** Use Circuit Breakers to stop calling failing services.

### 5. Define a Consistent Error Contract

**Principle:** Errors are API responses too. They must have a predictable shape.

- **Format:** Standardize fields across REST and Server Actions.
  ```json
  {
    "code": "MISSING_PERMISSION",
    "message": "User does not have access to this resource.",
    "request_id": "req_123abc",
    "details": { ... }
  }
  ```

### 6. Make Partial Failure a First-Class Outcome

**Principle:** Distributed actions may only partially succeed.

- **Strategy:** If a DB write succeeds but an email fails, define the behavior explicitly.
- **Handling:** Either fallback to a background queue to retry the non-critical part, or return a specific status code indicating partial success.

### 7. Prefer "Durable Work" for Slow Operations

**Principle:** HTTP requests should be fast.

- **Action:** Move slow, unreliable, or heavy operations (emails, PDF generation, webhooks) to a durable background queue (Redis/Celery/SQS).
- **Risk:** Performing these in the request/response cycle risks timeout and data inconsistency.

### 8. Separate Domain Logic from Transport

**Principle:** Business logic should exist independently of the web framework.

- **Architecture:**
  - **Transport Layer (Routes):** validation, auth, HTTP mapping.
  - **Service Layer:** Pure business logic.
- **Benefit:** Allows logic to be reused in CLI scripts, cron jobs, or other interfaces without mocking HTTP context.

### 9. Use Stable Response Schemas

**Principle:** Clients depend on the shape of your data.

- **Implementation:** Always return strongly-typed response models.
- **Versioning:** Avoid accidental breaking changes by strictly defining the output schema.

### 10. Design for Backpressure

**Principle:** Prevent the system from accepting more work than it can handle.

- **Mechanisms:**
  - **Bounded Queues:** Reject jobs when queues are full.
  - **Pagination:** Mandate limits on list endpoints.
  - **Streaming:** Stream large datasets instead of buffering in memory.

---

## B. FastAPI Routes & Backend Endpoints

### 11. Keep Handlers Thin

**Rule:** Route handlers should be "thin adapters".

- **Responsibilities:** Parse request -> Authenticate -> Call Service Layer -> Map Service Result to HTTP Response.
- **Avoid:** Writing complex business logic inside the route function.

### 12. Return Correct Status Codes Deterministically

**Rule:** Use standard HTTP semantics.

- **Anti-Pattern:** Returning `200 OK` with a JSON body containing `{"error": "failed"}`.
- **Correct:** Use `400` for bad input, `401/403` for auth, `404` for missing, `500` for crashes.

### 13. Use Request-Scoped Dependency Injection

**Rule:** Do not use global state.

- **Implementation:** Inject DB sessions, user context, and config objects via the framework's dependency injection system (e.g., `Depends()` in FastAPI). This ensures resource cleanup and thread safety.

### 14. Always Protect Writes with Authorization Checks

**Rule:** Authentication is not Authorization.

- **Check:** Every write endpoint must verify that the _authenticated_ user has permission to modify the _specific_ target resource.
- **Defense:** Never rely on the frontend to hide unrelated buttons.

### 15. Avoid N+1 and Heavy Work in Request Path

**Rule:** Latency bombs are unacceptable.

- **Optimization:** Use `.joinedload()`, `.selectinload()` or batch loaders to fetch related data efficiently.
- **Profiling:** Monitor query counts on list endpoints.

### 16. Wrap Multi-Step Writes in Transactions

**Rule:** Atomicity is non-negotiable for multi-step writes.

- **Pattern:**
  ```python
  with db.transaction():
      create_user()
      create_profile()
  ```
- **Result:** Either everything commits, or nothing changes. No zombie data.

### 17. Enforce Uniqueness at the Database

**Rule:** Application-level checks are subject to race conditions.

- **Defense:** Define `UNIQUE` constraints in the SQL schema. Catch the integrity error in the code instead of doing `check_exists() -> insert()`.

### 18. Make Pagination Mandatory for List Routes

**Rule:** Unbounded lists are a DoS vector.

- **Implementation:** Require `limit` and `offset/cursor` params. Enforce a hard maximum `limit` (e.g., 100 items).

### 19. Use Optimistic Concurrency When Appropriate

**Rule:** Prevent "Last Write Wins" overwrites on shared resources.

- **Mechanism:** Use version numbers (ETags) or `updated_at` timestamps. If the client sends an old version, reject the update.

### 20. Ensure Uploads/Downloads are Streamed

**Rule:** RAM is expensive; Bandwidth is cheap.

- **Implementation:** Never load a full file into memory. Stream bytes from the client to S3 (and vice versa).

### 21. Use Consistent Request Limits

**Rule:** Validate "shape" limits early.

- **Limits:** Max body size, max string length, max JSON nesting depth, max array items.

### 22. Guard Every External Call

**Rule:** External services will fail.

- **Defense:** Apply timeouts, limited retries (for safe operations only), and circuit breakers to every external HTTP/RPC call.

### 23. Treat Webhooks as Hostile Inputs

**Rule:** Webhooks are input from the wild internet.

- **Verification:** strict signature verification (`X-Signature`), allowlist event types, and handle duplicates (idempotency).

### 24. Use Background Tasks Carefully

**Rule:** Framework "Background Tasks" are volatile.

- **Best Practice:** Use in-memory background tasks only for non-critical "best effort" work. For critical data (billing, email), use a persistent queue.

### 25. Return Correlation IDs

**Rule:** Traceability is essential for debugging.

- **Implementation:** Every response header must include `X-Request-ID`. Log this ID with every log message generated by that request.

---

## C. Middleware Reliability Patterns

### 26. Centralize Structured Logging

**Pattern:** Middleware logs the summary of every request.

- **Data:** Method, path, status code, latency (ms), request_id, user_id (if verified).
- **Format:** JSON logs for machine parsing.

### 27. Standardize Exception Handling Globally

**Pattern:** Catch exceptions at the top level.

- **Implementation:** Convert internal exceptions (e.g., `UserNotFound`) into standard HTTP error responses (404) in a single exception handler.

### 28. Add Timeout/Cancellation Propagation

**Pattern:** Stop working if the client leaves.

- **Mechanism:** If the HTTP client disconnects, propagate a cancellation signal context to the DB and internal services to halt processing.

### 29. Rate Limit at the Edge

**Pattern:** Protect the core application.

- **Implementation:** Apply rate limiting middleware based on IP or User ID to prevent abuse and burstiness.

### 30. Implement Request Size Limits

**Pattern:** Defense in depth.

- **Action:** Reject payloads larger than a defined threshold (e.g., 1MB for JSON) before even attempting to parse them.

### 31. Add Security Headers

**Pattern:** Secure defaults.

- **Headers:** `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Strict-Transport-Security`.

### 32. CORS: Least Privilege

**Pattern:** Restrict browser access.

- **Config:** Explicitly define allowed Origins, Methods, and Headers. Do not use `allow_origins=["*"]` in production.

### 33. Cache Headers Intentionally

**Pattern:** No "magic" caching.

- **Action:** Explicitly set `Cache-Control` headers. Default to `no-store` for APIs to prevent leakage. Enable private caching carefully for immutable resources.

### 34. Health Checks Should Be Cheap

**Pattern:** Load balancers check frequently; keep it light.

- **Routes:** `/health` returns 200 OK (immediate, no DB). `/ready` checks DB connectivity (for startup/deployment).

### 35. Measure Latency Buckets

**Pattern:** Averages are misleading.

- **Metrics:** Track p50, p95, and p99 latency in middleware. The tail latency is what users experience during load.

---

## D. Backend Service Reliability

### 36. Circuit Breaker Behavior

**Pattern:** Stop the bleeding.

- **Logic:** If a service has X% failure rate, "open" the circuit and fail immediately for a set cooldown period.

### 37. Bulkheads / Isolation

**Pattern:** Partition resources.

- **Implementation:** Use separate thread pools or connection pools for different dependencies. A slow legacy service shouldn't exhaust the connection pool for the main DB.

### 38. Connection Pool Hygiene

**Pattern:** Manage finite resources.

- **Config:** Set `pool_size`, `max_overflow`, and `pool_timeout` explicitly. Monitor "pool checkout time".

### 39. Plan for Cold Starts & Thundering Herds

**Pattern:** Smooth out spikes.

- **Techniques:** Implement "jitter" (randomness) in retry logic and cache expiration times to prevent all instances from refreshing simultaneously.

### 40. Use an Outbox Pattern for Events

**Pattern:** Transactional consistency.

- **Problem:** "Write to DB successful, but failed to publish to RabbitMQ".
- **Solution:** Write the event to a DB "outbox" table _in the same transaction_ as the data change. A separate worker relays events from the table to the queue.

### 41. Make Retry Policies Explicit and Bounded

**Pattern:** Infinite retries equal infinite load.

- **Policy:** Max attempts (e.g., 3) + Exponential Backoff + Jitter.

### 42. Retry Only Safe Operations

**Pattern:** Know your verbs.

- **Safe:** `GET`, `PUT` (if idempotent), `DELETE` (if idempotent).
- **Unsafe:** `POST` (usually). Never retry non-idempotent calls without special handling.

### 43. Define SLOs and Error Budgets

**Pattern:** Measure what matters.

- **Definition:** Define "Reliability" (e.g., 99.95% non-500 responses). Alert when the error budget is burning too fast.

### 44. Rollback Strategy

**Pattern:** Things will break.

- **Requirement:** Every deployment/migration must have a documented rollback storage. Use Feature Flags to decouple deployment from release.

### 45. Runbooks + On-Call Debug Paths

**Pattern:** Reliability is a process.

- **Doc:** "If alert X fires, check Y." Automate known fixes, document the rest.

---

## E. Next.js Server Actions & Frontend Wiring

### 46. Treat Server Actions as API Endpoints

**Rule:** Server Actions are reachable via POST requests by anyone.

- **Security:** Apply the same rigor as REST APIs. Validate inputs with Zod/Valibot. Enforce Authorization checks inside the action.

### 47. Make Server Actions Idempotent

**Rule:** Users double-click.

- **Handling:** Ensure logic can handle multiple submissions of the same form without duplicating data.

### 48. Never Leak Raw Errors to Client

**Rule:** Security through obscurity (of implementation details).

- **Practice:** Catch errors server-side. Log the full stack trace securely. Return a generic, safe error message to the client (mapped via the Error Contract).

### 49. Use Optimistic UI + Pending States

**Rule:** Instant feedback loops.

- **Frontend:** Use `useTransition` and `useActionState`. Disable submit buttons immediately. Show optimistic updates where safe.

### 50. Revalidation is Part of Correctness

**Rule:** Cache invalidation is hard but necessary.

- **Action:** After a mutation, explicitly call `revalidatePath` or `revalidateTag`.
- **Why:** Ensures the client UI doesn't show stale data that contradicts the server state.
