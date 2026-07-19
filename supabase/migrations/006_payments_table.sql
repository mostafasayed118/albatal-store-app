-- ============================================================
-- Payments table for tracking payment transactions
-- Run AFTER 005_storage_buckets.sql
-- ============================================================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  method TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  phone_number TEXT,
  transaction_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_transaction ON payments(transaction_id);
CREATE INDEX idx_payments_status ON payments(status);

-- RLS policies
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Users can read only their own payments
CREATE POLICY "payments_select_own"
  ON payments FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own payments
CREATE POLICY "payments_insert_own"
  ON payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Updated_at trigger
CREATE TRIGGER set_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
