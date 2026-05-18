-- ── InKind Donations ─────────────────────────────────────────────────────────
-- Donors list physical items for pickup; beneficiaries request them.
-- One donation → many requests, but only one can be accepted.

CREATE TABLE inkind_donations (
  id          SERIAL PRIMARY KEY,
  donor_id    INT         NOT NULL REFERENCES users(id),
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  photo_url   TEXT,
  address_text TEXT        NOT NULL,
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
                CHECK (status IN ('AVAILABLE', 'ACCEPTED', 'CANCELLED')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inkind_requests (
  id                SERIAL PRIMARY KEY,
  donation_id       INT         NOT NULL REFERENCES inkind_donations(id),
  beneficiary_id    INT         NOT NULL REFERENCES users(id),
  message           TEXT,
  phone             VARCHAR(30) NOT NULL,
  email             VARCHAR(255),
  status            VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED')),
  donor_shared_phone VARCHAR(30),
  accepted_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prevent a beneficiary from requesting the same donation twice
CREATE UNIQUE INDEX inkind_requests_one_per_beneficiary
  ON inkind_requests(donation_id, beneficiary_id);

CREATE INDEX inkind_donations_donor_id_idx    ON inkind_donations(donor_id);
CREATE INDEX inkind_donations_status_idx      ON inkind_donations(status);
CREATE INDEX inkind_requests_donation_id_idx  ON inkind_requests(donation_id);
CREATE INDEX inkind_requests_beneficiary_idx  ON inkind_requests(beneficiary_id);
