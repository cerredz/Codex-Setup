# Skills Index

> **Central reference for all skill commands.** When a skill needs to reference related skills, read this file instead of individual skill files.

---

## 📁 Category Overview

- **🧠 Reasoning & Planning**: Problem decomposition, planning strategies, research methods (`reasoning_planning/`)
- **🏗️ Architecture & Design**: System design, data modeling, structural decisions (`architecture_design/`)
- **💻 Languages**: Language-specific best practices and frameworks (`languages/`)
- **🔧 Backend & Infrastructure**: Databases, APIs, server-side patterns (`backend_infrastructure/`)
- **🎨 Frontend**: UI frameworks, styling, animation (`frontend/`)
- **✅ Testing & Quality**: Testing strategies, code quality verification (`testing_quality/`)
- **🔄 Refactoring & Migration**: Code evolution, modernization, migrations (`refactoring_migration/`)
- **🛡️ Error Mitigation**: Auditing, security review, defensive coding (`error_mitigation/`)
- **🎭 Modes & Personas**: Behavioral modifiers, coding styles (`modes_personas/`)

---

## 🧠 Reasoning & Planning

### [pause_and_understand](reasoning_planning/pause_and_understand.md)

**Synergies:** `ask_questions`, `first_principles`

Forces a deliberate pause before action to synthesize the user's core objective from multiple context sources, preventing purely procedural responses. It prioritizes the user's underlying intent over literal instructions when they diverge, ensuring strategic alignment. This skill prevents "attention fragmentation" and ensures every action serves the holistic goal.

### [tree_of_thought](reasoning_planning/tree_of_thought.md)

**Synergies:** `first_principles`, `generate_plan`

Generates multiple distinct reasoning paths to explore different dimensions of a problem before converging on a solution. It encourages diverse perspectives—examining technical feasibility, edge cases, user experience, and security—to prevent tunnel vision. This process creates a hidden "cognitive scaffolding" that ensures the final response is robust and well-considered.

### [first_principles](reasoning_planning/first_principles.md)

**Synergies:** `architect`, `tree_of_thought`

Systematically deconstructs a problem into its fundamental truths (axioms) by stripping away assumptions and analogies. It aggressively questions "why" something is needed until the undeniable constraints are revealed. The solution is then reconstructed from the ground up based solely on these proven truths.

### [generate_plan](reasoning_planning/generate_plan.md)

**Synergies:** `architect`, `first_principles`

Creates a comprehensive, granular implementation plan that covers pre-implementation analysis, core execution, and post-implementation verification. It breaks down high-level requests into specific, actionable tasks with clear dependencies and error mitigation strategies. The plan acts as a strict roadmap that must be approved before any code is written.

### [generate_plan_feature](reasoning_planning/generate_plan_feature.md)

**Synergies:** `generate_plan`

Specializes in feature-specific planning that aligns closely with architectural design documents and existing system patterns. It cross-references general design principles to ensure new features fit seamlessly into the broader ecosystem. The resulting plan details file paths, dependencies, and validation steps for the specific feature.

### [ask_questions](reasoning_planning/ask_questions.md)

**Synergies:** Any skill

Formulates a list of clarifying questions to resolve ambiguities and deepen understanding before attempting an implementation. It covers both high-level conceptual doubts and low-level implementation details. This ensures the final solution aligns perfectly with the user's intent and context.

### [explore_codebase](reasoning_planning/explore_codebase.md)

**Synergies:** `architect`, `generate_plan`

Systematically lists and reads relevant files to build a complete mental map of the system architecture and dependencies. It traces imports, examines parent directories, and reviews configuration files to understand how the target code fits into the whole. This prevents isolated fixes that break downstream components.

### [self_refinement](reasoning_planning/self_refinement.md)

**Synergies:** `generate_plan`

Executes a recursive critique loop where the agent evaluates its own plan against the original requirements to identify gaps or vagueness. It iteratively improves the plan by addressing these self-identified deficiencies. This ensures the final output is polished and rigorous before being presented to the user.

### [confidence_weighting](reasoning_planning/confidence_weighting.md)

**Synergies:** `generate_plan`

Assigns explicit confidence scores and priority levels to each task in a plan based on the available context and certainty. It highlights areas of high risk or ambiguity that may require further research. This allows for better prioritization and risk management during execution.

### [think_longer](reasoning_planning/think_longer.md)

**Synergies:** `pause_and_understand`, `tree_of_thought`

Think longer than you normally would before responding. Do not settle on your first interpretation or your first solution—sit with the problem, question your assumptions, and explore alternatives before committing to an answer. If your reasoning feels quick or automatic, you have not thought enough. Slow down.

---

## 🏗️ Architecture & Design

### [architect](architecture_design/architect.md)

**Synergies:** `first_principles`, `schema_design`

Creates a comprehensive system architecture document that addresses both functional and non-functional requirements like performance, security, and scalability. It forces explicit trade-off analysis and documents decision rationale to guide future engineering. The resulting artifact serves as the blueprint for all subsequent implementation work.

### [feature](architecture_design/feature.md)

**Synergies:** `ux_best_practices`, `schema_design`, `creating_server_action`, `rest_api_security`

Orchestrates the end-to-end process of building a new feature, from UI/UX design and database integration to backend implementation and testing. It defines a strict chronological workflow that ensures every layer of the stack—frontend, state management, API, and security—is implemented in the correct order and adheres to established best practices.

---

## 💻 Languages

### [python_best_practices](languages/python_best_practices.md)

**Synergies:** `python_refactorer`, `tester`

Enforces strict standards for writing robust, readable, and maintainable Python code suitable for production environments. It emphasizes type hinting, rigorous error handling, and pythonic idioms while discouraging "AI slop" or unnecessary complexity. The focus is on long-term maintainability and clarity.

### [langgraph_expert](languages/langgraph_expert.md)

**Synergies:** `llm_prompt_engineer`

Provides expert guidance on building stateful, agentic orchestration systems using LangGraph. It covers state management, node definition, graph composition, and persistence patterns for complex workflows. It ensures that agents are built with proper error handling, human-in-the-loop capabilities, and observability.

### [llm_prompt_engineer](languages/llm_prompt_engineer.md)

**Synergies:** `langgraph_expert`

Designs high-performance system prompts using the "Identity-Goal-Input" framework to ensure consistent and high-quality LLM outputs. It structures prompts to establish expert authority, define clear success criteria, and specify exact input/output formats. This systematic approach reduces hallucinations and improves alignment with user intent.

### [stripe](languages/stripe.md)

**Synergies:** `creating_server_action`

Provides expert guidance on integrating Stripe payments, prioritizing the use of Checkout Sessions and Payment Intents over legacy APIs. It covers security compliance, PCI handling, and subscription modeling. This ensures financial transactions are handled securely and in accordance with Stripe's latest best practices.

---

## 🔧 Backend & Infrastructure

### [mongodb_operations](backend_infrastructure/mongodb_operations.md)

**Synergies:** `schema_design`

Focuses on writing high-performance MongoDB queries and update operations that are optimized for the query planner. It prioritizes atomic operations to prevent race conditions and efficient aggregation pipelines to minimize resource usage. The goal is to ensure database interactions remain fast and reliable as data volume grows.

### [rest_api_security](backend_infrastructure/rest_api_security.md)

**Synergies:** `error_mitigation/*`

Implements a "defense-in-depth" security strategy for REST APIs, covering authentication, authorization, input validation, and rate limiting. It adopts a threat-model mindset to identify and neutralize common attack vectors like IDOR and injection attacks. This ensures the API fails safely and protects sensitive data under hostile conditions.

### [creating_server_action](backend_infrastructure/creating_server_action.md)

**Synergies:** `react_best_practices`

Provides a standardized pattern for creating secure Next.js server actions, including input validation, authentication checks, and backend communication. It ensures that server actions are robust, secure, and properly integrated with the broader application architecture. This prevents common security holes in full-stack Next.js apps.

### [optimize_queries](backend_infrastructure/optimize_queries.md)

**Synergies:** `mongodb_operations`

Defines a workflow for analyzing and improving the efficiency of database queries by examining execution plans and index usage. It identifies bottlenecks such as full collection scans or N+1 query patterns. The skill guides the application of targeted indexes and query restructuring to achieve millisecond-level performance.

### [schema_design](backend_infrastructure/schema_design.md)

**Synergies:** `architect`, `mongodb_operations`

Designs production-grade MongoDB schemas focused on access patterns, relationship cardinality, and long-term scalability. It emphasizes performance optimization techniques like embedding vs. referencing decisions and proper indexing strategies. The goal is to prevent common pitfalls like unbounded arrays and performance bottlenecks at scale.

---

### [api_security_best_practices](backend_infrastructure/api_security_best_practices.md)

**Synergies:** `audit_middleware`, `python_best_practices`

Implements a comprehensive "defense-in-depth" security strategy for REST APIs, covering 30+ distinct vulnerability classes. It provides concrete FastAPI implementation patterns for mitigating threats ranging from standard injection attacks to subtle architectural flaws like race conditions, side-channel attacks, and logic gaps. The skill enforces a "secure by design" mindset.

---

## 🎨 Frontend

### [react_best_practices](frontend/react_best_practices.md)

**Synergies:** `tailwind`, `framer_motion`

A comprehensive guide to optimizing React and Next.js applications, focusing on critical performance factors like eliminating waterfalls and reducing bundle size. It mandates patterns that improve Core Web Vitals, such as parallel data fetching and strategic code splitting. The goal is to create fast, responsive user and developer experiences.

### [tailwind](frontend/tailwind.md)

**Synergies:** `react_best_practices`

Expertise in architecting scalable CSS using Tailwind's utility-first methodology, configuration, and design system integration. It guides the use of utility classes, arbitrary values, and configuration customization to build consistent UIs. It emphasizes maintainability and performance through proper purging and token usage.

### [framer_motion](frontend/framer_motion.md)

**Synergies:** `react_best_practices`, `tailwind`

Guidelines for creating performant, fluid animations that enhance user experience without causing layout thrashing. It focuses on declarative animation definitions, gesture handling, and shared layout transitions. The skill ensures animations are smooth (60fps) and add meaningful interactions.

### [ux_best_practices](frontend/ux_best_practices.md)

**Synergies:** `react_best_practices`, `tailwind`

A comprehensive collection of 50+ production-grade UX patterns for building intuitive and accessible interfaces. It covers visual hierarchy, navigation, forms, and feedback mechanisms, emphasizing "cognitive load" reduction. Applying these practices ensures the application feels premium, responsive, and easy to use.

---

## ✅ Testing & Quality

### [tester](testing_quality/tester.md)

**Synergies:** `python_best_practices`, `react_best_practices`

Develops strategic test plans that target critical business logic, edge cases, and potential system failure points. It prioritizes high-value tests that protect against data corruption, security breaches, and integration failures over superficial coverage. The goal is to ensure system resilience and reliability through rigorous verification.

---

## 🔄 Refactoring & Migration

### [python_refactorer](refactoring_migration/python_refactorer.md)

**Synergies:** `python_best_practices`

Applies systematic, safe refactoring techniques to improve code maintainability and readability without altering behavior. It detects code smells like long methods or tight coupling and applies targeted transformations like "Extract Method" or "Introduce Parameter Object". The process emphasizes incremental changes verified by tests.

### [cleanup_comments](refactoring_migration/cleanup_comments.md)

**Synergies:** `python_refactorer`

Enforces a high-signal comment policy that removes noise, stale TODOs, and redundant explanations. It advocates for self-documenting code where names explain intent, reserving comments for "why" rather than "what". This keeps the codebase clean and reduces the cognitive load of reading outdated or obvious comments.

---

## 🛡️ Error Mitigation

_Auditing, security review, defensive coding patterns_

### [audit_middleware](error_mitigation/audit_middleware.md)

**Synergies:** `rest_api_security`, `tester`

Conducts exhaustive security audits of FastAPI routes to verify dependency chains, authentication gaps, and authorization logic. It maps out the execution flow of middleware and dependencies to ensure every endpoint is protected. The skill identifies vulnerabilities like missing rate limiters or improper input validation before they reach production.

### [audit_tests](error_mitigation/audit_tests.md)

**Synergies:** `tester`

Conducts an exhaustive audit of the existing test suite to identify critical coverage gaps, redundant tests, and quality issues. It maps the system landscape to ensure every route, business logic function, and database operation is protected against production failures. The goal is to produce a prioritized roadmap for hardening the test suite.

> **Future skills**: `security_audit`, `code_review`, `defensive_coding`, `error_handling`

---

## 🎭 Modes & Personas

### [minimalist](modes_personas/minimalist.md)

**Use when:** Brevity is priority

A persona that prioritizes extreme conciseness and clarity, stripping away any non-essential code or boilerplate. It favors direct, readable solutions that are immediately understandable without extensive documentation. The goal is to solve the problem with the absolute minimum amount of code required.

### [ralph_wiggins](modes_personas/ralph_wiggins.md)

**Synergies:** `generate_plan`

**Use when:** Implementing task/plan files

A tenacious, step-by-step execution mode that obsessively completes tasks sequentially with rigorous verification. It forbids jumping ahead or parallelizing, ensuring that every detail is handled with absolute precision. This mode is ideal for complex, high-stakes implementation tasks where accuracy is paramount.

### [expert](modes_personas/expert.md)

**Synergies:** Any skill

**Use when:** Deep domain expertise is required

A persona that assumes deep domain knowledge and skips introductory explanations to focus on nuances, edge cases, and tradeoffs. It answers from the perspective of a seasoned veteran, prioritizing hard-to-find information over basic tutorials.

### [researcher](modes_personas/researcher.md)

**Synergies:** `explore_codebase`

**Use when:** Gathering context before action

A persona that mandates thorough investigation using available tools before formulating a response. It prevents assumption-based answers by forcing the active gathering of facts, documentation, and code evidence.

## 📝 Adding New Skills

When adding a new skill:

1. Place the `.md` file in the appropriate category folder
2. Update this index with the skill entry in the new paragraph format
3. Add synergies with related skills
4. Consider if it fits common combinations
