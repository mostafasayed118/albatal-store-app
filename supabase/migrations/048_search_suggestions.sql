-- 048_search_suggestions.sql (feature-batch §7 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Server-side fuzzy search suggestions for the catalog search bar.
-- The client ships a pure client-side fallback (suggestProductNames)
-- so the UX works before this migration is applied; once applied,
-- the storefront can switch to the RPC for cross-catalog fuzzy recall.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON public.products USING gin (name gin_trgm_ops);

-- Returns up to `limit` distinct product names that fuzzily match the
-- query, best (most similar) first. Exact matches are excluded — they
-- are already the primary search results. RLS: reads via the anon-
-- readable products table, no customer PII involved.
CREATE OR REPLACE FUNCTION public.search_suggestions(
  q text,
  lim integer DEFAULT 5
)
RETURNS TABLE (name text)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT p.name
  FROM public.products p
  WHERE p.name ILIKE '%' || q || '%'
    AND lower(p.name) <> lower(trim(q))
    AND similarity(p.name, trim(q)) > 0.1
  ORDER BY similarity(p.name, trim(q)) DESC
  LIMIT lim;
$$;

-- The RPC is intentionally read-only and invoker-scoped; no grants to
-- service_role changes needed. Expose to anon + authenticated:
GRANT EXECUTE ON FUNCTION public.search_suggestions(text, integer)
  TO anon, authenticated;
