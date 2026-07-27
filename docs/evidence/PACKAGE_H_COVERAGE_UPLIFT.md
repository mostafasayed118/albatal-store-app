# PACKAGE H — COVERAGE UPLIFT (FOLLOW-UP, NOT AUTHORIZED)

Status: PROPOSED / NOT AUTHORIZED
Created by: Package G (2026-07-27)
Gate type: RELEASE-QUALITY gate (NOT a staging-freeze gate)

## Goal

Restore the CI line-coverage threshold from the interim **40%** floor back to
the production target of **70%** before beta or production release.

## Context

Package G set an interim coverage threshold of 40% in `.github/workflows/ci.yml`
because current coverage is ~41.07% (LINES_HIT=1925 / LINES_FOUND=4687) while all
198 tests pass. The interim floor prevents regression but is explicitly temporary.

## Likely scope (to be refined when authorized)

- Add Supabase data-layer tests (repositories, mappers)
- Add Paymob service tests (initiate/callback flows, HMAC validation paths)
- Add checkout service tests (order creation, COD/online branching)
- Add orders repository tests
- Add RLS / runtime denial tests
- Add Edge Function integration tests
- Add missing cubit/state tests for uncovered presentation logic

## Exit criteria

- Line coverage >= 70% on the candidate branch.
- Restore `ci.yml` coverage threshold from 40 to 70 and remove the interim comment.
- All tests green; analyze clean; format clean.

## Notes

- Package H is a follow-up quality gate; it does NOT block the staging-candidate
  freeze. Release verdict remains NO-GO independently until staging and live
  evidence gates pass.
- Package H is NOT authorized yet. Do not begin test authoring under this package
  without explicit human approval.
