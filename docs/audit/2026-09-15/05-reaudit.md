# Al Batal Elite — Re-Audit (identical rubric) + Residual Risk Register

- **Date:** 2026-09-15
- **Rubric:** [01-rubric.md](01-rubric.md) — **identical document, identical weights**, frozen before the first pass
- **Tree re-audited:** `fix/audit-2026-09-15` (7 commits on top of `5fd16e9`)
- **Method:** the same scans and gates as the baseline pass, re-run on the repaired tree; every cited fix re-verified by reproduction (see [04-verification.md](04-verification.md))

## 1. Scores — same rubric, same weights

| Dimension | Weight | Baseline | Re-audit | Movement |
|---|---|---|---|---|
| Maintainability | 20% | 8.5 | **9.5** | +1.0 |
| Clean architecture | 20% | 9.5 | **10.0** | +0.5 |
| Code quality | 20% | 7.5 | **9.5** | +2.0 |
| Security | 25% | 8.0 | **9.5** | +1.5 |
| Performance | 15% | 8.5 | **9.0** | +0.5 |
| **Weighted overall** | 100% | **8.4** | **9.5** | **+1.1** |

```
Re-audit = 0.20×9.5 + 0.20×10.0 + 0.20×9.5 + 0.25×9.5 + 0.15×9.0
         = 1.90 + 2.00 + 1.90 + 2.375 + 1.350 = 9.525 → 9.5
```

Harness on the re-audited tree: analyze clean · **888/888 tests pass** · format clean · Android debug APK builds · 70.4% coverage · secret sweep clean.

## 2. Why this is 9.5 and not 10.0

Every **code-level** finding raised by this audit is either fixed-and-verified or explicitly reviewed and waived. What remains between 9.5 and 10.0 is **not code defects** — it is four owner-gated decisions that the audit is contractually forbidden from taking unilaterally (`AGENTS.md`: no `pubspec.yaml` edits without approval, no `supabase/` migration edits without human review).

Per the audit brief, these are reported as residual risk rather than by discarding the rubric to manufacture a literal 10.

## 3. Residual risk register

| ID | Residual | Dimension | Why it is not closed here | Exact owner action to close it | Risk if left open |
|---|---|---|---|---|---|
| RESIDUAL-R1 (`AUD-008`) | Admin customer directory is RLS-narrowed; the referenced `061` policy migration does not exist | Security | `AGENTS.md` forbids editing `supabase/` migrations without human review; applying requires DB access the auditor does not have. **Corroborated independently** by the 2026-09-14 live-DB check recorded in `STATE.md`: no admin SELECT policy is live on `profiles`, and `admin_list_customers` is a SECURITY DEFINER function that exists in production with no migration file (migration-parity debt) | Review `docs/audit/2026-09-15/proposals/061_admin_profiles_read.sql` and pick one route: (a) apply the SELECT policy, or (b) migrate the live-only `admin_list_customers` function and call it from the repository. Then run the checklist and apply on staging → production | Admin console silently under-reports customers; no data exposure. Medium impact, low severity |
| RESIDUAL-R2 (`AUD-009`) | `http: any` in `dev_dependencies` | Maintainability / supply chain | `AGENTS.md` forbids `pubspec.yaml` changes without explicit approval | Change `http: any` → `http: ^1.2.0` (or delete if unused), then `flutter pub get` | A future `http` major can break the test harness on a fresh checkout. Low |
| RESIDUAL-R3 (`AUD-011`) | Catalogue colour names are a hardcoded ARGB map | Maintainability | Requires a schema decision (`products.color_name` or a lookup table) + migration review | Add the column/table, regenerate, read it in the mapper keeping the `'Other'` fallback | Cosmetic drift between DB colours and filter labels. Low |
| RESIDUAL-R4 (`AUD-013`) | `.gitignore` ignores `lib/generated/` while 3 generated l10n files are tracked | Maintainability | Repo-governance wording; either choice is defensible | Add a comment (`# l10n output is intentionally tracked`) or a `!lib/generated/l10n/` negation | Contributor confusion; a new generated file may be silently ignored. Very low |
| RESIDUAL-R5 (`AUD-012`) | Admin console + invoice PDF use hardcoded English copy | Maintainability | **Waived, not a defect**: the code documents the choice ("Admin-only, intentionally unlocalized") | If Arabic-speaking staff use the console: add ARB keys and switch to `context.l10n`; invoice needs locale plumbing | Admin UX only; customer-facing surfaces are fully localized. Very low |
| RESIDUAL-R6 | Release keystores (`release-key.jks`, `release-keystore.jks`) live in the repo root on disk | Security hygiene | Untracked and gitignored, so no leak through git; moving them touches the owner's local build setup | Move signing material outside the repository tree; rotate if it was ever shared or copied | Local filesystem exposure of signing material. Low |
| RESIDUAL-R7 | No certificate pinning | Security | Deliberate stack-level trade-off; adding it is an architectural change needing owner sign-off | Explicitly accept in writing, or pin via a custom `http` client for Supabase/Paymob hosts | MITM via a trusted-device CA. Low-medium, standard for this stack |
| RESIDUAL-R8 | `admin_sales_dashboard_page.dart` builder lacks `buildWhen`; 20 static `ListView(` surfaces | Performance | Inspected: bounded static content (≤ 4 cards / form fields / policy text); adding guards is churn without measured benefit | None required; revisit only if the dashboard grows a scrolling list | Negligible |
| RESIDUAL-R9 | 9 payments tests could not be re-run as a single file group because `test/payment_test.dart` no longer exists (referenced by an older plan doc) | Documentation | The file was reorganised in a prior batch; the suite runs via the folder | Update the stale path reference in `docs/superpowers/plans/2026-09-08-audit-batch.md` if that plan is reused | Confusion for a future implementer following the old plan. Very low |

## 4. Confidence notes (per rubric requirement)

| Dimension | Confidence | Basis / limitation |
|---|---|---|
| Maintainability | High | Full-tree scans (file sizes, dartdoc, TODO census) + 15 files read in full. Metrics are countable, not subjective |
| Clean architecture | High | Dependency-direction rules were tested mechanically across all 255 files (0 violations), not sampled |
| Code quality | High | Gate-driven (analyzer, formatter, suite) plus a complete triage of all 26 non-null assertions and all 97 catch sites |
| Security | Medium-high | Secrets/RLS/platform config reviewed directly; RLS coverage is repo-wide by policy grep + deep reads of 002/017/029, but 59 migrations were not re-derived line-by-line from a live database. No live probing was allowed |
| Performance | Medium | Static analysis plus the existing `catalog_perf_test.dart`; no profiling against real devices or a production dataset was in scope |

## 5. Honest assessment

The codebase was already well above average at baseline (8.4/10): clean layering, disciplined error handling, documented RLS hardening, bounded queries and a large test suite. The audit's real value was catching three things a green-looking repo hid — a **build-breaking manifest typo**, a **truncated test file that silently disabled a documented regression guard**, and a **security control that could crash instead of failing closed** — then closing the gap to 9.5 with verified fixes.
