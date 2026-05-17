-- Phase B3: Beneficiary Feedback System
-- Purely observational signal from the aid recipient

CREATE TABLE IF NOT EXISTS beneficiary_feedback (
    id SERIAL PRIMARY KEY,
    delivery_id INT NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    beneficiary_id INT NOT NULL REFERENCES users(id),
    confirmation_status VARCHAR(20) NOT NULL, -- 'RECEIVED', 'NOT_RECEIVED', 'PARTIAL'
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(delivery_id)
);

CREATE INDEX idx_beneficiary_feedback_delivery ON beneficiary_feedback(delivery_id);
CREATE INDEX idx_beneficiary_feedback_beneficiary ON beneficiary_feedback(beneficiary_id);
