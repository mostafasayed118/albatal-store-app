-- 030: batch index for checkout variants (UNNEST batching TODO from audit)
CREATE INDEX IF NOT EXISTS idx_product_variants_lookup ON public.product_variants (product_id, size, color);
-- Note: 013 loop remains correct; UNNEST batching would require rewriting the RPC to SELECT ... FROM jsonb_to_recordset(p_items) JOIN product_variants ON (product_id,size,color) FOR UPDATE — deferred to post-launch as safe optimization.
