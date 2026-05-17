-- Phase 3: Manual finance system migration
-- Adds payment_method, receipt_url, updated_at, approved_by, rejected_by to donations
-- Creates withdrawals table for NGO wallet withdrawals

ALTER TABLE donations
  ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) NOT NULL DEFAULT 'BANK_TRANSFER',
  ADD COLUMN IF NOT EXISTS receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS approved_by INT REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS rejected_by INT REFERENCES users(id);

-- Normalize existing status values to new enum set
UPDATE donations SET status = 'CONFIRMED' WHERE status = 'COMPLETED';
UPDATE donations SET status = 'REJECTED'  WHERE status IN ('FAILED', 'REFUNDED');

CREATE TABLE IF NOT EXISTS withdrawals (
  id             SERIAL PRIMARY KEY,
  ngo_user_id    INT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  bank_account   TEXT         NOT NULL,
  status         VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
  approved_by    INT          REFERENCES users(id),
  rejected_by    INT          REFERENCES users(id),
  approved_at    TIMESTAMPTZ,
  rejected_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ  DEFAULT NOW(),
  updated_at     TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawals_ngo_user ON withdrawals(ngo_user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status   ON withdrawals(status);
