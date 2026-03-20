-- Add Stripe tracking to subscriptions
ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS stripe_session_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;
