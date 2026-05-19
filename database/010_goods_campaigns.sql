-- ── Goods Campaigns & Donations ───────────────────────────────────────────────
-- NGOs create goods campaigns seeking specific physical items.
-- Donors submit item donations tied to a campaign.
-- Volunteers pick up items from donors and deliver them.
-- Coordinators verify deliveries and approve/reject.

-- ── Table 1: goods_campaigns ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS goods_campaigns (
  id               SERIAL PRIMARY KEY,
  ngo_id           INTEGER          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title            VARCHAR(255)     NOT NULL,
  item_needed      VARCHAR(255)     NOT NULL,
  category         VARCHAR(100)     NOT NULL,
  category_other   VARCHAR(255),
  target_qty       DECIMAL(10,2)    NOT NULL CHECK (target_qty > 0),
  unit             VARCHAR(50)      NOT NULL,
  description      TEXT             NOT NULL,
  location_text    TEXT             NOT NULL,
  latitude         DECIMAL(10,8),
  longitude        DECIMAL(11,8),
  deadline         DATE             NOT NULL,
  cover_image_url  TEXT,
  status           VARCHAR(50)      NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE', 'PAUSED', 'CLOSED', 'DRAFT')),
  qty_received     DECIMAL(10,2)    NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goods_campaigns_ngo_id ON goods_campaigns(ngo_id);
CREATE INDEX IF NOT EXISTS idx_goods_campaigns_status ON goods_campaigns(status);

-- ── Table 2: goods_donations ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS goods_donations (
  id               SERIAL PRIMARY KEY,
  campaign_id      INTEGER          NOT NULL REFERENCES goods_campaigns(id) ON DELETE RESTRICT,
  donor_id         INTEGER          NOT NULL REFERENCES users(id),
  item_name        VARCHAR(255)     NOT NULL,
  category         VARCHAR(100)     NOT NULL,
  description      TEXT             NOT NULL,
  photo_url        TEXT,
  quantity         DECIMAL(10,2)    NOT NULL CHECK (quantity > 0),
  unit             VARCHAR(50)      NOT NULL,
  pickup_address   TEXT             NOT NULL,
  pickup_lat       DECIMAL(10,8),
  pickup_lng       DECIMAL(11,8),
  contact_number   VARCHAR(20)      NOT NULL,
  status           VARCHAR(50)      NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING', 'ASSIGNED', 'DELIVERED', 'APPROVED', 'REJECTED')),
  volunteer_id     INTEGER          REFERENCES users(id),
  proof_photo_url  TEXT,
  qty_confirmed    DECIMAL(10,2),
  volunteer_note   TEXT,
  rejection_reason TEXT,
  delivered_at     TIMESTAMPTZ,
  approved_at      TIMESTAMPTZ,
  rejected_at      TIMESTAMPTZ,
  submitted_at     TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goods_donations_campaign_id  ON goods_donations(campaign_id);
CREATE INDEX IF NOT EXISTS idx_goods_donations_donor_id     ON goods_donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_goods_donations_volunteer_id ON goods_donations(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_goods_donations_status       ON goods_donations(status);

-- ── Table 3: goods_status_log ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS goods_status_log (
  id            SERIAL PRIMARY KEY,
  donation_id   INTEGER      NOT NULL REFERENCES goods_donations(id) ON DELETE CASCADE,
  changed_by    INTEGER      NOT NULL REFERENCES users(id),
  old_status    VARCHAR(50),
  new_status    VARCHAR(50)  NOT NULL,
  note          TEXT,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goods_status_log_donation_id ON goods_status_log(donation_id);
