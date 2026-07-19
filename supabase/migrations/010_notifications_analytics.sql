-- ============================================================
-- Notifications and Analytics tables
-- Run AFTER 009_shipping_zones.sql
-- ============================================================

-- Notifications table
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  recipient_email TEXT NOT NULL,
  recipient_name TEXT,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed', 'pending')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_order ON notifications(order_id);
CREATE INDEX idx_notifications_type ON notifications(type);

-- Analytics events table
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event TEXT NOT NULL,
  properties JSONB DEFAULT '{}',
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_analytics_event ON analytics_events(event);
CREATE INDEX idx_analytics_user ON analytics_events(user_id);
CREATE INDEX idx_analytics_created ON analytics_events(created_at);

-- Error logs table
CREATE TABLE error_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message TEXT NOT NULL,
  context TEXT,
  error TEXT,
  stack_trace TEXT,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  environment TEXT NOT NULL DEFAULT 'production',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_error_logs_created ON error_logs(created_at);
CREATE INDEX idx_error_logs_environment ON error_logs(environment);

-- RLS policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- Users can read their own notifications
CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (auth.uid() = (
    SELECT user_id FROM orders WHERE id = notifications.order_id
  ));

-- Service role can insert notifications
CREATE POLICY "notifications_insert_service"
  ON notifications FOR INSERT
  WITH CHECK (true);

-- Service role can insert analytics events
CREATE POLICY "analytics_insert_service"
  ON analytics_events FOR INSERT
  WITH CHECK (true);

-- Service role can insert error logs
CREATE POLICY "error_logs_insert_service"
  ON error_logs FOR INSERT
  WITH CHECK (true);

-- Admins can read all analytics and error logs
CREATE POLICY "admin_select_analytics"
  ON analytics_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

CREATE POLICY "admin_select_errors"
  ON error_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );
