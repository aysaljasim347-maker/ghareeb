-- ============================================================
-- DisasterAid V2.1 — Comprehensive QA Seed Dataset
-- Focus: Edge Cases, Financial Integrity, and Full Lifecycle
-- ============================================================

BEGIN;

-- 1. CLEANUP (Optional - use with caution in shared DB)
-- TRUNCATE ledger_entries, audit_logs, chat_messages, chat_rooms, donations, withdrawals, deliveries, task_events, tasks, campaigns, volunteer_profiles, ngo_profiles, users CASCADE;

-- 2. USERS (Multi-Role Matrix)
-- Password for all: 'password123'
-- Hash: $2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u

INSERT INTO users (id, name, email, password_hash, role_id, status) VALUES
-- These admins (id 100, 101) are test/admin accounts for QA
(100, 'Super Admin', 'super@disasteraid.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 6, 'ACTIVE'),
(101, 'Finance Admin', 'finance@disasteraid.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 6, 'ACTIVE'),

-- NGOs
(200, 'Red Cross PK', 'contact@redcross.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 4, 'ACTIVE'),
(201, 'Edhi Foundation', 'info@edhi.org', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 4, 'ACTIVE'),
(202, 'Saylani Trust', 'saylani@trust.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 4, 'ACTIVE'),
(203, 'Al-Khidmat', 'alkhidmat@service.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 4, 'ACTIVE'),
(204, 'Shadow NGO', 'shadow@ngo.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 4, 'SUSPENDED'),

-- Volunteers
(300, 'Ahmed Khan', 'ahmed@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(301, 'Sara Bibi', 'sara@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(302, 'John Doe', 'john@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(303, 'Idle Volunteer', 'idle@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(304, 'Suspended Vol', 'bad@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'SUSPENDED'),
(305, 'Active V5', 'v5@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(306, 'Active V6', 'v6@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(307, 'Active V7', 'v7@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(308, 'Active V8', 'v8@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),
(309, 'Active V9', 'v9@volunteer.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 3, 'ACTIVE'),

-- Beneficiaries
(400, 'Zia Flood Victim', 'zia@needs.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 2, 'ACTIVE'),
(401, 'Fatima Medical', 'fatima@needs.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 2, 'ACTIVE'),
(402, 'B3 Refugee', 'b3@needs.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 2, 'ACTIVE'),
(403, 'B4 Orphanage', 'b4@needs.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 2, 'ACTIVE'),
(404, 'B5 Remote Area', 'b5@needs.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 2, 'ACTIVE'),

-- Donors
(500, 'Whale Donor', 'rich@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(501, 'Micro Donor 1', 'm1@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(502, 'Micro Donor 2', 'm2@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(503, 'Recurring D3', 'd3@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(504, 'D4 Anonymous', 'd4@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(505, 'D5', 'd5@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(506, 'D6', 'd6@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(507, 'D7', 'd7@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(508, 'D8', 'd8@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),
(509, 'D9', 'd9@donor.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 1, 'ACTIVE'),

-- Coordinators
(600, 'Field Lead C1', 'c1@field.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 5, 'ACTIVE'),
(601, 'Audit Lead C2', 'c2@field.pk', '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u', 5, 'ACTIVE')
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name, 
    email = EXCLUDED.email, 
    role_id = EXCLUDED.role_id, 
    status = EXCLUDED.status,
    password_hash = EXCLUDED.password_hash;

-- Update password hashes manually for seeded users
UPDATE users SET password_hash = '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u' WHERE id >= 100;

-- 3. PROFILES
INSERT INTO ngo_profiles (id, user_id, org_name, wallet_balance, status) VALUES
(1, 200, 'Red Cross PK', 500000.00, 'ACTIVE'),
(2, 201, 'Edhi Foundation', 1250000.50, 'ACTIVE'),
(3, 202, 'Saylani Trust', 0.00, 'ACTIVE'), -- Edge case: Zero balance
(4, 203, 'Al-Khidmat', 75000.00, 'ACTIVE'),
(5, 204, 'Shadow NGO', 10.00, 'PENDING') -- Edge case: Pending verification
ON CONFLICT (id) DO UPDATE SET wallet_balance = EXCLUDED.wallet_balance;

INSERT INTO volunteer_profiles (id, user_id, rating, completed_tasks) VALUES
(1, 300, 4.8, 12),
(2, 301, 5.0, 5),
(3, 302, 3.2, 1), -- Low rating
(4, 303, 5.0, 0)
ON CONFLICT (id) DO NOTHING;

-- 4. CAMPAIGNS
INSERT INTO campaigns (id, ngo_id, created_by, title, goal_pkr, raised_pkr, status) VALUES
(1, 1, 200, 'Sindh Flood Relief 2026', 1000000.00, 450000.00, 'ACTIVE'),
(2, 2, 201, 'Emergency Cardiac Unit', 500000.00, 650000.00, 'ACTIVE'), -- Over-funded
(3, 3, 202, 'Winter Clothes Drive', 200000.00, 200000.00, 'PAUSED'), -- Fully funded but paused
(4, 4, 203, 'Ramadan Food Packs', 300000.00, 0.00, 'DRAFT'), -- New draft
(5, 1, 200, 'Completed Rescue Mission', 100000.00, 100000.00, 'COMPLETED') -- Finished
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, raised_pkr = EXCLUDED.raised_pkr;

-- 5. TASKS (Crucial Test Area)
INSERT INTO tasks (id, campaign_id, beneficiary_id, created_by, claimed_by, coordinator_id, source_type, title, status, urgency, location) VALUES
-- Normal flow
(1, 1, 400, 200, 300, 600, 'NGO_CAMPAIGN', 'Deliver 50kg Flour to Zia', 'SUBMITTED', 'HIGH', ST_SetSRID(ST_MakePoint(67.0011, 24.8607), 4326)::geography),
(2, 2, 401, 201, 301, 600, 'NGO_CAMPAIGN', 'Urgent Insulin for Fatima', 'IN_PROGRESS', 'CRITICAL', ST_SetSRID(ST_MakePoint(67.0500, 24.9000), 4326)::geography),
(3, 3, 402, 202, NULL, NULL, 'NGO_CAMPAIGN', 'Distribute Blankets at Camp', 'OPEN', 'MEDIUM', ST_SetSRID(ST_MakePoint(67.1000, 24.9500), 4326)::geography),

-- Edge cases
(4, 1, 403, 200, 302, 601, 'NGO_CAMPAIGN', 'Clean Water Delivery', 'CLAIMED', 'HIGH', ST_SetSRID(ST_MakePoint(67.0100, 24.8700), 4326)::geography), -- Claimed but not started
(5, NULL, 404, 404, NULL, NULL, 'BENEFICIARY_REQUEST', 'Help! My roof collapsed', 'OPEN', 'CRITICAL', ST_SetSRID(ST_MakePoint(67.1500, 24.8000), 4326)::geography), -- Direct request
(6, 1, 400, 200, 300, 600, 'NGO_CAMPAIGN', 'Verified Past Task', 'PAID', 'LOW', ST_SetSRID(ST_MakePoint(67.0000, 24.8600), 4326)::geography), -- Fully completed

-- Failure/Anomaly cases
(7, 5, 402, 200, 304, 601, 'NGO_CAMPAIGN', 'Task with Suspended Volunteer', 'FLAGGED', 'MEDIUM', ST_SetSRID(ST_MakePoint(67.2000, 24.8200), 4326)::geography),
(8, 1, 400, 200, 305, NULL, 'NGO_CAMPAIGN', 'Orphaned Workflow', 'IN_PROGRESS', 'MEDIUM', ST_SetSRID(ST_MakePoint(67.0011, 24.8607), 4326)::geography) -- No coordinator assigned
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status;

-- 6. DONATIONS (Financial Stress Test)
INSERT INTO donations (id, donor_id, campaign_id, amount_pkr, status, gateway_ref, created_at) VALUES
(1, 500, 1, 100000.00, 'CONFIRMED', 'TXN_WHALE_001', NOW() - INTERVAL '2 days'),
(2, 501, 1, 10.50, 'CONFIRMED', 'TXN_MICRO_001', NOW() - INTERVAL '1 day'), -- Tiny donation
(3, 502, 2, 250000.00, 'PENDING', 'TXN_PENDING_001', NOW()), -- High amount pending
(4, 503, 3, 5000.00, 'REJECTED', 'TXN_REJECT_001', NOW() - INTERVAL '5 days'),
(5, 500, 2, 400000.00, 'CONFIRMED', 'TXN_WHALE_002', NOW() - INTERVAL '3 days'),
(6, 504, 1, 50.00, 'PENDING', 'TXN_DUP_REF', NOW()), -- Anomaly: will try to test duplicate ref later
(7, 505, 5, 100000.00, 'CONFIRMED', 'TXN_COMP_001', NOW() - INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;

-- 7. WITHDRAWALS (Risk Scenarios)
INSERT INTO withdrawals (id, ngo_user_id, amount, bank_account, status, approved_by, approved_at) VALUES
(1, 200, 50000.00, 'PK1234567890', 'APPROVED', 101, NOW() - INTERVAL '1 day'),
(2, 201, 2000000.00, 'PK0987654321', 'PENDING', NULL, NULL), -- Edge case: > NGO wallet balance
(3, 202, 500.00, 'PK6667778889', 'REJECTED', 101, NULL),
(4, 200, 100.00, 'PK1112223334', 'PENDING', NULL, NULL) -- Multiple pending for same NGO
ON CONFLICT (id) DO NOTHING;

-- 8. CHAT SYSTEM DATA
INSERT INTO chat_rooms (id, task_id, created_by) VALUES
(1, 1, 200),
(2, 2, 201),
(3, 4, 200),
(4, 6, 200),
(5, 8, 200) -- Room for orphan task
ON CONFLICT (id) DO NOTHING;

INSERT INTO chat_messages (room_id, sender_id, text, created_at) VALUES
(1, 200, 'Ahmed, please update us on the flour delivery.', NOW() - INTERVAL '1 hour'),
(1, 300, 'Loading the truck now. Will be there in 30 mins.', NOW() - INTERVAL '45 mins'),
(2, 301, 'Beneficiary is not responding to calls.', NOW() - INTERVAL '2 hours'),
(3, 200, 'Task claimed, awaiting start.', NOW() - INTERVAL '5 hours'),
(5, 305, 'Help? No coordinator here.', NOW()) -- Message burst test
ON CONFLICT (id) DO NOTHING;

-- 9. LEDGER & AUDIT LOGS (Traceability)
INSERT INTO ledger_entries (type, amount_pkr, from_user_id, to_user_id, ref_table, ref_id) VALUES
('DONATION', 100000.00, 500, NULL, 'donations', 1),
('DONATION', 10.50, 501, NULL, 'donations', 2),
('WITHDRAWAL', 50000.00, 200, NULL, 'withdrawals', 1),
('DONATION', 400000.00, 500, NULL, 'donations', 5);

INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata) VALUES
(101, 'APPROVE_DONATION', 'donations', 1, '{"amount": 100000}'),
(101, 'APPROVE_WITHDRAWAL', 'withdrawals', 1, '{"amount": 50000, "ngo": "Red Cross"}'),
(100, 'UPDATE_CAMPAIGN_STATUS', 'campaigns', 3, '{"old": "ACTIVE", "new": "PAUSED"}'),
(100, 'SUSPEND_USER', 'users', 304, '{"reason": "Inactivity and poor reports"}');

-- 10. INTENTIONAL ANOMALIES (Testing Resilience)
-- Orphan events
INSERT INTO task_events (task_id, user_id, event_type) VALUES
(1, 300, 'CLAIMED'),
(1, 300, 'STARTED'),
(1, 300, 'SUBMITTED'),
(7, 304, 'FLAGGED');

-- Metadata for one event
UPDATE task_events SET metadata = '{"reason": "Inconsistent GPS data"}' WHERE task_id = 7;

-- 11. SEQUENCE SYNCHRONIZATION
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('ngo_profiles_id_seq', (SELECT MAX(id) FROM ngo_profiles));
SELECT setval('campaigns_id_seq', (SELECT MAX(id) FROM campaigns));
SELECT setval('tasks_id_seq', (SELECT MAX(id) FROM tasks));
SELECT setval('donations_id_seq', (SELECT MAX(id) FROM donations));
SELECT setval('withdrawals_id_seq', (SELECT MAX(id) FROM withdrawals));
SELECT setval('chat_rooms_id_seq', (SELECT MAX(id) FROM chat_rooms));
SELECT setval('ledger_entries_id_seq', (SELECT MAX(id) FROM ledger_entries));
SELECT setval('audit_logs_id_seq', (SELECT MAX(id) FROM audit_logs));
SELECT setval('task_events_id_seq', (SELECT MAX(id) FROM task_events));

COMMIT;
