-- ============================================================
-- Migration 060: Edge-function rate limiting (audit 2026-09-13)
--
-- Backs the shared `_shared/rate_limit.ts` helper: one atomic
-- INSERT .. ON CONFLICT per check, SECURITY DEFINER so the
-- edge functions (user-scoped or service-role clients) can take
-- a token without any table grants.
--
-- DEPLOY GATE: human review + staging apply first (041/046
-- precedent). No client behavior changes until the functions
-- that call rate_limit_take are deployed.
-- ============================================================

create table if not exists public.rate_limits (
  bucket     text   not null,
  window_id  bigint not null,
  count      bigint not null default 0,
  primary key (bucket, window_id)
);

comment on table public.rate_limits is
  'Per-caller rate-limit counters for edge functions (migration 060). '
  'One row per (bucket, window); windows are epoch / window_seconds.';

-- No client ever reads the table directly: all access goes through
-- the SECURITY DEFINER function below.
revoke all on public.rate_limits from anon, authenticated, public;

create or replace function public.rate_limit_take(
  p_bucket          text,
  p_limit           int,
  p_window_seconds  int
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window bigint :=
    extract(epoch from now())::bigint / greatest(p_window_seconds, 1);
begin
  -- Atomic take: insert the window row on first sight, else bump the
  -- counter only while the budget lasts. `found` is false once the
  -- window's budget is exhausted -> the caller returns 429.
  insert into public.rate_limits (bucket, window_id, count)
    values (p_bucket, v_window, 1)
    on conflict (bucket, window_id)
    do update set count = public.rate_limits.count + 1
    where public.rate_limits.count < p_limit;
  return found;
end;
$$;

-- Every authenticated edge-function caller (user-scoped clients) may
-- take a token; anon must never reach it (functions authenticate
-- before checking). Service-role bypasses grants by design.
revoke all on function public.rate_limit_take(text, int, int) from public, anon;
grant execute on function public.rate_limit_take(text, int, int) to authenticated;

-- Housekeeping: windows older than 48h are dead weight. Cheap enough
-- to prune opportunistically whenever a take lands in a fresh window.
create or replace function public.rate_limit_prune()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.rate_limits
  where window_id < extract(epoch from now())::bigint - 172800;
end;
$$;

revoke all on function public.rate_limit_prune() from public, anon, authenticated;
