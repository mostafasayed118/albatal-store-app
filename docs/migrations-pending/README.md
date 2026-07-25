# Migrations Pending — Reference Only

This directory contains migration drafts that are **NOT applied** to any environment.

These files are preserved for reference only. They are not executed by Supabase CLI tooling.

## Purpose

- Document local migration drafts that conflicted with applied migrations
- Provide context for the canonical forward repair migration (026)
- Preserve history of attempted fixes

## Rules

- Do NOT apply these migrations to staging or production
- Do NOT rename or renumber these files
- The canonical repair migration is in `supabase/migrations/026_*.sql`
