# Code Review Standards and Operating Process

**Status:** Proposed team standard  
**Audience:** Authors, reviewers, tech leads, maintainers, and release owners  
**Scope:** Application code, APIs, database changes, infrastructure, configuration, tests, and documentation changes  
**Primary goal:** Detect correctness, security, reliability, and maintainability problems early while making review a repeatable learning process rather than a personal style debate.

---

## 1. Operating principles

1. **Review the change, not the author.** Comments must describe observable behavior, risk, or maintainability impact.
2. **Correctness before preference.** A bug, security weakness, broken contract, or untestable design takes priority over formatting preferences already enforced by tooling.
3. **Small changes are easier to review.** Keep pull requests focused on one coherent outcome. Separate cleanup, dependency upgrades, and unrelated refactors.
4. **Automate deterministic checks.** Formatters, linters, type checks, tests, secret scanning, and build checks should not be left to human memory.
5. **Review risk proportionally.** A payment boundary, authorization policy, migration, or production configuration deserves more scrutiny than a copy-only change.
6. **Make feedback actionable.** Every non-trivial finding should identify the location, impact, reasoning, and an acceptable direction for resolution.
7. **Prefer evidence over confidence.** “Tests pass” is evidence for covered behavior; it is not proof that untested behavior is correct.
8. **Teach without blocking unnecessarily.** Explain recurring issues, pair on unfamiliar areas, and reserve approval blocks for issues that materially affect quality or risk.
9. **Leave the codebase better, not merely different.** Avoid unrelated refactoring, speculative abstractions, and review churn.
10. **No silent exceptions.** Accepted risk must be documented with an owner, rationale, and follow-up issue or explicit expiration condition.

---

## 2. Review levels and required rigor

Use the highest applicable level when a change spans categories.

| Level | Typical changes | Minimum review |
|---|---|---|
| **L0 — Routine** | Documentation, comments, localized copy, generated output with verified source change | Author self-check, automated checks, one reviewer when behavior is affected |
| **L1 — Standard** | Ordinary feature work, UI changes, refactors, non-sensitive API changes | One independent reviewer, tests for changed behavior, analyzer/linter and relevant build checks |
| **L2 — Elevated** | Authentication, authorization, personal data, payments, database schema/RLS, external callbacks, dependency changes, release configuration | Two-person review or one qualified domain reviewer plus independent verification; targeted negative tests and deployment impact analysis |
| **L3 — Critical** | Production security boundary, destructive migration, payment settlement logic, signing/release secrets, incident remediation, data-loss risk | Explicit owner/release approval, security or domain review, rollback plan, evidence from a safe environment, and post-deployment verification |

### 2.1 Change-risk questions

Before assigning reviewers, the author answers:

- Does the change affect authentication, authorization, tenant/user isolation, or secrets?
- Does it change money movement, pricing, inventory, order status, or idempotency?
- Does it modify a database schema, migration order, RLS policy, RPC, webhook, or background job?
- Does it alter a public API, persisted data format, navigation contract, or deep link?
- Does it affect performance-sensitive paths, startup, scrolling, list rendering, or network/database volume?
- Does it change platform configuration, build signing, deployment, permissions, or dependency versions?
- Is rollback straightforward, and can the old and new versions coexist safely?

Any “yes” raises the review to at least **L2** unless the team lead explicitly records why not.

---

## 3. Review criteria

Reviewers should evaluate the following dimensions in order: **correctness and risk first, then maintainability, then performance and polish**. Do not use the checklist mechanically; focus on the behavior and trust boundaries affected by the change.

### 3.1 Readability

A readable change can be understood without reverse-engineering it.

**Verify:**

- Names describe domain intent, not implementation accidents. Avoid unexplained abbreviations and names such as `data`, `temp`, `handler2`, or `doThing` when a more precise name is possible.
- Functions and classes have one primary responsibility. Long methods, deeply nested conditionals, and mixed UI/data/error logic are signals to investigate.
- Control flow is easy to follow. Prefer guard clauses and explicit states over clever boolean expressions or hidden side effects.
- Public interfaces make preconditions, outputs, and failure behavior clear.
- Comments explain **why**, a constraint, or a non-obvious trade-off. Do not add comments that merely restate the code.
- Formatting, imports, null-safety conventions, naming, and project idioms match the repository and are enforced by tools where possible.
- User-facing strings are localized when the project supports localization. Directional layout and accessibility semantics are preserved.
- Tests name the behavior they protect and use realistic domain language.

**Warning signs:** duplicated branching, unexplained magic values, multiple levels of callbacks, hidden global state, comments that contradict the code, and a reviewer needing to ask what the code does before being able to assess whether it is correct.

### 3.2 Maintainability

Maintainability is the cost and safety of changing the code later.

**Verify:**

- The change is placed in the correct module and layer. Dependencies point inward according to the project architecture.
- UI renders state and dispatches intent; business rules live in domain/application logic; data mapping and provider-specific behavior stay at the data boundary.
- New abstractions have at least one concrete reason to exist. Do not introduce a shared helper for a single call merely to appear reusable.
- Repository contracts are stable and explicit. Provider models do not leak into presentation or domain layers without a deliberate mapping decision.
- The change preserves backward compatibility or documents the migration path for public APIs, stored data, routes, and persisted state.
- Duplication is either removed safely or intentionally retained because premature abstraction would couple unrelated behavior.
- Dependencies are justified, maintained, licensed appropriately, and not added when the platform or current stack already provides the capability.
- Tests cover the behavior most likely to regress, especially branching, mapping, authorization, error paths, and state transitions.
- Documentation, runbooks, configuration examples, and generated files are updated only when they are part of the change’s source of truth.
- The diff contains no unrelated formatting churn, generated artifacts, local paths, temporary files, or experiments.

**Maintainability test:** A competent teammate who did not write the change should be able to identify where to modify the behavior, how to test it, and what constraints must not be broken.

### 3.3 Performance

Performance review should identify measurable or credible regressions, not demand premature optimization.

**Verify:**

- Algorithmic complexity is appropriate for expected input size. Avoid repeated linear scans, nested queries, accidental N+1 requests, or unbounded loops.
- Expensive work is not performed on the UI/main thread when it can be deferred, batched, cached, or moved to an appropriate worker.
- Network calls have reasonable pagination, timeouts, cancellation, retry behavior, and response-size limits.
- Database queries select only required fields, use suitable filters and indexes, avoid N+1 access, and do not bypass intended server-side boundaries.
- Caching has explicit invalidation rules and does not return stale or unauthorized data across users or environments.
- Flutter widgets avoid unnecessary rebuilds, excessive work in `build`, avoidable `saveLayer`/opacity costs, uncontrolled animations, and unbounded lists without virtualization or pagination.
- Images and assets are sized, cached, and decoded appropriately for their display size.
- Streams, subscriptions, timers, controllers, and listeners are disposed or cancelled at the correct lifecycle boundary.
- Background work cannot create duplicate submissions or race with UI state changes.
- Performance claims are backed by a profile, benchmark, query plan, logs, or a clearly stated workload assumption when the path is high risk.

**Performance rule:** Do not reject a clear implementation for a theoretical optimization. Do reject a change when the expected workload, device constraints, query volume, or frame budget makes the regression credible.

### 3.4 Security and privacy

Security review is mandatory for changes involving identity, data access, external input, secrets, payments, storage, logging, or deployment.

**Verify:**

- No credentials, tokens, private keys, signing material, production connection strings, or secret values are committed, logged, returned to clients, or placed in client assets.
- Authentication is checked at the correct boundary; authorization is checked for every sensitive operation, not inferred from UI visibility.
- Object ownership and tenant boundaries are enforced server-side. Never rely on a client-supplied user ID, price, role, status, or permission.
- External input is validated for type, range, format, size, and allowed values before use. Reject invalid input rather than silently normalizing security-sensitive values.
- Database access uses least privilege, parameterized queries/RPCs, explicit grants, and restrictive RLS policies. Check both positive and negative cases.
- Webhooks and callbacks verify authenticators such as signatures/HMAC, protect against replay, enforce amount/order identity, and are idempotent.
- Sensitive errors do not expose provider responses, SQL details, stack traces, internal identifiers, or personally identifiable information.
- Logs and telemetry are scrubbed for credentials, payment data, personal data, authorization headers, and raw provider/database objects.
- Redirects, deep links, uploaded files, URLs, and external content use allowlists and safe schemes where relevant.
- Dependency and supply-chain changes are reviewed for provenance, permissions, known advisories, and transitive impact.
- Privacy, retention, deletion, and access rules remain consistent with project policy.

**Required security evidence for elevated changes:** threat boundary summary, abuse/negative tests, secret scan result, and a rollback or containment plan where applicable.

### 3.5 Error handling and resilience

Error handling should preserve correctness, user safety, debuggability, and recovery.

**Verify:**

- Loading, success, empty, partial, and error states are explicit where the UI or API can observe them.
- Errors are caught at the correct boundary. Provider exceptions are translated into stable application errors; widgets do not contain database or transport error policy.
- Exceptions are not swallowed, ignored, or converted into false success. If an error is intentionally ignored, document why and how it is observed.
- User-facing messages are safe, localized where required, actionable, and free of implementation details or secrets.
- Retry behavior is bounded and appropriate. Do not retry validation failures, authorization failures, or non-idempotent writes without a safe idempotency design.
- Timeouts and cancellation prevent indefinite spinners and orphaned work.
- Mutations are atomic or compensating steps are defined. Partial failure cannot silently leave inconsistent order, payment, inventory, or profile state.
- Duplicate requests, process restarts, delayed callbacks, and out-of-order events are handled explicitly for stateful workflows.
- Logs include enough context to diagnose the failure without exposing sensitive values. Correlation/request IDs are preferred over dumping payloads.
- Tests cover expected failures, boundary failures, malformed responses, offline/timeout behavior, and recovery or retry behavior.

---

## 4. Project-specific review profile: Al Batal Elite

The following rules apply in addition to the general criteria.

### Flutter and Dart

- `flutter analyze` must be clean for new findings; existing findings must be identified rather than silently ignored.
- Run `dart format --set-exit-if-changed .` or the repository-equivalent formatter check.
- Cubits expose immutable, explicit states. Widgets use `BlocBuilder` for rendering and `BlocListener` for side effects.
- Business logic does not move into widgets. Repositories own provider calls and mapping; presentation does not import Supabase configuration or raw data clients.
- New logic includes focused tests for state transitions, repository behavior, mapping, and errors. Bug fixes include a regression test when practical.
- RTL-safe layouts use directional insets and directional icons. User-visible copy goes through generated localization.
- Follow `DESIGN.md` for theme tokens, typography, touch targets, radii, colors, and dark-mode behavior.

### Supabase, SQL, and database changes

- Migrations are forward-only, ordered, idempotent where practical, and reviewed for the actual deployed migration history rather than filenames alone.
- RLS, grants, RPC `SECURITY DEFINER` behavior, search paths, ownership checks, and service-role boundaries are reviewed together.
- Every sensitive policy change includes negative tests: anonymous access, cross-user access, privilege escalation, direct table mutation, and forged/malformed input as applicable.
- Client-provided price, role, status, payment state, and ownership identifiers are not trusted.
- Production-impacting migrations include a backup/rollback or forward-repair plan and a staging verification procedure.

### Payments and commerce

- Payment state transitions are server-authoritative and idempotent.
- Provider callbacks verify authenticity, order identity, amount, replay behavior, and duplicate delivery behavior.
- Payment initiation and settlement do not depend on client-controlled database writes.
- Sensitive provider responses and transaction data are sanitized in client errors and logs.
- Changes require elevated review and evidence from a safe environment before release approval.

### Repository safety and release gates

- Do not modify `.env`, credential files, signing material, secrets, payment configuration, or protected deployment files without the explicit approval required by repository policy.
- Use an isolated worktree for code-changing attempts when required by `AGENTS.md`.
- Do not push, merge, deploy, or alter production systems as part of review without explicit human authorization.
- Reviewers must distinguish source/test evidence from live staging or production evidence. Never mark a live gate as passed from local tests alone.

---

## 5. Structured review workflow

### Phase A — Pre-review preparation

**Author responsibilities**

1. Open a focused pull request with a descriptive title.
2. State the problem, intended behavior, scope, non-goals, risk level, and rollout/rollback plan.
3. Link the issue, design decision, migration plan, incident, or acceptance criteria.
4. Describe user-visible changes and include screenshots, recordings, API examples, query plans, or evidence when they improve reviewability.
5. List tests and verification commands with actual results. State what was not run and why.
6. Call out security, data, payment, performance, compatibility, and migration implications.
7. Remove unrelated changes, generated churn, secrets, local paths, and debug code.
8. Request reviewers with the needed domain knowledge. Do not request approval from a reviewer who cannot reasonably assess the risk.

**Automated preconditions**

- Formatting and static analysis pass.
- Unit/widget/integration tests relevant to the change pass.
- Build or packaging checks pass for affected targets.
- Secret scanning and dependency checks pass or have a documented exception.
- Database migrations, policy tests, and deployment manifests validate when applicable.

**Reviewer preparation**

- Read the PR description and linked requirements before reading individual lines.
- Identify the trust boundaries, state transitions, data flow, and likely failure modes.
- Confirm the diff is in scope and the assigned review level is adequate.
- Ask for missing context before making detailed style comments.

### Phase B — Review execution

Use two passes for L1–L3 reviews:

**Pass 1: system-level review**

- Does the design solve the stated problem?
- Is the data/control flow correct across layers and services?
- Are contracts, authorization boundaries, persistence, rollout, and failure modes handled?
- Is the test strategy proportionate to the risk?

**Pass 2: implementation review**

- Read the changed code line by line, including tests and configuration.
- Check edge cases, null/empty values, concurrency, retries, lifecycle cleanup, and compatibility.
- Compare implementation behavior with the stated acceptance criteria.
- Inspect adjacent code only where it affects the changed behavior; avoid scope creep.
- Re-run or reproduce important checks for L2/L3 changes when independent verification is required.

**Review discipline**

- Prefer a small number of high-signal comments over exhaustive narration.
- Mark comments as blocking only when the severity policy supports blocking.
- Distinguish “must fix,” “should fix,” and “consider” explicitly.
- If the intent is unclear, ask a question before prescribing a redesign.
- Approve only after all blocking issues are resolved or formally accepted by the correct owner.

### Phase C — Feedback communication

A useful comment contains:

1. **Location:** file, symbol, or behavior; use a precise line range when possible.
2. **Finding:** what is wrong or uncertain.
3. **Impact:** correctness, security, reliability, maintainability, performance, or user impact.
4. **Reasoning/evidence:** the path, example, test, or invariant that demonstrates the concern.
5. **Suggested direction:** a concrete fix or question, without over-prescribing implementation details.
6. **Severity:** P0–P3 and whether it blocks approval.

**Example**

> **P1 — blocks approval | Authorization**  
> `updateOrderStatus` accepts an order ID from the client but does not verify ownership or an admin role at the server boundary. A user who knows another order ID could mutate that order. Please enforce ownership/role authorization in the RPC or repository boundary and add a cross-user negative test. The UI guard is not sufficient because it is client-controlled.

**Tone rules**

- Be direct, respectful, and specific.
- Avoid sarcasm, absolutes, and comments about intelligence or effort.
- Praise concrete strengths when they reduce risk or improve clarity.
- Do not use review comments to debate formatting already enforced by automation.
- Move architectural or repeated discussions to the PR summary, design document, or team discussion rather than repeating them on many lines.

### Phase D — Post-review follow-up

**Author**

- Resolve each blocking finding with code, tests, or a documented exception.
- Reply with what changed and the verification result; do not merely mark a thread resolved.
- Re-request review after material changes. Summarize the new diff so reviewers can focus their second pass.
- Create follow-up issues for accepted P2/P3 work with owner and target milestone.

**Reviewer**

- Re-check changed lines and any dependent behavior after fixes.
- Confirm that the fix addresses the root cause and did not introduce a new failure.
- Close comments only when the response and code provide sufficient evidence.
- Record residual risk for L2/L3 changes, especially deployment and rollback conditions.

**Team/maintainer**

- Review escaped defects and rejected findings during periodic calibration.
- Update checklists when a recurring production issue was not caught.
- Measure process outcomes, not reviewer volume: escaped defects, rework, review turnaround, rollback incidents, and percentage of changes with adequate verification.
- Do not use comment counts, approval counts, or raw review speed as individual performance targets.

---

## 6. Severity levels and resolution policy

| Severity | Definition | Examples | Review action |
|---|---|---|---|
| **P0 — Critical** | Immediate risk of data loss, credential exposure, payment compromise, authorization bypass, production outage, or unsafe release | Secret committed; cross-user data exposure; payment settlement can be forged; destructive migration without recovery | **Block approval and release.** Stop rollout if already deployed. Escalate immediately, contain/rotate/revoke as needed, fix and verify with independent evidence. |
| **P1 — High** | Material correctness, security, reliability, or compatibility defect likely to affect users or operations | Broken checkout path; missing error boundary causing false success; migration that fails on existing data; severe performance regression | **Block merge.** Fix before merge unless the designated owner explicitly accepts the risk with a time-bounded plan and release remains safe. |
| **P2 — Medium** | Important maintainability, test, edge-case, performance, or UX issue with limited immediate blast radius | Missing negative test; weak timeout handling on a non-critical request; avoidable duplication; moderate rebuild cost | Normally fix before merge when practical. If deferred, create a tracked issue with owner, rationale, and target milestone. Do not allow indefinite “later.” |
| **P3 — Low** | Non-blocking improvement, naming/documentation nit, or optional cleanup | Wording improvement; small refactor with no behavior impact; extra explanatory documentation | May be fixed in the PR or left as a non-blocking suggestion. Never obscure higher-severity findings. |

### 6.1 Severity decision rules

- Severity is based on **impact × likelihood × exposure**, not how difficult the fix is.
- A low-likelihood issue at a critical trust boundary can still be P0/P1.
- A missing test is P1 when it leaves a critical behavior unverifiable; otherwise it is usually P2.
- A reviewer may raise severity when new evidence appears. The author may request a second opinion, but must not relabel a finding solely to remove a blocker.
- Exceptions require: finding, rationale, approver, owner, mitigation, expiry/trigger, and tracking link.

### 6.2 Resolution states

Use these states consistently:

- **Open — blocking:** must be fixed or formally accepted before approval.
- **Open — non-blocking:** should be addressed or tracked; does not prevent approval.
- **Question:** intent or behavior needs clarification; not yet a defect.
- **Accepted risk:** documented exception with owner and follow-up.
- **Resolved:** code and evidence address the finding.
- **Won’t fix:** only with explicit rationale; use sparingly and never for unmitigated P0/P1 risks.

---

## 7. Pull request approval checklist

A reviewer should be able to answer “yes” to all applicable items before approving.

### Scope and intent

- [ ] The PR has one coherent purpose and matches the linked requirement.
- [ ] Scope, non-goals, risk level, and rollout/rollback considerations are clear.
- [ ] No unrelated refactoring, generated churn, debug code, local files, or secrets are included.
- [ ] The implementation is the smallest reasonable change that solves the problem.

### Readability and design

- [ ] Names, structure, and control flow communicate intent.
- [ ] Responsibilities are separated; no god-class, god-widget, or mixed-layer logic was introduced.
- [ ] Comments explain why or constraints, not obvious operations.
- [ ] Public interfaces and state transitions are explicit.
- [ ] The code follows repository conventions and architectural boundaries.

### Correctness and compatibility

- [ ] Normal, empty, invalid, boundary, duplicate, and concurrent cases were considered.
- [ ] Existing behavior and public contracts remain compatible, or the migration is explicit.
- [ ] Persistence, caching, serialization, and navigation/deep-link behavior are correct.
- [ ] The change cannot produce false success or silently discard work.

### Performance and lifecycle

- [ ] No obvious N+1 query, unbounded work, accidental quadratic path, or excessive payload exists.
- [ ] UI-thread/main-thread work is appropriate; rebuilds and list rendering are controlled.
- [ ] Network/database calls have appropriate pagination, timeout, cancellation, and retry behavior.
- [ ] Streams, timers, controllers, subscriptions, and resources are cleaned up.
- [ ] High-risk performance claims have evidence or a clear workload assumption.

### Security and privacy

- [ ] No credentials, tokens, private data, or sensitive provider responses are exposed.
- [ ] Authentication and server-side authorization are enforced at the real trust boundary.
- [ ] Input validation, ownership checks, tenant isolation, and least privilege are present.
- [ ] RLS/grants/RPC behavior is safe for both allowed and denied cases when applicable.
- [ ] Webhook/payment/callback authenticity, amount/order binding, replay, and idempotency are covered when applicable.
- [ ] Logs, analytics, errors, redirects, uploads, and URLs are appropriately sanitized/allowlisted.

### Error handling and observability

- [ ] Loading, success, empty, and error states are explicit where applicable.
- [ ] Errors are translated at the correct boundary and are safe for users.
- [ ] Retry, timeout, cancellation, rollback, and partial-failure behavior are defined.
- [ ] Diagnostic context is sufficient without logging secrets or personal data.
- [ ] Failures are covered by deterministic tests or documented evidence.

### Verification and release safety

- [ ] Formatting and static analysis passed with no unexplained new findings.
- [ ] Relevant unit/widget/integration/contract tests passed.
- [ ] Affected build/package/deployment checks passed.
- [ ] Database, migration, policy, and negative tests passed when applicable.
- [ ] The author listed what was not verified and why.
- [ ] All P0/P1 findings are resolved or formally accepted by the correct owner.
- [ ] Follow-up issues exist for deferred P2/P3 work that matters.
- [ ] The reviewer’s approval is appropriate for the risk level and domain.

---

## 8. Practical team model for mixed experience levels

### For authors

- Use the PR template and complete the risk questions before requesting review.
- Keep the diff small; split implementation, refactoring, and formatting when they do not need to land together.
- Ask for an early design review for L2/L3 changes instead of waiting until the code is complete.
- Include a short “how to verify” section so reviewers can reproduce behavior.

### For newer reviewers

- Start with L0/L1 changes and pair with a senior reviewer on L2/L3 work.
- Use the checklist as a learning guide, not as a substitute for understanding the requirement.
- Focus first on behavior, boundaries, tests, and failure modes; leave style to automation.
- Ask questions when intent is unclear and escalate security/payment/data concerns early.

### For experienced reviewers

- Explain recurring patterns and model good comments.
- Review the design and risk before line-by-line details.
- Avoid becoming the only person who understands a critical subsystem; rotate reviewers and document decisions.
- Calibrate severity consistently across team members.

### For leads and maintainers

- Define code owners for security, payments, database, release, and platform-sensitive areas.
- Protect review independence: the author should not be the sole approver for elevated changes.
- Use pairing or short review workshops when a change is educational or the team lacks domain coverage.
- Prefer a smaller number of qualified reviewers over a large approval queue.
- Revisit this standard after incidents, major architecture changes, or repeated review escapes.

---

## 9. Adaptation by project type

The core criteria stay constant; the emphasis changes.

| Project type | Add emphasis on |
|---|---|
| **Mobile/UI** | State transitions, lifecycle disposal, accessibility, localization/RTL, offline behavior, frame budget, platform permissions, deep links, and visual regression evidence |
| **Backend/API** | Contract compatibility, authentication/authorization, validation, rate limits, idempotency, timeouts, retries, observability, and backward-compatible rollout |
| **Database/data** | Migration ordering, existing-data behavior, constraints, indexes/query plans, RLS/grants, rollback/repair strategy, backup/restore, and privacy/retention |
| **Payments/commerce** | Server authority, amount/order binding, signature verification, replay resistance, duplicate callbacks, settlement state machine, reconciliation, and audit evidence |
| **Libraries/SDKs** | Public API stability, semantic versioning, documentation, platform compatibility, dependency surface, deprecation path, and consumer tests |
| **Infrastructure/CI/CD** | Least privilege, secret handling, artifact provenance, environment isolation, failure/rollback behavior, reproducibility, and change blast radius |
| **Data/ML/analytics** | Data contracts, schema drift, lineage, privacy, sampling bias, reproducibility, monitoring, and safe fallback behavior |
| **Documentation/configuration** | Accuracy, copy-paste safety, environment assumptions, version alignment, examples that do not contain secrets, and ownership of the source of truth |

### Minimum viable review profile

For a small team or low-risk project, the minimum is:

1. Author self-check and focused PR description.
2. Automated formatter/linter/test/secret checks.
3. One independent reviewer for behavior changes.
4. Explicit blocking policy for security, data loss, broken contracts, and production outages.
5. Tracked follow-up for meaningful deferred work.

Scale up to L2/L3 review when the risk questions or project type require it; do not scale down because the team is busy.

---

## 10. Suggested PR template

```markdown
## What changed?
<!-- Problem, intended behavior, and non-goals. -->

## Risk level
- [ ] L0 Routine
- [ ] L1 Standard
- [ ] L2 Elevated
- [ ] L3 Critical

## Risk notes
- Auth/authorization/data isolation:
- Payments/pricing/inventory:
- Database/migrations/RLS:
- Secrets/privacy/logging:
- Performance/lifecycle:
- Compatibility/rollout/rollback:

## Verification
Commands and actual results:
- `...`

Not run / not verified and why:
- `...`

## Reviewer focus
<!-- List the areas where deliberate review is most valuable. -->

## Screenshots, evidence, or query plans
<!-- Include only when relevant; never include secrets or private data. -->
```

---

## 11. Definition of done for review

A pull request is review-complete when:

- The requirement and risk are understood.
- Automated checks and relevant manual/evidence checks pass.
- The reviewer has completed both system-level and implementation-level review appropriate to the change.
- Every P0/P1 issue is resolved or formally accepted by the correct owner.
- Deferred P2/P3 work is tracked when it has lasting value.
- The final diff is understandable, scoped, and safe to merge.
- The approval reflects evidence, not an assumption that the code “looks right.”

This standard should be adopted with a short calibration period: review a few real PRs, compare severity decisions, and adjust wording or project-specific gates without weakening the blocking rules for security, data integrity, authorization, payments, and release safety.
