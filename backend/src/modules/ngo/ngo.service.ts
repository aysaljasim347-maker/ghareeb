import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';

export class NgoService {
  /**
   * Get NGO profile ID for a user.
   */
  async getNgoIdByUserId(userId: number): Promise<number | null> {
    const result = await pool.query('SELECT id FROM ngo_profiles WHERE user_id = $1', [userId]);
    return result.rows[0]?.id || null;
  }

  /**
   * Get NGO dashboard statistics.
   */
  async getDashboardStats(userId: number) {
    const ngoId = await this.getNgoIdByUserId(userId);
    if (!ngoId) throw createError('NGO profile not found', 404);

    const [campaignStats, donationStats] = await Promise.all([
      pool.query(`
        SELECT 
          COUNT(*) as total_count,
          COUNT(*) FILTER (WHERE status = 'ACTIVE') as active_count,
          COALESCE(SUM(raised_pkr), 0) as total_raised,
          COALESCE(SUM(goal_pkr), 0) as total_goal
        FROM campaigns
        WHERE ngo_id = $1
      `, [ngoId]),
      pool.query(`
        SELECT 
          COUNT(*) as donation_count,
          COALESCE(SUM(amount_pkr), 0) as donation_sum
        FROM donations d
        JOIN campaigns c ON c.id = d.campaign_id
        WHERE c.ngo_id = $1 AND d.status = 'CONFIRMED'
      `, [ngoId])
    ]);

    const c = campaignStats.rows[0];
    const d = donationStats.rows[0];

    return {
      campaigns: {
        total: parseInt(c.total_count, 10),
        active: parseInt(c.active_count, 10),
        total_raised: parseFloat(c.total_raised),
        total_goal: parseFloat(c.total_goal),
      },
      donations: {
        count: parseInt(d.donation_count, 10),
        total_amount: parseFloat(d.donation_sum),
      }
    };
  }

  /**
   * Get full NGO profile.
   */
  async getProfile(userId: number) {
    const result = await pool.query(`
      SELECT np.*, u.name, u.email, u.created_at as user_joined_at
      FROM ngo_profiles np
      JOIN users u ON u.id = np.user_id
      WHERE np.user_id = $1
    `, [userId]);

    if (result.rows.length === 0) throw createError('NGO profile not found', 404);
    return result.rows[0];
  }

  /**
   * Get NGO campaigns (paginated).
   */
  async getCampaigns(userId: number) {
    const ngoId = await this.getNgoIdByUserId(userId);
    if (!ngoId) throw createError('NGO profile not found', 404);

    const result = await pool.query(`
      SELECT * FROM campaigns
      WHERE ngo_id = $1
      ORDER BY created_at DESC
    `, [ngoId]);

    return result.rows;
  }

  /**
   * Public profile data.
   */
  async getPublicProfile(ngoId: number) {
    const [profile, campaigns] = await Promise.all([
      pool.query('SELECT org_name, description, status, verified_at, created_at FROM ngo_profiles WHERE id = $1', [ngoId]),
      pool.query(`
        SELECT id, title, status, raised_pkr, goal_pkr, created_at 
        FROM campaigns 
        WHERE ngo_id = $1 AND status != 'DRAFT'
        ORDER BY created_at DESC
      `, [ngoId])
    ]);

    if (profile.rows.length === 0) throw createError('NGO not found', 404);

    return {
      profile: profile.rows[0],
      campaigns: campaigns.rows
    };
  }
}

export const ngoService = new NgoService();
