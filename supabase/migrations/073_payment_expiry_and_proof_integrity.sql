BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.get_or_claim_paymob_payment_legacy_073(UUID)') IS NULL THEN
    IF to_regprocedure('public.get_or_claim_paymob_payment(UUID)') IS NOT NULL THEN
      ALTER FUNCTION public.get_or_claim_paymob_payment(UUID)
        RENAME TO get_or_claim_paymob_payment_legacy_073;
    END IF;
  END IF;
  IF to_regprocedure('public.process_paymob_callback_legacy_073(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)') IS NULL THEN
    IF to_regprocedure('public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)') IS NOT NULL THEN
      ALTER FUNCTION public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
        RENAME TO process_paymob_callback_legacy_073;
    END IF;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment_legacy_073(UUID)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.process_paymob_callback_legacy_073(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_or_claim_paymob_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = p_order_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;
  IF v_order.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;
  IF v_order.expires_at IS NOT NULL AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  RETURN public.get_or_claim_paymob_payment_legacy_073(p_order_id);
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_or_claim_paymob_payment(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.process_paymob_callback(
  p_paymob_order_id TEXT,
  p_paymob_txn_id TEXT,
  p_amount_cents INTEGER,
  p_currency TEXT,
  p_success BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order_id UUID;
  v_order RECORD;
BEGIN
  SELECT order_id
    INTO v_order_id
    FROM public.payments
   WHERE paymob_order_id = p_paymob_order_id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unmapped_payment');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = v_order_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;
  IF v_order.status = 'pending'
     AND v_order.expires_at IS NOT NULL
     AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_expired',
      'order_id', v_order.id
    );
  END IF;

  RETURN public.process_paymob_callback_legacy_073(
    p_paymob_order_id,
    p_paymob_txn_id,
    p_amount_cents,
    p_currency,
    p_success
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
  TO service_role;

CREATE OR REPLACE FUNCTION public.set_payment_provider_order_id_claim(
  p_payment_id UUID,
  p_paymob_order_id TEXT,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order_id UUID;
  v_order RECORD;
  v_payment RECORD;
  v_updated_id UUID;
BEGIN
  IF p_payment_id IS NULL
     OR p_claim_token IS NULL
     OR p_paymob_order_id IS NULL
     OR btrim(p_paymob_order_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT order_id
    INTO v_order_id
    FROM public.payments
   WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_found');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = v_order_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_found');
  END IF;
  IF v_order.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pending');
  END IF;
  IF v_order.expires_at IS NOT NULL AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  SELECT id, order_id, status, method, paymob_order_id,
         paymob_initiation_phase, paymob_initiation_claim_token
    INTO v_payment
    FROM public.payments
   WHERE id = p_payment_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_found');
  END IF;
  IF v_payment.status IS DISTINCT FROM 'pending'
     OR v_payment.method IS DISTINCT FROM 'paymob_card' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pending');
  END IF;
  IF v_payment.paymob_order_id IS NOT NULL THEN
    IF v_payment.paymob_order_id = btrim(p_paymob_order_id) THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_set',
        'paymob_order_id', btrim(p_paymob_order_id)
      );
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'claim_already_submitted');
  END IF;

  UPDATE public.payments
     SET paymob_order_id = btrim(p_paymob_order_id),
         paymob_initiation_phase = 'provider_persisted',
         updated_at = now()
   WHERE id = p_payment_id
     AND status = 'pending'
     AND paymob_initiation_claim_token = p_claim_token
     AND paymob_initiation_phase = 'provider_submitted'
     AND paymob_order_id IS NULL
   RETURNING id INTO v_updated_id;
  IF v_updated_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_matched');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'updated',
    'paymob_order_id', btrim(p_paymob_order_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id_claim(UUID,TEXT,UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id_claim(UUID,TEXT,UUID)
  TO service_role;

CREATE OR REPLACE FUNCTION public.review_instapay_proof(
  p_proof_id UUID,
  p_approve BOOLEAN,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_proof RECORD;
  v_payment RECORD;
  v_order RECORD;
  v_payment_id UUID;
  v_order_id UUID;
  v_storage_path TEXT;
  v_note TEXT;
  v_updated_id UUID;
  v_updated_order_id UUID;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;
  IF p_proof_id IS NULL OR p_approve IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;
  IF p_note IS NOT NULL AND char_length(p_note) > 2000 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_note');
  END IF;
  v_note := NULLIF(btrim(p_note), '');

  SELECT is_admin
    INTO v_is_admin
    FROM public.profiles
   WHERE id = v_admin;
  IF v_is_admin IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'admin_required');
  END IF;

  SELECT payment_id, storage_path, outcome
    INTO v_proof
    FROM public.instapay_proofs
   WHERE id = p_proof_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_not_found');
  END IF;
  IF v_proof.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;
  v_payment_id := v_proof.payment_id;
  v_storage_path := v_proof.storage_path;

  SELECT order_id
    INTO v_order_id
    FROM public.payments
   WHERE id = v_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = v_order_id
   FOR UPDATE;
  IF NOT FOUND OR v_order.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;
  IF v_order.expires_at IS NOT NULL AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  SELECT id, order_id, user_id, status, method
    INTO v_payment
    FROM public.payments
   WHERE id = v_payment_id
   FOR UPDATE;
  IF NOT FOUND
     OR v_payment.order_id IS DISTINCT FROM v_order.id
     OR v_payment.status IS DISTINCT FROM 'pending'
     OR v_payment.method IS DISTINCT FROM 'instapay' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;

  SELECT payment_id, storage_path, outcome
    INTO v_proof
    FROM public.instapay_proofs
   WHERE id = p_proof_id
   FOR UPDATE;
  IF NOT FOUND OR v_proof.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;
  IF v_proof.payment_id IS DISTINCT FROM v_payment_id
     OR v_proof.storage_path IS DISTINCT FROM v_storage_path THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_changed');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM storage.objects o
    WHERE o.bucket_id = 'instapay-proofs'
      AND o.name = v_storage_path
      AND (storage.foldername(o.name))[1] = v_payment.user_id::TEXT
      AND (storage.foldername(o.name))[2] = v_payment_id::TEXT
      AND o.metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
       AND COALESCE(o.metadata->>'size', o.metadata->>'contentLength') ~ '^[0-9]+$'
       AND (COALESCE(o.metadata->>'size', o.metadata->>'contentLength'))::BIGINT <= 5 * 1024 * 1024
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_storage_missing');
  END IF;

  UPDATE public.payments
     SET status = CASE WHEN p_approve THEN 'success' ELSE 'failed' END,
         transaction_id = CASE
           WHEN p_approve THEN 'instapay_' || p_proof_id::TEXT
           ELSE transaction_id
         END,
         updated_at = now()
   WHERE id = v_payment_id
     AND status = 'pending'
   RETURNING id INTO v_updated_id;
  IF v_updated_id IS NULL THEN
    RAISE EXCEPTION 'payment_not_pending' USING ERRCODE = 'P0001';
  END IF;

  IF p_approve THEN
    UPDATE public.orders
       SET status = 'paid',
           updated_at = now()
     WHERE id = v_order_id
       AND status = 'pending'
     RETURNING id INTO v_updated_order_id;
    IF v_updated_order_id IS NULL THEN
      RAISE EXCEPTION 'order_not_pending' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  UPDATE public.instapay_proofs
     SET outcome = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by = v_admin,
         reviewed_at = now(),
         note = v_note
   WHERE id = p_proof_id
     AND outcome IS NULL
   RETURNING id INTO v_updated_id;
  IF v_updated_id IS NULL THEN
    RAISE EXCEPTION 'proof_already_reviewed' USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'payment_id', v_payment_id,
    'order_id', v_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.review_instapay_proof(UUID,BOOLEAN,TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_instapay_proof(UUID,BOOLEAN,TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_variant(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_stock INTEGER,
  p_price_override NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM public.assert_admin();
  IF p_product_id IS NULL
     OR p_size IS NULL
     OR btrim(p_size) = ''
     OR p_color IS NULL
     OR btrim(p_color) = ''
     OR p_stock IS NULL
     OR p_stock < 0 THEN
    RAISE EXCEPTION 'invalid_variant' USING ERRCODE = '22023';
  END IF;
  IF p_price_override IS NOT NULL
     AND (p_price_override <= 0
          OR p_price_override::TEXT IN ('NaN', 'Infinity', '-Infinity')
          OR p_price_override <> trunc(p_price_override)) THEN
    RAISE EXCEPTION 'invalid_variant_price' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = p_product_id) THEN
    RAISE EXCEPTION 'product_not_found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.product_variants (product_id, size, color, stock, price_override)
  VALUES (p_product_id, btrim(p_size), btrim(p_color), p_stock, p_price_override::INTEGER)
  ON CONFLICT (product_id, size, color)
  DO UPDATE SET stock = EXCLUDED.stock, price_override = EXCLUDED.price_override
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_variant(UUID,TEXT,TEXT,INTEGER,NUMERIC)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_variant(UUID,TEXT,TEXT,INTEGER,NUMERIC)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_product_images(
  p_product_id UUID,
  p_paths TEXT[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.assert_admin();
  IF p_product_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.products WHERE id = p_product_id) THEN
    RAISE EXCEPTION 'product_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF p_paths IS NULL OR cardinality(p_paths) > 20 THEN
    RAISE EXCEPTION 'invalid_image_paths' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM unnest(p_paths) AS path
    WHERE path IS NULL
       OR btrim(path) = ''
       OR path !~ ('^product-images/' || p_product_id::TEXT || '/')
       OR (
         NOT EXISTS (
           SELECT 1
           FROM storage.objects o
           WHERE o.bucket_id = 'product-images'
             AND o.name = path
         )
         AND NOT EXISTS (
           SELECT 1
           FROM public.product_images existing
           WHERE existing.product_id = p_product_id
             AND existing.storage_path = path
         )
       )
  ) THEN
    RAISE EXCEPTION 'invalid_image_path' USING ERRCODE = '22023';
  END IF;
  IF cardinality(p_paths) <> (SELECT count(DISTINCT path) FROM unnest(p_paths) AS paths(path)) THEN
    RAISE EXCEPTION 'duplicate_image_path' USING ERRCODE = '22023';
  END IF;
  DELETE FROM public.product_images WHERE product_id = p_product_id;
  INSERT INTO public.product_images (product_id, storage_path, sort_order, is_primary)
  SELECT p_product_id, path, ordinality - 1, ordinality = 1
  FROM unnest(p_paths) WITH ORDINALITY AS paths(path, ordinality);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_product_images(UUID,TEXT[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_product_images(UUID,TEXT[])
  TO authenticated;

COMMIT;

