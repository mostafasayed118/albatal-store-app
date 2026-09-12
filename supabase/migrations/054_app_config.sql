-- 054_app_config.sql (feature-batch §13 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Remote configuration: a flat key/value table readable by any client
-- (values are non-sensitive: feature flags, maintenance mode, minimum
-- supported version). Writes are admin-only.

CREATE TABLE IF NOT EXISTS public.app_config (
  key        text PRIMARY KEY,
  value      text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_config_read ON public.app_config
  FOR SELECT USING (true);

CREATE POLICY app_config_admin_write ON public.app_config
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );

-- Sensible starting keys (values reviewed at deploy time):
INSERT INTO public.app_config (key, value) VALUES
  ('maintenance_mode', 'false'),
  ('min_supported_version', '0.0.0')
ON CONFLICT (key) DO NOTHING;
