-- ============================================================
-- DisasterAid V2.1 — Database Schema
-- PostgreSQL 16 + PostGIS 3
-- ============================================================
BEGIN;
-- ── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;
-- ── ENUM Types ──────────────────────────────────────────────
CREATE TYPE user_role AS ENUM (
    'DONOR',
    'BENEFICIARY',
    'VOLUNTEER',
    'NGO',
    'COORDINATOR',
    'ADMIN'
);
CREATE TYPE task_status AS ENUM (
    'OPEN',
    'ASSIGNED',
    'CLAIMED',
    'IN_PROGRESS',
    'SUBMITTED',
    'COORDINATOR_VERIFIED',
    'PAID',
    'FLAGGED',
    'CANCELLED'
);
CREATE TYPE task_urgency AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE task_source AS ENUM (
    'BENEFICIARY_REQUEST',
    'NGO_CAMPAIGN',
    'PLATFORM_CAMPAIGN',
    'ADMIN_CREATED'
);
CREATE TYPE task_event_type AS ENUM (
    'CREATED',
    'SEEN',
    'ASSIGNED',
    'CLAIMED',
    'STARTED',
    'SUBMITTED',
    'VERIFIED',
    'PAID',
    'FLAGGED',
    'CHAT_STARTED',
    'UPDATED',
    'CANCELLED'
);
CREATE TYPE campaign_status AS ENUM (
    'DRAFT',
    'PENDING_APPROVAL',
    'ACTIVE',
    'PAUSED',
    'CLOSED',
    'REJECTED',
    'COMPLETED'
);
CREATE TYPE user_status AS ENUM ('ACTIVE', 'SUSPENDED');
-- ── Utility Functions ───────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$ language 'plpgsql';
-- ── Tables ──────────────────────────────────────────────────
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name user_role UNIQUE NOT NULL
);
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT NOT NULL REFERENCES roles(id),
    name VARCHAR(255) NOT NULL,
    cnic VARCHAR(15),
    status user_status DEFAULT 'ACTIVE',
    locale VARCHAR(5) DEFAULT 'en',
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT email_or_phone CHECK (
        email IS NOT NULL
        OR phone IS NOT NULL
    )
);
CREATE TABLE ngo_profiles (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    org_name VARCHAR(255) NOT NULL,
    registration_number VARCHAR(100) UNIQUE,
    status VARCHAR(20) DEFAULT 'PENDING',
    wallet_balance NUMERIC(12, 2) DEFAULT 0,
    location GEOGRAPHY(Point, 4326),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE volunteer_profiles (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ngo_id INT REFERENCES ngo_profiles(id),
    skills TEXT [],
    rating NUMERIC(3, 2) DEFAULT 5.0,
    completed_tasks INT DEFAULT 0,
    total_earned NUMERIC(12, 2) DEFAULT 0,
    location GEOGRAPHY(Point, 4326),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE campaigns (
    id SERIAL PRIMARY KEY,
    ngo_id INT REFERENCES ngo_profiles(id) ON DELETE
    SET NULL,
        created_by INT REFERENCES users(id),
        title VARCHAR(255) NOT NULL,
        description TEXT,
        goal_pkr NUMERIC(12, 2) NOT NULL,
        raised_pkr NUMERIC(12, 2) DEFAULT 0,
        spent_pkr NUMERIC(12, 2) DEFAULT 0,
        location GEOGRAPHY(Point, 4326),
        status campaign_status DEFAULT 'DRAFT',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    campaign_id INT REFERENCES campaigns(id) ON DELETE
    SET NULL,
        beneficiary_id INT REFERENCES users(id),
        created_by INT REFERENCES users(id),
        claimed_by INT REFERENCES users(id),
        coordinator_id INT REFERENCES users(id),
        source_type task_source NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        category VARCHAR(50),
        family_size INT DEFAULT 1,
        items_needed JSONB DEFAULT '[]'::jsonb,
        location GEOGRAPHY(Point, 4326) NOT NULL,
        location_text TEXT,
        radius_km INT DEFAULT 5,
        budget_pkr NUMERIC(10, 2) DEFAULT 0,
        urgency task_urgency DEFAULT 'MEDIUM',
        status task_status DEFAULT 'OPEN',
        upvotes INT DEFAULT 0,
        downvotes INT DEFAULT 0,
        view_count INT DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        claimed_at TIMESTAMPTZ
);
CREATE TABLE task_events (
    id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id INT REFERENCES users(id),
    event_type task_event_type NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE task_views (
    task_id INT REFERENCES tasks(id) ON DELETE CASCADE,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    first_seen_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    view_count INT DEFAULT 1,
    PRIMARY KEY (task_id, user_id)
);
CREATE TABLE deliveries (
    id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    volunteer_id INT NOT NULL REFERENCES users(id),
    photo_urls TEXT [] NOT NULL,
    gps_location GEOGRAPHY(Point, 4326) NOT NULL,
    notes TEXT,
    verified_by INT REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE donations (
    id SERIAL PRIMARY KEY,
    donor_id INT REFERENCES users(id) ON DELETE
    SET NULL,
        campaign_id INT REFERENCES campaigns(id) ON DELETE
    SET NULL,
        amount_pkr NUMERIC(10, 2) NOT NULL,
        status VARCHAR(20) DEFAULT 'PENDING',
        gateway_ref VARCHAR(255) UNIQUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE chat_rooms (
    id SERIAL PRIMARY KEY,
    task_id INT REFERENCES tasks(id) ON DELETE CASCADE,
    created_by INT REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE chat_messages (
    id SERIAL PRIMARY KEY,
    room_id INT NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id INT NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE app_config (
    id INT PRIMARY KEY DEFAULT 1,
    disaster_mode BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE ledger_entries (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    amount_pkr NUMERIC(12, 2) NOT NULL,
    from_user_id INT REFERENCES users(id),
    to_user_id INT REFERENCES users(id),
    ref_table VARCHAR(50),
    ref_id INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- ── Indexes ─────────────────────────────────────────────────
CREATE INDEX idx_tasks_location ON tasks USING GIST(location);
CREATE INDEX idx_tasks_status ON tasks(status)
WHERE status IN ('OPEN', 'ASSIGNED');
CREATE INDEX idx_tasks_claimed ON tasks(claimed_by)
WHERE claimed_by IS NOT NULL;
CREATE INDEX idx_task_events_task_time ON task_events(task_id, created_at DESC);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email);
-- ── Triggers ────────────────────────────────────────────────
CREATE TRIGGER update_tasks_updated_at BEFORE
UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_volunteer_profiles_updated_at BEFORE
UPDATE ON volunteer_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- ── Seed Data ───────────────────────────────────────────────
INSERT INTO roles (name)
VALUES ('DONOR'),
    ('BENEFICIARY'),
    ('VOLUNTEER'),
    ('NGO'),
    ('COORDINATOR'),
    ('ADMIN');
INSERT INTO app_config (id)
VALUES (1);
-- This admin is the system bootstrap admin (id auto-generated)
INSERT INTO users (email, password_hash, role_id, name)
VALUES (
        'admin@disasteraid.pk',
        '$2b$10$WGUcO88IrQxm0ZbR2msEZ../XO5XEbOiff78x0IuPYhiw.985Nb0u',
        6,
        'System Admin'
    );
COMMIT;