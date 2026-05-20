-- ============================================================
-- DisasterAid V2.1 — Schema V2 Fixes Migration
-- File: database/011_schema_v2_fixes.sql
-- Idempotent: safe to re-run against the old schema.
-- ============================================================

BEGIN;

-- ── New enum types ───────────────────────────────────────────
DO $$ BEGIN
    CREATE TYPE donation_status AS ENUM ('PENDING', 'CONFIRMED', 'REJECTED', 'REFUNDED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE volunteer_type AS ENUM ('INDEPENDENT', 'NGO');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Utility function ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── [H2] Column renames ──────────────────────────────────────
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'deliveries' AND column_name = 'photo_urls'
    ) THEN
        ALTER TABLE deliveries RENAME COLUMN photo_urls TO storage_keys;
    END IF;
END $$;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inkind_donations' AND column_name = 'photo_url'
    ) THEN
        ALTER TABLE inkind_donations RENAME COLUMN photo_url TO storage_key;
    END IF;
END $$;

-- ── [M3] Soft-delete columns ─────────────────────────────────
ALTER TABLE users         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE campaigns     ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE ngo_profiles  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- ── [L1] volunteer_type column + backfill ────────────────────
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'volunteer_profiles' AND column_name = 'volunteer_type'
    ) THEN
        ALTER TABLE volunteer_profiles ADD COLUMN volunteer_type volunteer_type;
        UPDATE volunteer_profiles
           SET volunteer_type = CASE
               WHEN ngo_id IS NOT NULL THEN 'NGO'::volunteer_type
               ELSE 'INDEPENDENT'::volunteer_type
           END;
        ALTER TABLE volunteer_profiles ALTER COLUMN volunteer_type SET NOT NULL;
        ALTER TABLE volunteer_profiles ALTER COLUMN volunteer_type SET DEFAULT 'INDEPENDENT';
    END IF;
END $$;

DO $$ BEGIN
    ALTER TABLE volunteer_profiles
        ADD CONSTRAINT volunteer_type_ngo_consistency CHECK (
            (volunteer_type = 'NGO'         AND ngo_id IS NOT NULL) OR
            (volunteer_type = 'INDEPENDENT' AND ngo_id IS NULL)
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── [L3] donations.status → enum ────────────────────────────
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'donations'
          AND column_name = 'status'
          AND data_type = 'character varying'
    ) THEN
        UPDATE donations SET status = 'CONFIRMED' WHERE status = 'COMPLETED';
        UPDATE donations SET status = 'REJECTED'  WHERE status IN ('FAILED', 'REFUNDED');
        ALTER TABLE donations ALTER COLUMN status DROP DEFAULT;
        ALTER TABLE donations
            ALTER COLUMN status TYPE donation_status
            USING status::donation_status;
        ALTER TABLE donations ALTER COLUMN status SET DEFAULT 'PENDING'::donation_status;
    END IF;
END $$;

-- ── [C1] CHECK constraints ───────────────────────────────────
DO $$ BEGIN
    ALTER TABLE ngo_profiles
        ADD CONSTRAINT ngo_profiles_wallet_balance_check CHECK (wallet_balance >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE volunteer_profiles
        ADD CONSTRAINT volunteer_profiles_total_earned_check CHECK (total_earned >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE donations
        ADD CONSTRAINT donations_amount_positive CHECK (amount_pkr > 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE tasks
        ADD CONSTRAINT tasks_budget_non_negative CHECK (budget_pkr >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── [H1] Ledger duplicate prevention ────────────────────────
DO $$ BEGIN
    ALTER TABLE ledger_entries
        ADD CONSTRAINT ledger_entries_unique_event UNIQUE (type, ref_table, ref_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── [M4] Missing FK indexes ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tasks_campaign    ON tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_tasks_beneficiary ON tasks(beneficiary_id);

-- Soft-delete filtering indexes
CREATE INDEX IF NOT EXISTS idx_users_active     ON users(id)     WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_campaigns_active ON campaigns(id) WHERE deleted_at IS NULL;

-- ── [M2] Drop legacy app_config ─────────────────────────────
DROP TABLE IF EXISTS app_config CASCADE;

-- ── [L4] updated_at triggers ────────────────────────────────
DROP TRIGGER IF EXISTS update_tasks_updated_at         ON tasks;
DROP TRIGGER IF EXISTS update_volunteer_profiles_updated_at ON volunteer_profiles;
DROP TRIGGER IF EXISTS update_campaigns_updated_at     ON campaigns;
DROP TRIGGER IF EXISTS update_donations_updated_at     ON donations;
DROP TRIGGER IF EXISTS update_withdrawals_updated_at   ON withdrawals;
DROP TRIGGER IF EXISTS update_inkind_donations_updated_at ON inkind_donations;

CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_volunteer_profiles_updated_at
    BEFORE UPDATE ON volunteer_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campaigns_updated_at
    BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_donations_updated_at
    BEFORE UPDATE ON donations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_withdrawals_updated_at
    BEFORE UPDATE ON withdrawals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inkind_donations_updated_at
    BEFORE UPDATE ON inkind_donations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── [C6] Task state machine trigger ─────────────────────────
CREATE OR REPLACE FUNCTION enforce_task_status_transition()
RETURNS TRIGGER AS $$
DECLARE
    allowed TEXT[];
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    allowed := CASE OLD.status
        WHEN 'OPEN'                 THEN ARRAY['ASSIGNED', 'CLAIMED', 'FLAGGED', 'CANCELLED']
        WHEN 'ASSIGNED'             THEN ARRAY['IN_PROGRESS', 'OPEN', 'FLAGGED', 'CANCELLED']
        WHEN 'CLAIMED'              THEN ARRAY['IN_PROGRESS', 'OPEN', 'FLAGGED', 'CANCELLED']
        WHEN 'IN_PROGRESS'          THEN ARRAY['SUBMITTED', 'FLAGGED', 'CANCELLED']
        WHEN 'SUBMITTED'            THEN ARRAY['COORDINATOR_VERIFIED', 'FLAGGED', 'IN_PROGRESS']
        WHEN 'COORDINATOR_VERIFIED' THEN ARRAY['PAID', 'FLAGGED']
        WHEN 'PAID'                 THEN ARRAY[]::TEXT[]
        WHEN 'FLAGGED'              THEN ARRAY['OPEN', 'CANCELLED']
        WHEN 'CANCELLED'            THEN ARRAY[]::TEXT[]
        ELSE                             ARRAY[]::TEXT[]
    END;

    IF NOT (NEW.status::TEXT = ANY(allowed)) THEN
        RAISE EXCEPTION
            'Invalid task status transition: % -> %. Allowed from %: [%]',
            OLD.status, NEW.status, OLD.status, array_to_string(allowed, ', ');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_task_status_transition ON tasks;
CREATE TRIGGER enforce_task_status_transition
    BEFORE UPDATE OF status ON tasks
    FOR EACH ROW EXECUTE FUNCTION enforce_task_status_transition();

-- ── [H3] claimed_by must be active volunteer ─────────────────
CREATE OR REPLACE FUNCTION validate_task_claimer()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.claimed_by IS NOT NULL AND (OLD.claimed_by IS DISTINCT FROM NEW.claimed_by) THEN
        IF NOT EXISTS (
            SELECT 1 FROM volunteer_profiles
            WHERE user_id = NEW.claimed_by
              AND status = 'ACTIVE'
        ) THEN
            RAISE EXCEPTION
                'User % cannot claim a task: no active volunteer_profile found.',
                NEW.claimed_by;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_task_claimer ON tasks;
CREATE TRIGGER validate_task_claimer
    BEFORE INSERT OR UPDATE OF claimed_by ON tasks
    FOR EACH ROW EXECUTE FUNCTION validate_task_claimer();

-- ── [L2] Feedback ownership trigger ─────────────────────────
CREATE OR REPLACE FUNCTION validate_feedback_ownership()
RETURNS TRIGGER AS $$
DECLARE
    task_beneficiary_id INT;
BEGIN
    SELECT t.beneficiary_id INTO task_beneficiary_id
    FROM deliveries d
    JOIN tasks t ON t.id = d.task_id
    WHERE d.id = NEW.delivery_id;

    IF task_beneficiary_id IS NULL THEN
        RAISE EXCEPTION
            'Delivery % has no associated task beneficiary.', NEW.delivery_id;
    END IF;

    IF NEW.beneficiary_id != task_beneficiary_id THEN
        RAISE EXCEPTION
            'User % is not the beneficiary for delivery %. Expected beneficiary: %.',
            NEW.beneficiary_id, NEW.delivery_id, task_beneficiary_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_feedback_ownership ON beneficiary_feedback;
CREATE TRIGGER validate_feedback_ownership
    BEFORE INSERT ON beneficiary_feedback
    FOR EACH ROW EXECUTE FUNCTION validate_feedback_ownership();

-- ── [C3] Sync campaign raised_pkr via trigger ────────────────
CREATE OR REPLACE FUNCTION sync_campaign_raised_pkr()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'CONFIRMED' THEN
        UPDATE campaigns
        SET raised_pkr = raised_pkr + NEW.amount_pkr
        WHERE id = NEW.campaign_id;

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status != 'CONFIRMED' AND NEW.status = 'CONFIRMED' THEN
            UPDATE campaigns
            SET raised_pkr = raised_pkr + NEW.amount_pkr
            WHERE id = NEW.campaign_id;
        ELSIF OLD.status = 'CONFIRMED' AND NEW.status != 'CONFIRMED' THEN
            UPDATE campaigns
            SET raised_pkr = GREATEST(0, raised_pkr - OLD.amount_pkr)
            WHERE id = OLD.campaign_id;
        END IF;

    ELSIF TG_OP = 'DELETE' AND OLD.status = 'CONFIRMED' THEN
        UPDATE campaigns
        SET raised_pkr = GREATEST(0, raised_pkr - OLD.amount_pkr)
        WHERE id = OLD.campaign_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_campaign_raised_pkr ON donations;
CREATE TRIGGER sync_campaign_raised_pkr
    AFTER INSERT OR UPDATE OF status OR DELETE ON donations
    FOR EACH ROW EXECUTE FUNCTION sync_campaign_raised_pkr();

-- ── [C3] Sync campaign spent_pkr via trigger ────────────────
CREATE OR REPLACE FUNCTION sync_campaign_spent_pkr()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status != 'PAID' AND NEW.status = 'PAID' AND NEW.campaign_id IS NOT NULL THEN
        UPDATE campaigns
        SET spent_pkr = spent_pkr + NEW.budget_pkr
        WHERE id = NEW.campaign_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_campaign_spent_pkr ON tasks;
CREATE TRIGGER sync_campaign_spent_pkr
    AFTER UPDATE OF status ON tasks
    FOR EACH ROW EXECUTE FUNCTION sync_campaign_spent_pkr();

-- ── [C5] RLS helper functions ────────────────────────────────
CREATE OR REPLACE FUNCTION app_current_user_id() RETURNS INT AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::INT;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION app_current_user_role() RETURNS user_role AS $$
    SELECT r.name
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE u.id = app_current_user_id()
      AND u.deleted_at IS NULL;
$$ LANGUAGE SQL STABLE;

-- ── [C5] Row Level Security ──────────────────────────────────
ALTER TABLE users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages  ENABLE ROW LEVEL SECURITY;
ALTER TABLE beneficiary_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select ON users;
DROP POLICY IF EXISTS users_update ON users;
CREATE POLICY users_select ON users FOR SELECT
    USING (deleted_at IS NULL);
CREATE POLICY users_update ON users FOR UPDATE
    USING (id = app_current_user_id() OR app_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS tasks_select ON tasks;
DROP POLICY IF EXISTS tasks_insert ON tasks;
DROP POLICY IF EXISTS tasks_update ON tasks;
CREATE POLICY tasks_select ON tasks FOR SELECT
    USING (
        status != 'CANCELLED'
        OR beneficiary_id  = app_current_user_id()
        OR claimed_by      = app_current_user_id()
        OR app_current_user_role() IN ('COORDINATOR', 'ADMIN')
    );
CREATE POLICY tasks_insert ON tasks FOR INSERT
    WITH CHECK (
        app_current_user_role() IN ('BENEFICIARY', 'NGO', 'COORDINATOR', 'ADMIN')
    );
CREATE POLICY tasks_update ON tasks FOR UPDATE
    USING (
        claimed_by        = app_current_user_id()
        OR coordinator_id = app_current_user_id()
        OR app_current_user_role() IN ('COORDINATOR', 'ADMIN')
    );

DROP POLICY IF EXISTS donations_select ON donations;
DROP POLICY IF EXISTS donations_insert ON donations;
CREATE POLICY donations_select ON donations FOR SELECT
    USING (
        donor_id = app_current_user_id()
        OR app_current_user_role() IN ('NGO', 'COORDINATOR', 'ADMIN')
    );
CREATE POLICY donations_insert ON donations FOR INSERT
    WITH CHECK (donor_id = app_current_user_id());

DROP POLICY IF EXISTS withdrawals_select ON withdrawals;
DROP POLICY IF EXISTS withdrawals_insert ON withdrawals;
CREATE POLICY withdrawals_select ON withdrawals FOR SELECT
    USING (
        ngo_user_id = app_current_user_id()
        OR app_current_user_role() = 'ADMIN'
    );
CREATE POLICY withdrawals_insert ON withdrawals FOR INSERT
    WITH CHECK (
        ngo_user_id = app_current_user_id()
        AND app_current_user_role() = 'NGO'
    );

DROP POLICY IF EXISTS audit_logs_admin ON audit_logs;
CREATE POLICY audit_logs_admin ON audit_logs FOR ALL
    USING (app_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS ledger_admin ON ledger_entries;
CREATE POLICY ledger_admin ON ledger_entries FOR ALL
    USING (app_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS chat_messages_select ON chat_messages;
DROP POLICY IF EXISTS chat_messages_insert ON chat_messages;
CREATE POLICY chat_messages_select ON chat_messages FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM chat_rooms cr
            JOIN tasks t ON t.id = cr.task_id
            WHERE cr.id = room_id
              AND (
                  t.beneficiary_id   = app_current_user_id()
                  OR t.claimed_by    = app_current_user_id()
                  OR t.coordinator_id = app_current_user_id()
                  OR app_current_user_role() = 'ADMIN'
              )
        )
    );
CREATE POLICY chat_messages_insert ON chat_messages FOR INSERT
    WITH CHECK (sender_id = app_current_user_id());

DROP POLICY IF EXISTS feedback_insert ON beneficiary_feedback;
DROP POLICY IF EXISTS feedback_select ON beneficiary_feedback;
CREATE POLICY feedback_insert ON beneficiary_feedback FOR INSERT
    WITH CHECK (beneficiary_id = app_current_user_id());
CREATE POLICY feedback_select ON beneficiary_feedback FOR SELECT
    USING (
        beneficiary_id = app_current_user_id()
        OR app_current_user_role() IN ('COORDINATOR', 'ADMIN')
    );

COMMIT;
