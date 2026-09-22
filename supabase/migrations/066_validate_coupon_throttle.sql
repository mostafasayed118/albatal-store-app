-- ============================================================
-- 066_validate_coupon_throttle.sql (audit 2026-09-21, security MEDIUM)
-- REVIEW-GATED PROPOSAL — owner review required before applying
-- (AGENTS.md migration gate). Prepared 2026-09-22; not applied.
--
-- Closes the unauthenticated coupon-enumeration oracle:
--   * `validate_coupon` was GRANTed to `anon` with no rate limit, so any
--     unauthenticated caller could enumerate live promo codes
--     (code shape + discount amounts) at wire speed.
--   * The app only ever calls it from the checkout flow, which the
--     router's redirect policy already gates behind sign-in — so the
--     `anon` grant served no legitimate caller.
--
-- Deltas (vs the 056 definition):
--   1. REVOKE EXECUTE from `anon` — the RPC now requires a session.
--   2. Per-caller throttling through the 060 rate-limit infrastructure
--      (`rate_limit_take`, SECURITY DEFINER, 10 takes / 60s / caller).
--      A throttled caller gets a generic P0001 error, which the client
--      maps to the existing fail-soft `coupon_invalid` — no oracle leak
--      in the error channel either.
--   3. LANGUAGE sql STABLE -> plpgsql VOLATILE (the rate-limit take is a
--      write; the planner contract for SELECT-only functions no longer
--      holds).
--
-- NOTE FOR REVIEWER: if `create_checkout_order` resolves coupons by
-- calling this function internally (056 reviewer-notes delta), order
-- creation takes from the same bucket. 10/min per caller comfortably
-- covers checkout + manual validation; raise the limit here if the
-- review prefers headroom.
--
-- DEPLOY GATE: human review + staging apply first (060 precedent).
-- Verify after apply: `select has_function_privilege('anon',
-- 'public.validate_coupon(text)', 'execute')` must be false.
-- ============================================================

-- 1. The anonymous oracle closes here.
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM anon;

-- 2. Throttled body: same columns, same fail-soft semantics.
CREATE OR REPLACE FUNCTION public.validate_coupon(p_code text)
RETURNS TABLE (code text, discount_minor integer, description text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Per-caller throttle (audit 2026-09-21): 10 validations / minute /
  -- authenticated caller. auth.uid() reads the request JWT claims even
  -- under SECURITY DEFINER. The caller is guaranteed authenticated by
  -- the REVOKE above; the coalesce keeps the bucket key non-null.
  IF NOT public.rate_limit_take(
         'validate_coupon:' || coalesce(auth.uid()::text, 'anon'),
         10, 60) THEN
    RAISE EXCEPTION 'validate_coupon rate limited' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
    SELECT c.code, c.discount_minor, c.description
    FROM public.coupons c
    WHERE upper(trim(c.code)) = upper(trim(p_code))
      AND c.active
      AND (c.expires_at IS NULL OR c.expires_at > now())
    LIMIT 1;
END;
$$;

-- Grant shape after the change: authenticated callers only.
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.validate_coupon(text) TO authenticated;
