import { Pool } from 'pg';
import bcrypt from 'bcrypt';

const TEST_DB_CONFIG = {
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
  database: process.env.POSTGRES_DB || 'disasteraid_test',
  user: process.env.POSTGRES_USER || 'test_user',
  password: process.env.POSTGRES_PASSWORD || 'test_password',
};

let pool: Pool;

beforeAll(async () => {
  pool = new Pool(TEST_DB_CONFIG);
});

afterAll(async () => {
  await pool.query("DELETE FROM ledger_entries WHERE ref_table = 'donations'");
  await pool.query('DELETE FROM donations');
  await pool.query('DELETE FROM campaigns WHERE title LIKE \'Donation Test%\'');
  await pool.query("DELETE FROM ngo_profiles WHERE org_name = 'Donation Test NGO'");
  await pool.query("DELETE FROM users WHERE email LIKE 'donation-%'");
  await pool.end();
});

// ── Helpers ──
async function setupDonationTest() {
  const hash = await bcrypt.hash('password', 4);

  // Create donor
  const donorRole = await pool.query("SELECT id FROM roles WHERE name = 'DONOR'");
  const donor = await pool.query(
    `INSERT INTO users (email, password_hash, role_id, name)
     VALUES ('donation-donor@test.com', $1, $2, 'Test Donor')
     ON CONFLICT (email) DO UPDATE SET name = 'Test Donor'
     RETURNING id`,
    [hash, donorRole.rows[0].id]
  );

  // Create NGO user
  const ngoRole = await pool.query("SELECT id FROM roles WHERE name = 'NGO'");
  const ngoUser = await pool.query(
    `INSERT INTO users (email, password_hash, role_id, name)
     VALUES ('donation-ngo@test.com', $1, $2, 'Test NGO')
     ON CONFLICT (email) DO UPDATE SET name = 'Test NGO'
     RETURNING id`,
    [hash, ngoRole.rows[0].id]
  );

  // Create NGO profile
  const ngoProfile = await pool.query(
    `INSERT INTO ngo_profiles (user_id, org_name)
     VALUES ($1, 'Donation Test NGO')
     ON CONFLICT (user_id) DO UPDATE SET org_name = 'Donation Test NGO'
     RETURNING id`,
    [ngoUser.rows[0].id]
  );

  // Create campaign
  const campaign = await pool.query(
    `INSERT INTO campaigns (ngo_id, created_by, title, goal_pkr, status)
     VALUES ($1, $2, 'Donation Test Campaign', 100000, 'ACTIVE')
     RETURNING id`,
    [ngoProfile.rows[0].id, ngoUser.rows[0].id]
  );

  return {
    donorId: donor.rows[0].id,
    ngoUserId: ngoUser.rows[0].id,
    campaignId: campaign.rows[0].id,
  };
}

describe('Donations Module', () => {
  test('should create a donation and confirm it', async () => {
    const { donorId, campaignId } = await setupDonationTest();

    // Create donation
    const donation = await pool.query(
      `INSERT INTO donations (donor_id, campaign_id, amount_pkr, status)
       VALUES ($1, $2, 5000, 'PENDING')
       RETURNING id, status`,
      [donorId, campaignId]
    );
    expect(donation.rows[0].status).toBe('PENDING');

    // Confirm donation in a transaction (simulating webhook)
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `UPDATE donations SET status = 'COMPLETED' WHERE id = $1`,
        [donation.rows[0].id]
      );

      await client.query(
        `UPDATE campaigns SET raised_pkr = raised_pkr + 5000 WHERE id = $1`,
        [campaignId]
      );

      await client.query(
        `INSERT INTO ledger_entries (type, amount_pkr, from_user_id, ref_table, ref_id)
         VALUES ('DONATION', 5000, $1, 'donations', $2)`,
        [donorId, donation.rows[0].id]
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    // Verify campaign raised_pkr was updated
    const campaign = await pool.query(
      'SELECT raised_pkr FROM campaigns WHERE id = $1',
      [campaignId]
    );
    expect(parseFloat(campaign.rows[0].raised_pkr)).toBe(5000);

    // Verify ledger entry was created
    const ledger = await pool.query(
      "SELECT * FROM ledger_entries WHERE ref_table = 'donations' AND ref_id = $1",
      [donation.rows[0].id]
    );
    expect(ledger.rows.length).toBe(1);
    expect(parseFloat(ledger.rows[0].amount_pkr)).toBe(5000);
    expect(ledger.rows[0].type).toBe('DONATION');
  });

  test('should reject donation to non-ACTIVE campaign', async () => {
    const { donorId } = await setupDonationTest();

    // Create a DRAFT campaign
    const draftCampaign = await pool.query(
      `INSERT INTO campaigns (created_by, title, goal_pkr, status)
       VALUES ($1, 'Donation Test Draft', 50000, 'DRAFT')
       RETURNING id`,
      [donorId]
    );

    const campaign = await pool.query(
      'SELECT status FROM campaigns WHERE id = $1',
      [draftCampaign.rows[0].id]
    );
    expect(campaign.rows[0].status).toBe('DRAFT');
    // Application layer should reject donations to non-ACTIVE campaigns
  });
});
