-- ============================================================
-- Shipping zones and delivery fee calculation
-- ============================================================

-- Shipping zones table
CREATE TABLE shipping_zones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  governorates TEXT[] NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0 CHECK (fee >= 0),
  estimated_days_min INTEGER NOT NULL DEFAULT 1,
  estimated_days_max INTEGER NOT NULL DEFAULT 3,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Free shipping threshold
CREATE TABLE shipping_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Default config
INSERT INTO shipping_config (key, value) VALUES
  ('free_shipping_threshold', '50000'),
  ('default_fee', '7500'),
  ('default_days_min', '1'),
  ('default_days_max', '3');

-- Default zones for Egypt
INSERT INTO shipping_zones (name, governorates, fee, estimated_days_min, estimated_days_max) VALUES
  ('Cairo & Giza', ARRAY['Cairo', 'Giza'], 5000, 1, 2),
  ('Alexandria', ARRAY['Alexandria'], 6000, 1, 2),
  ('Delta', ARRAY['Dakahlia', 'Sharqia', 'Gharbia', 'Monufia', 'Qalyubia', 'Beheira', 'Kafr El Sheikh'], 7000, 2, 3),
  ('Upper Egypt', ARRAY['Minya', 'Assiut', 'Sohag', 'Qena', 'Luxor', 'Aswan'], 8000, 3, 5),
  ('Canal Cities', ARRAY['Ismailia', 'Port Said', 'Suez'], 7000, 2, 3),
  ('Sinai', ARRAY['North Sinai', 'South Sinai'], 10000, 4, 7),
  ('Matrouh & Red Sea', ARRAY['Matrouh', 'Red Sea'], 9000, 3, 5);

-- RLS
ALTER TABLE shipping_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_config ENABLE ROW LEVEL SECURITY;

-- Public read for active zones
CREATE POLICY "shipping_zones_select_public"
  ON shipping_zones FOR SELECT
  USING (is_active = true);

CREATE POLICY "shipping_config_select_public"
  ON shipping_config FOR SELECT
  USING (true);

-- Function to calculate shipping fee
CREATE OR REPLACE FUNCTION calculate_shipping_fee(
  p_governorate TEXT,
  p_subtotal INTEGER
)
RETURNS INTEGER AS $$
DECLARE
  v_threshold INTEGER;
  v_fee INTEGER;
BEGIN
  -- Check free shipping threshold
  SELECT value::INTEGER INTO v_threshold
  FROM shipping_config WHERE key = 'free_shipping_threshold';

  IF p_subtotal >= v_threshold THEN
    RETURN 0;
  END IF;

  -- Look up zone fee
  SELECT sz.fee INTO v_fee
  FROM shipping_zones sz
  WHERE p_governorate = ANY(sz.governorates)
    AND sz.is_active = true
  LIMIT 1;

  IF v_fee IS NULL THEN
    -- Default fee
    SELECT value::INTEGER INTO v_fee
    FROM shipping_config WHERE key = 'default_fee';
  END IF;

  RETURN v_fee;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
