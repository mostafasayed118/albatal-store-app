# Al Batal Elite — Audit Handover Package

Audit: 2026-09-15 · Repair branch: `fix/audit-2026-09-15` · Baseline: `5ef935c` (+ owner-WIP snapshot `5fd16e9`)

## 1. What changed, and where to look

| Commit | Finding | Change | Files |
|---|---|---|---|
| `5fd16e9` | — | Pre-audit snapshot of the owner's uncommitted WIP (no code edits by the auditor) | 36 files (owner WIP) |
| `9884592` | AUD-001, AUD-002 | App-lock stays fail-closed on any sign-out failure; test harness wraps the gate in `MaterialApp` | `lib/shared/components/app_lock_gate.dart`, `test/shared/components/app_lock_gate_test.dart` |
| `ded0bb4` | AUD-003 | Reconstructed the truncated admin customer-directory test (`main()` + 5 tests + RPC fake) | `test/features/admin/data/admin_customer_directory_test.dart` |
| `e7f3839` | AUD-004 | Removed the illegal `--` from the manifest XML comment | `android/app/src/main/AndroidManifest.xml` |
| `e78ca6e` | AUD-005 | `dart format` across `lib` and `test` | 7 files |
| `f8c6f45` | AUD-006 | Payment watcher closes its controller on unsubscribe | `lib/features/payments/data/payment_status_watcher.dart` |
| `5d494ae` | AUD-010 | Removed the stale `cached_network_image` TODO | `lib/features/storefront/data/product_mapper.dart` |
| `b86…` → superseded | — | *superseded by* `707db16` + the final docs commit (audit report, rubric, ledger, verification, re-audit, handover, harness, RLS proposal, rendered report) | `docs/audit/2026-09-15/**`, `scripts/audit/run-audit.ps1`, `STATE.md` |

> The exact final commit list: `git log --oneline 5ef935c..fix/audit-2026-09-15`. Every fix commit maps to a ledger row; the docs commits carry the audit artifacts.

Deliverables index: [00-inventory](00-inventory.md) · [01-rubric](01-rubric.md) · [02-ledger.json](02-findings-ledger.json) / [02-ledger.csv](02-findings-ledger.csv) · [03-audit-report](03-audit-report.md) · [04-verification](04-verification.md) · [05-reaudit](05-reaudit.md) · [06-handover](06-handover.md) · [rendered report](report.html) · [patch series](patches/) · [scores data](scores.json) · [RLS proposal](proposals/061_admin_profiles_read.sql) · harness: `scripts/audit/{run-audit,score}.ps1`

### Patch series (review starting point)

`docs/audit/2026-09-15/patches/` holds one patch per fix commit, in apply order:

| Patch | Finding | Change |
|---|---|---|
| `0001-…app-lock-gate…` | AUD-001, AUD-002 | Fail-closed sign-out + MaterialApp test harness |
| `0002-…customer-directory…` | AUD-003 | Reconstructed admin test (`main()` + 5 tests) |
| `0003-…manifest…` | AUD-004 | Illegal `--` removed from the XML comment |
| `0004-…dart-format…` | AUD-005 | Formatter pass across lib + test |
| `0005-…payment-watcher…` | AUD-006 | Controller closed on unsubscribe |
| `0006-…cached_network_image-TODO…` | AUD-010 | Stale TODO removed |

Applying these six patches to the snapshot commit `5fd16e9` reproduces the fixed tree exactly
(255 lib / 169 test / 20 android files, zero SHA-256 differences) — see [04-verification](04-verification.md#8-patch-series-faithfulness-proof).

## 2. Rollback procedure

**Nothing has been pushed or merged.** `master` is untouched at `5ef935c`; all audit work sits on `fix/audit-2026-09-15`.

### Option A — discard the whole audit (fastest)

```powershell
cd C:\flutter_projects\albatal_store
git checkout master                     # working tree returns to the pre-audit state
git branch -D fix/audit-2026-09-15      # deletes the repair branch
```

> Note: the pre-audit state *included* uncommitted owner WIP. That WIP was committed as `5fd16e9` on the repair branch so it could not be lost. If you delete the branch, recover it first from the snapshot commit:
> `git checkout -b wip-recovery 5fd16e9` (or `git stash list` / your editor's local history).

### Option B — revert only the audit fixes, keep the branch

```powershell
git switch fix/audit-2026-09-15
git revert --no-commit 5d494ae f8c6f45 e78ca6e e7f3839 ded0bb4 9884592   # newest → oldest
git commit -m "revert: undo audit fixes"
```

Reverting `e7f3839` restores the broken manifest and Android builds will fail again — revert it only if you intend to reword the comment differently.

### Option C — keep fixes, drop only the audit docs

```powershell
git switch fix/audit-2026-09-15
git rm -r --cached docs/audit scripts/audit   # keeps files on disk
```

### Per-fix revert map

| Finding | Fully reverts with |
|---|---|
| AUD-001, AUD-002 | `9884592` |
| AUD-003 | `ded0bb4` |
| AUD-004 | `e7f3839` (re-breaks Android builds) |
| AUD-005 | `e78ca6e` |
| AUD-006 | `f8c6f45` |
| AUD-010 | `5d494ae` |

**No dependency, configuration or schema change is part of the repair branch** — so a revert needs no `pub get`, no Gradle sync, and no database rollback. The only SQL ever produced (`proposals/061_admin_profiles_read.sql`) was **never applied** and is documented with its own rollback block.

## 3. Deployment & configuration notes

- **No dependency changes.** `pubspec.yaml` and `pubspec.lock` were not modified by the audit.
- **No schema changes.** Migration 061 is a *proposal*, not applied. If you apply it, follow its review checklist and use its rollback block to undo.
- **Build note:** `android/app/src/main/AndroidManifest.xml` now parses. Any future edit to an XML comment must not contain `--` (this was the entire build breakage).
- **Before release:** run the harness on the merge candidate and, if a release build is intended, verify `flutter build appbundle --release` (requires a valid gitignored `android/key.properties`).
- **Keystore hygiene:** move `release-key.jks` / `release-keystore.jks` outside the repository tree if they are not already backed up in a secure location.

## 4. How to re-run the audit and the verification harness

**Scoring pass (recompute the weighted overall from the data):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/score.ps1
```

Reads `docs/audit/2026-09-15/scores.json`, validates the weights (must sum to 100%) and
score ranges, recomputes the weighted overall for both phases, cross-checks the findings ledger
for any open critical/high finding in a scored dimension, and prints the per-term arithmetic.
Exit 0 = consistent with the published 8.4 → 9.4.

**Verification pass (analyze + format + tests + Android build + secret sweep + dependency snapshot):**

```powershell
# full pass (analyze + format + tests + Android debug build + secret sweep + dependency snapshot)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/run-audit.ps1

# faster pass without the Android build
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/run-audit.ps1 -SkipBuild

# add a coverage measurement (~25 min)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit/run-audit.ps1 -WithCoverage
```

- Exit code `0` = every gate passed; `1` = at least one gate failed.
- Evidence is written to `.openclaw/tmp/audit/rerun/` (analyze, format, test, build, coverage, pub-outdated logs).
- Expected result on the repaired tree: analyze clean · 888/888 tests · format clean · APK builds · secret sweep clean.
- To re-derive the **scores**, re-read [01-rubric.md](01-rubric.md) and apply the anchors to whatever the harness reports; the arithmetic template is in [03-audit-report.md](03-audit-report.md#1-weighted-overall-score).

## 5. Reviewer checklist (goal-brief verification plan)

- [ ] Open each cited `file:line` in [03-audit-report.md](03-audit-report.md) and confirm the finding is real and correctly described.
- [ ] Recompute the weighted score from the five dimension scores → must equal 9.5.
- [ ] Reproduce AUD-004 by reverting `e7f3839` (`flutter build apk --debug` fails), then restore.
- [ ] Reproduce AUD-003/AUD-001 by checking out the parent of their commits and running the two test files.
- [ ] Cross-check the ledger against `git log 5ef935c..fix/audit-2026-09-15`: every `fixed` row has a commit, every fix commit maps to a row (verified: AUD-004→`e7f3839`, AUD-003→`ded0bb4`, AUD-001/002→`9884592`, AUD-006→`f8c6f45`, AUD-005→`e78ca6e`, AUD-010→`5d494ae`).
- [ ] Apply `docs/audit/2026-09-15/patches/*.patch` to `5fd16e9` and confirm the result matches the branch tip (proven byte-identical for lib/test/android).
- [ ] Run `scripts/audit/run-audit.ps1` on a clean checkout of the branch to prove the green result is not local state.
- [ ] Decide RESIDUAL-R1…R11 ([05-reaudit.md](05-reaudit.md#3-residual-risk-register)) — each has a one-line owner action.
- [ ] **AUD-015 (R11) — blocks cloning:** back up `.git/packed-refs`, resolve the duplicate `refs/heads/audit-remediation` definition (`447f645` loose vs `83fc99c` packed), re-sort the file, then `git pack-refs --all` + `git fsck --full`. Until then a fresh `git clone` of this repository fails, so CI cannot check it out greenfield.
- [ ] **AUD-014 (R10):** placeholder the anon key in `config/env.staging.json` (mirror `env.production.json`), keep the real key in `config/env.staging.local.json`, and rotate the staging anon key in the Supabase dashboard (it is in git history via `d50a181`).
- [ ] Re-run the secret sweep on history before publishing (`gitleaks detect` using the repo's `.gitleaks.toml`).

## 6. Known cosmetic items for the reviewer

- **The repository cannot currently be cloned** (`AUD-015`): `.git/packed-refs` is unsorted and defines `refs/heads/audit-remediation` twice. Work locally in the existing clone until it is fixed; the fix procedure is in `05-reaudit.md` → `RESIDUAL-R11`, and it must be owner-led because it touches `.git` internals.
- The snapshot commit `5fd16e9` also captured `.openclaw-attachments/` (two pasted-text files). Removing them from the index was blocked by a safety guard at the time; drop them when you squash or rebase the branch if you prefer.
- `.openclaw/tmp/audit/**` holds raw process logs and scratch exports (untracked, ignored).
- The harness's secret sweep initially flagged the committed staging token; the sweep is now role-aware (warn on `anon`, hard-fail on `service_role`). The warned state is expected until the owner completes the AUD-014 remediation above.
- Process transparency: during verification, one `git revert` dry-run executed in the working tree (a scratch clone failed for the reason above) and was aborted immediately; the tree was confirmed clean at `92b0cb4` afterwards, and the rollback was then proven properly with a file-level reverse-patch run (`04-verification.md` §10).
