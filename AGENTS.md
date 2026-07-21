# AGENTS.md — Opencode Minimal Loop

These rules are loaded by opencode before loop work.

## Project Context

- **App:** Al Batal Elite — premium fabric-commerce Flutter app
- **Stack:** Flutter 3.x, Dart 3.x, BLoC/Cubit, GetIt, GoRouter, Supabase
- **Architecture:** Feature-first Clean Architecture (presentation → domain → data)
- **Conventions:** See `INSTRUCTIONS.md` (role, code quality, testing, security rules)
- **Design System:** See `DESIGN.md` (emerald/gold palette, Montserrat/Inter typography)

## Loop Mode

- Start in L1 report-only mode.
- Read `STATE.md` before any triage.
- Update `STATE.md` after every loop run.
- Do not edit source code until the human explicitly enables L2.

## Safety

- Never push or merge without human approval.
- Never edit `.env`, `.env.*`, `auth/`, `payments/`, `secrets/`, or `credentials/`.
- Never modify `supabase/` migrations without human review.
- Use a git worktree for every code-changing attempt.
- Max 3 fix attempts per item; escalate after that.

## Scope

- Auto-fixes are limited to `lib/` directory only.
- Do not modify `pubspec.yaml` without human approval.
- Do not modify CI/CD workflows without human approval.
- Stay within feature-first Clean Architecture boundaries.

## Verification

- For L2+ changes, dispatch a verifier sub-agent after implementation.
- Run `flutter test` and `flutter analyze` before proposing a fix.
- Record test evidence in `STATE.md`.
- Do not claim code works unless tests were run.

## Reference Files

- `INSTRUCTIONS.md` — Full project conventions (role, architecture, code quality, testing)
- `DESIGN.md` — Design system tokens and component specs
- `STATE.md` — Current loop state (updated every run)
- `LOOP.md` — Loop configuration and human gates
- `loop-constraints.md` — Binding safety rules
- `loop-budget.md` — Token and run limits
