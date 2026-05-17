-- Phase 4: Audit & Accountability System
-- Tracks administrative actions for transparency and traceability

CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    admin_id INT NOT NULL REFERENCES users(id),
    action_type VARCHAR(50) NOT NULL, -- e.g., 'APPROVE_DONATION', 'REJECT_WITHDRAWAL', 'UPDATE_CAMPAIGN_STATUS'
    target_entity VARCHAR(50) NOT NULL, -- e.g., 'donations', 'withdrawals', 'campaigns'
    target_id INT NOT NULL,
    metadata JSONB, -- stores details like old_status, new_status, reason, etc.
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_admin_id ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action_type);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_entity, target_id);
