-- 075 — Wishlist sync (owner-reviewed + approved 2026-09-27).
--
-- ADOPTS the 001-era `public.wishlists` table instead of creating its own:
-- remote already has `wishlists(id, user_id→profiles CASCADE,
-- product_id→products CASCADE, created_at, UNIQUE(user_id, product_id))`
-- with owner-only SELECT/INSERT/DELETE policies and live rows. This
-- migration only ADDS (all idempotent):
--   * index on (user_id, created_at DESC) for the merge RPC's ordering,
--   * 200-row per-user cap (helper + CHECK backstop, RPC trims),
--   * `public.sync_wishlist(UUID[])` — atomic union-merge RPC.
--
-- Conventions follow 046 (membership tier) / 069 (review security):
-- BEGIN/COMMIT, idempotent guards, functions SECURITY DEFINER with locked
-- search_path + REVOKE/GRANT.
--
-- Client (separate change, branch fix/batch3-wishlist-075):
-- `SupabaseWishlistRepository` implements the existing `WishlistRepository`
-- port; on sign-in union-merge local + remote (local wins), then push via
-- `sync_wishlist`. Product deletions prune as tombstones, not errors.
-- Guest (signed-out) flow keeps using `LocalWishlistRepository` untouched.

BEGIN;

-- Fail closed with a clear message when the 001 table is absent (fresh
-- environment that never applied the initial schema).
DO $$
BEGIN
  IF to_regclass('public.wishlists') IS NULL THEN
    RAISE EXCEPTION 'public.wishlists is missing (001 not applied)';
  END IF;
END;
$$;

-- Cap: at most 200 wishlist rows per user. Enforced by the CHECK via a
-- helper so direct INSERTs (not just the RPC) are bounded too.
CREATE OR REPLACE FUNCTION public.wishlist_count_for_user(p_user_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT COUNT(*)::INTEGER FROM public.wishlists WHERE user_id = p_user_id;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'wishlists_per_user_cap_check'
      AND conrelid = 'public.wishlists'::regclass
  ) THEN
    ALTER TABLE public.wishlists
      ADD CONSTRAINT wishlists_per_user_cap_check
      CHECK (public.wishlist_count_for_user(user_id) <= 200);
  END IF;
END;
$$;

-- The legacy table already orders by `created_at`; the RPC pages newest
-- first, so index that shape (IF NOT EXISTS — safe to re-run).
CREATE INDEX IF NOT EXISTS wishlists_user_created_idx
  ON public.wishlists (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- RLS: the 001-era `wishlists_{select,insert,delete}_own` policies
-- (`auth.uid() = user_id`) already cover direct access. Only if an
-- environment lacks them, install the equivalent single owner policy.
-- No admin read (preference data). No UPDATE policy by design: the RPC
-- below uses ON CONFLICT DO NOTHING, never an in-place update.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF (
    SELECT COUNT(*) FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'wishlists'
      AND policyname IN (
        'wishlists_select_own',
        'wishlists_insert_own',
        'wishlists_delete_own'
      )
  ) != 3 THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'wishlists'
        AND policyname = 'wishlists owner all'
    ) THEN
      CREATE POLICY "wishlists owner all"
        ON public.wishlists FOR ALL
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    END IF;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- sync_wishlist: atomic union-merge. Inserts the caller's product ids that
-- are not already present (UNIQUE(user_id, product_id) + ON CONFLICT DO
-- NOTHING ⇒ idempotent re-login). Unknown ids (stale local cache, deleted
-- products) are ignored, never stored; deleted products vanish via FK
-- CASCADE. Nothing the user still wants is ever removed by a sync — an
-- empty input PULLs, it does not wipe.
--
-- Returns the merged id set so the client can reconcile in one round trip.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_wishlist(p_product_ids UUID[])
RETURNS UUID[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_ids UUID[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  -- Ignore NULL/empty input: still return the current server set so the
  -- client can reconcile (e.g. fresh login with an empty local list must
  -- PULL, not wipe).
  IF p_product_ids IS NOT NULL AND array_length(p_product_ids, 1) > 0 THEN
    -- Deterministic cap: only the first N ids that fit in the remaining
    -- slots are attempted (input order = client recency order). The table
    -- CHECK above is a best-effort backstop for the direct-INSERT path;
    -- concurrent syncs can race past either, which merely overshoots a
    -- soft 200-row UX bound (no security impact: owner-only rows).
    INSERT INTO public.wishlists (user_id, product_id)
    SELECT v_user_id, u.pid
    FROM unnest(p_product_ids) WITH ORDINALITY AS u(pid, n)
    WHERE u.pid IS NOT NULL
      AND EXISTS (SELECT 1 FROM public.products p WHERE p.id = u.pid)
    ORDER BY u.n
    LIMIT GREATEST(
      200 - (SELECT COUNT(*) FROM public.wishlists WHERE user_id = v_user_id),
      0
    )
    ON CONFLICT (user_id, product_id) DO NOTHING;
  END IF;

  SELECT COALESCE(array_agg(product_id ORDER BY created_at DESC), '{}')
    INTO v_ids
    FROM public.wishlists
    WHERE user_id = v_user_id;

  RETURN v_ids;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_wishlist(UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_wishlist(UUID[]) TO authenticated;

REVOKE ALL ON FUNCTION public.wishlist_count_for_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wishlist_count_for_user(UUID) TO authenticated;

COMMIT;
