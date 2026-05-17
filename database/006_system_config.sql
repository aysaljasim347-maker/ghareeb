-- Phase 6: System Configuration Table
-- Persistent key/value store for system-level settings.
-- Currently used to survive system state (NORMAL/HIGH_LOAD/DISASTER_MODE/LOCKDOWN) across restarts.

CREATE TABLE IF NOT EXISTS system_config (
    key        VARCHAR(100) PRIMARY KEY,
    value      JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
