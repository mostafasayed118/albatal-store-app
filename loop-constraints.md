# Loop Constraints — Al Batal Elite

> Add rules below with `/constraints <rule>` in your agent.
> The `loop-constraints` skill reads this file at the start of every run.
> Constraints here are **binding** — the agent MUST follow them.

## Push & Merge
- Don't push before telling me
- Never auto-merge to main without human approval
- Always create a draft PR first; let me review before marking ready

## Paths — Never Edit
- `.env`, `.env.*` (except `.env.example`)
- `supabase/` migrations without human review
- `auth/`, `payments/`, `secrets/`, `credentials/`
- `android/key.properties`, `*.keystore`, `*.jks`
- `ios/Pods/`, `macos/Pods/`
- `lib/generated/`, `*.g.dart`, `*.freezed.dart`

## Paths — Auto-Fix Scope
- Auto-fixes are limited to `lib/` directory only
- Do not modify `pubspec.yaml` without human approval
- Do not modify CI/CD workflows (`.github/workflows/`) without human approval
- Do not modify `analysis_options.yaml` without human approval

## Flutter-Specific
- Never run `flutter pub upgrade` without human approval — suggest `flutter pub outdated` first
- Never modify `pubspec.lock` directly — let `flutter pub get` handle it
- Always run `flutter analyze` before `flutter test` to catch static issues first
- Do not add new dependencies without explaining why and listing alternatives
- Do not change BLoC/Cubit state class signatures without human approval
- Do not modify `GoRouter` route definitions without human review
- Do not touch `supabase/` SQL functions or RLS policies without human review
- Respect Clean Architecture layer boundaries — no bypassing layers

## Code Quality
- Always run tests before proposing a fix
- Never disable tests to make CI green
- Never refactor unrelated code — one fix per run
- Max 3 fix attempts per item; escalate after
- Enforce the attempt limit mechanically: log each try to `loop-ledger.json`

## Communication
- Always tell me what you're about to do before doing it
- Never close an issue or PR without my approval
- After meaningful changes, offer a learning walkthrough (per INSTRUCTIONS.md Section A)

## Budget
- If token spend hits 80% of daily cap, switch to report-only
- If loop-pause-all is active, exit immediately

---
<!-- Add your own rules below. Use plain English. The loop reads this verbatim. -->
