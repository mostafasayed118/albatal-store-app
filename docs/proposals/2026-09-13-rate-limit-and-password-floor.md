# Proposal — Edge-function rate limiting + GoTrue password floor

**Status: IMPLEMENTED on fix/audit-followup-0913 (owner-approved). DEPLOY GATED: migration 060 needs human-reviewed db push (staging first), then the four wired functions deploy; the GoTrue dashboard minimum-password setting must be raised to 8 server-side.** Both items sit behind the
`supabase/` and server-config gates (loop-constraints.md). Staged here
from the 2026-09-13 audit (security findings #1 and #5) so an approved
slice can apply them verbatim.

## 1. Rate limiting for edge functions

**Finding.** None of the 8 deployed functions throttle callers.
Unauthenticated hammering of `paymob-callback` burns function quota
(each request parses a body and computes an HMAC-SHA512), and any
authenticated user holding a pending InstaPay payment can spam
`instapay-submit-proof` with repeated 5 MB uploads (no per-payment
proof cap; the 24 h expiry marks the payment expired but never deletes
proof objects).

**Fix shape — per-caller atomic counter in Postgres:**

Migration `06X_rate_limits.sql` (run after backup, human-gated):

```sql
create table if not exists public.rate_limits (
  bucket     text    not null,          -- e.g. 'proof:user:<uuid>'
  window_id  bigint  not null,          -- epoch / window_seconds
  count      bigint  not null default 0,
  primary key (bucket, window_id)
);
revoke all on public.rate_limits from anon, authenticated;

create or replace function public.rate_limit_take(
  p_bucket text, p_limit int, p_window_seconds int
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_window bigint := extract(epoch from now())::bigint / p_window_seconds;
begin
  insert into public.rate_limits (bucket, window_id, count)
  values (p_bucket, v_window, 1)
  on conflict (bucket, window_id)
    do update set count = rate_limits.count + 1
    where rate_limits.count < p_limit;
  return found;   -- false once the window's budget is exhausted
end;
$$;
```

Edge-function wiring (each function, before any work):

```ts
const ok = await admin.rpc('rate_limit_take', {
  p_bucket: `proof:user:${user.id}`, p_limit: 10, p_window_seconds: 3600,
});
if (!ok) return json({ error: 'rate_limited' }, 429);
```

Suggested buckets: `proof:user:<id>` 10/h (instapay-submit-proof),
`cb:ip:<ip>` 60/h (paymob-callback), `init:user:<id>` 20/h
(instapay-initiate), `acct:ip:<ip>` 5/h (delete-account). Also cap
`instapay_proofs` rows per payment (`where payment_id = X`) to ≤ 5 in
`instapay-submit-proof`, and add a cleanup step to
`expire_stale_instapay_payments` deleting expired proof objects.

Also update the Deno contract tests in `supabase/tests/` for the 429
paths, and the SQL contract test pinning the function's SECURITY
DEFINER/REVOKE shape (041/046 pattern).

## 2. GoTrue minimum password length

**Finding.** The server accepts 6-character passwords (Supabase
default; the client enforces 8 — `sign_up_page.dart`), so a direct
API caller can create a weak credential.

**Fix (one setting, no code):** Supabase dashboard → Authentication →
Policies → Minimum password length → **8** (or
`auth.min_password_length = 8` in `supabase/config.toml` for local +
IaC parity). Optional hardening: enable the leaked-password-protection
toggle (already staged in the 09-08 batch's deploy notes).

Client-side `supabase_auth_repository.dart:171` maps the GoTrue
6-char message; after the change the message becomes 8 — keep the
mapper tolerant of both strings or match on the `weak_password` code.

## Order of operations (when approved)

1. Backup → apply `06X_rate_limits.sql` (staging first, per 041/046
   precedent) → deploy the 4 wired functions → Deno suite + contract
   tests → prod.
2. Dashboard/config.toml password-length change is instant and
   reversible; flip it any time.
