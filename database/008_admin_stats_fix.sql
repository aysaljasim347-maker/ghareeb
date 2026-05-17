-- Migration: Add missing metadata columns for admin stats and flagging
-- Purpose: Fix 500 errors on dashboard and enable dispute/flag functionality

ALTER TABLE donations ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE withdrawals ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
