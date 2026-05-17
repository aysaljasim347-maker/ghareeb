import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';

export interface PaginationOptions {
  page?: number;
  limit?: number;
  sortField?: string;
  sortOrder?: 'ASC' | 'DESC';
}

export interface AuditLogFilters {
  admin_id?: number;
  action_type?: string;
  target_entity?: string;
  target_id?: number;
  from_date?: string;
  to_date?: string;
  metadata_filter?: Record<string, string>;
}

export class AdminService {
  private applyPagination(query: string, options: PaginationOptions, values: any[]) {
    const page = options.page || 1;
    const limit = options.limit || 10;
    const offset = (page - 1) * limit;
    
    const sortField = options.sortField || 'created_at';
    const sortOrder = options.sortOrder || 'DESC';

    // Basic injection protection for sortField (whitelist)
    const allowedSortFields = ['created_at', 'amount_pkr', 'amount', 'name', 'status', 'id'];
    const safeSortField = allowedSortFields.includes(sortField) ? sortField : 'created_at';

    const paginatedQuery = `${query} ORDER BY ${safeSortField} ${sortOrder} LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
    return {
      query: paginatedQuery,
      values: [...values, limit, offset]
    };
  }

  async getDonationStats() {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_count,
        SUM(amount_pkr) as total_amount,
        COUNT(*) FILTER (WHERE status = 'PENDING') as pending_count,
        COUNT(*) FILTER (WHERE status = 'CONFIRMED') as confirmed_count,
        COUNT(*) FILTER (WHERE status = 'REJECTED') as rejected_count,
        COUNT(*) FILTER (WHERE metadata->>'disputed' = 'true') as disputed_count
      FROM donations
    `);
    return result.rows[0];
  }

  async getWithdrawalStats() {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_count,
        SUM(amount) as total_amount,
        COUNT(*) FILTER (WHERE status = 'PENDING') as pending_count,
        COUNT(*) FILTER (WHERE status = 'APPROVED') as approved_count,
        COUNT(*) FILTER (WHERE status = 'REJECTED') as rejected_count,
        COUNT(*) FILTER (WHERE metadata->>'flagged' = 'true') as flagged_count
      FROM withdrawals
    `);
    return result.rows[0];
  }

  async getCampaignStats() {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE status = 'ACTIVE') as active_count,
        SUM(raised_pkr) as total_raised,
        SUM(goal_pkr) as total_target
      FROM campaigns
    `);
    return result.rows[0];
  }

  async getUserStats() {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'ADMIN')) as admin_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'NGO')) as ngo_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'VOLUNTEER')) as volunteer_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'COORDINATOR')) as coordinator_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'DONOR')) as donor_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'BENEFICIARY')) as beneficiary_count,
        COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'NGO') AND status = 'PENDING') as pending_ngo_count
      FROM users
    `);
    return result.rows[0];
  }

  async getAllDonations(status?: string, options: PaginationOptions = {}) {
    let baseQuery = `
      SELECT d.*, u.name as donor_name, u.email as donor_email, c.title as campaign_title
      FROM donations d
      LEFT JOIN users u ON u.id = d.donor_id
      LEFT JOIN campaigns c ON c.id = d.campaign_id
    `;
    const values: any[] = [];
    if (status && status !== 'ALL') {
      baseQuery += ` WHERE d.status = $1`;
      values.push(status);
    }
    
    const { query, values: finalValues } = this.applyPagination(baseQuery, options, values);
    const result = await pool.query(query, finalValues);
    
    const totalResult = await pool.query(`SELECT COUNT(*) FROM donations ${status && status !== 'ALL' ? 'WHERE status = $1' : ''}`, values);
    
    return {
      items: result.rows,
      total: parseInt(totalResult.rows[0].count, 10)
    };
  }

  async getAllWithdrawals(status?: string, options: PaginationOptions = {}) {
    let baseQuery = `
      SELECT w.*, u.name as ngo_name, u.email as ngo_email
      FROM withdrawals w
      LEFT JOIN users u ON u.id = w.ngo_user_id
    `;
    const values: any[] = [];
    if (status && status !== 'ALL') {
      baseQuery += ` WHERE w.status = $1`;
      values.push(status);
    }
    
    const { query, values: finalValues } = this.applyPagination(baseQuery, options, values);
    const result = await pool.query(query, finalValues);
    
    const totalResult = await pool.query(`SELECT COUNT(*) FROM withdrawals ${status && status !== 'ALL' ? 'WHERE status = $1' : ''}`, values);

    return {
      items: result.rows,
      total: parseInt(totalResult.rows[0].count, 10)
    };
  }

  async getAllCampaigns(options: PaginationOptions = {}) {
    const baseQuery = `
      SELECT c.*, np.org_name as ngo_name, u.name as created_by_name
      FROM campaigns c
      LEFT JOIN ngo_profiles np ON np.id = c.ngo_id
      LEFT JOIN users u ON u.id = c.created_by
    `;
    
    const { query, values: finalValues } = this.applyPagination(baseQuery, options, []);
    const result = await pool.query(query, finalValues);
    const totalResult = await pool.query(`SELECT COUNT(*) FROM campaigns`);

    return {
      items: result.rows,
      total: parseInt(totalResult.rows[0].count, 10)
    };
  }

  async getAllUsers(options: PaginationOptions = {}) {
    const baseQuery = `
      SELECT u.id, u.name, u.email, u.status, u.created_at, r.name as role
      FROM users u
      JOIN roles r ON r.id = u.role_id
    `;
    
    const { query, values: finalValues } = this.applyPagination(baseQuery, options, []);
    const result = await pool.query(query, finalValues);
    const totalResult = await pool.query(`SELECT COUNT(*) FROM users`);

    return {
      items: result.rows,
      total: parseInt(totalResult.rows[0].count, 10)
    };
  }

  async getAuditLogs(options: PaginationOptions = {}, filters: AuditLogFilters = {}) {
    let baseQuery = `
      SELECT al.*, u.name as admin_name, u.email as admin_email
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.admin_id
      WHERE 1=1
    `;
    const values: any[] = [];
    let paramIndex = 1;

    if (filters.admin_id) {
      baseQuery += ` AND al.admin_id = $${paramIndex++}`;
      values.push(filters.admin_id);
    }
    if (filters.action_type) {
      baseQuery += ` AND al.action_type = $${paramIndex++}`;
      values.push(filters.action_type);
    }
    if (filters.target_entity) {
      baseQuery += ` AND al.target_entity = $${paramIndex++}`;
      values.push(filters.target_entity);
    }
    if (filters.target_id) {
      baseQuery += ` AND al.target_id = $${paramIndex++}`;
      values.push(filters.target_id);
    }
    if (filters.from_date) {
      baseQuery += ` AND al.created_at >= $${paramIndex++}`;
      values.push(filters.from_date);
    }
    if (filters.to_date) {
      baseQuery += ` AND al.created_at <= $${paramIndex++}`;
      values.push(filters.to_date);
    }
    if (filters.metadata_filter) {
      for (const [key, val] of Object.entries(filters.metadata_filter)) {
        baseQuery += ` AND al.metadata->>$${paramIndex++} = $${paramIndex++}`;
        values.push(key, val);
      }
    }
    
    // Total count with filters
    const countQuery = `SELECT COUNT(*) FROM audit_logs al WHERE 1=1 ${baseQuery.split('WHERE 1=1')[1]}`;
    const totalResult = await pool.query(countQuery, values);

    const { query, values: finalValues } = this.applyPagination(baseQuery, options, values);
    const result = await pool.query(query, finalValues);

    return {
      items: result.rows,
      total: parseInt(totalResult.rows[0].count, 10)
    };
  }

  async getNgoDetail(id: number) {
    const ngoResult = await pool.query(`
      SELECT np.*, u.email, u.name as user_name, u.status as user_status
      FROM ngo_profiles np
      JOIN users u ON u.id = np.user_id
      WHERE np.id = $1
    `, [id]);

    if (ngoResult.rows.length === 0) throw createError('NGO not found', 404);
    const ngo = ngoResult.rows[0];

    const statsResult = await pool.query(`
      SELECT 
        COUNT(*) as total_campaigns,
        COUNT(*) FILTER (WHERE status = 'ACTIVE') as active_campaigns,
        COALESCE(SUM(raised_pkr), 0) as total_raised,
        COALESCE(SUM(spent_pkr), 0) as total_spent
      FROM campaigns
      WHERE ngo_id = $1
    `, [id]);

    const recentCampaigns = await pool.query(`
      SELECT id, title, status, raised_pkr, goal_pkr, created_at
      FROM campaigns
      WHERE ngo_id = $1
      ORDER BY created_at DESC
      LIMIT 10
    `, [id]);

    return {
      ngo,
      stats: statsResult.rows[0],
      recent_campaigns: recentCampaigns.rows
    };
  }

  async getDonationTrace(id: number) {
    const donationResult = await pool.query(`
      SELECT d.*, u.name as donor_name, u.email as donor_email,
             c.title as campaign_title, c.ngo_id
      FROM donations d
      LEFT JOIN users u ON u.id = d.donor_id
      LEFT JOIN campaigns c ON c.id = d.campaign_id
      WHERE d.id = $1
    `, [id]);

    if (donationResult.rows.length === 0) throw createError('Donation not found', 404);
    const donation = donationResult.rows[0];

    const ledgerEntries = await pool.query(`
      SELECT * FROM ledger_entries 
      WHERE ref_table = 'donations' AND ref_id = $1
      ORDER BY created_at DESC
    `, [id]);

    const auditLogs = await pool.query(`
      SELECT al.*, u.name as admin_name
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.admin_id
      WHERE target_entity = 'donations' AND target_id = $1
      ORDER BY created_at DESC
    `, [id]);

    return {
      donation,
      ledger_entries: ledgerEntries.rows,
      audit_logs: auditLogs.rows
    };
  }

  // --- NGO Verification ---

  async getPendingNgos() {
    const result = await pool.query(`
      SELECT np.*, u.email, u.name as user_name, u.created_at as user_joined_at
      FROM ngo_profiles np
      JOIN users u ON u.id = np.user_id
      WHERE np.status = 'PENDING'
      ORDER BY np.created_at ASC
    `);
    return result.rows;
  }

  async verifyNgo(id: number, adminId: number, ip: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const result = await client.query(
        `UPDATE ngo_profiles SET status = 'VERIFIED', verified_at = NOW() WHERE id = $1 RETURNING *`,
        [id]
      );
      
      if (result.rows.length === 0) throw createError('NGO profile not found', 404);
      const ngo = result.rows[0];

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'VERIFY_NGO', 'ngo_profiles', $2, $3, $4)`,
        [adminId, id, JSON.stringify({ org_name: ngo.org_name }), ip]
      );

      await client.query('COMMIT');
      return ngo;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async rejectNgo(id: number, adminId: number, reason: string, ip: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const result = await client.query(
        `UPDATE ngo_profiles SET status = 'REJECTED' WHERE id = $1 RETURNING *`,
        [id]
      );
      
      if (result.rows.length === 0) throw createError('NGO profile not found', 404);
      const ngo = result.rows[0];

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'REJECT_NGO', 'ngo_profiles', $2, $3, $4)`,
        [adminId, id, JSON.stringify({ org_name: ngo.org_name, reason }), ip]
      );

      await client.query('COMMIT');
      return ngo;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  // --- Financial Safety ---

  async flagDonation(id: number, adminId: number, reason: string, ip: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const result = await client.query(
        `UPDATE donations SET metadata = COALESCE(metadata, '{}'::jsonb) || $2::jsonb WHERE id = $1 RETURNING *`,
        [id, JSON.stringify({ disputed: true, dispute_reason: reason, flagged_at: new Date().toISOString() })]
      );
      
      if (result.rows.length === 0) throw createError('Donation not found', 404);

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'FLAG_DONATION', 'donations', $2, $3, $4)`,
        [adminId, id, JSON.stringify({ reason }), ip]
      );

      await client.query('COMMIT');
      return result.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async flagWithdrawal(id: number, adminId: number, reason: string, ip: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const result = await client.query(
        `UPDATE withdrawals SET metadata = COALESCE(metadata, '{}'::jsonb) || $2::jsonb WHERE id = $1 RETURNING *`,
        [id, JSON.stringify({ flagged: true, flag_reason: reason, flagged_at: new Date().toISOString() })]
      );
      
      if (result.rows.length === 0) throw createError('Withdrawal not found', 404);

      await client.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
         VALUES ($1, 'FLAG_WITHDRAWAL', 'withdrawals', $2, $3, $4)`,
        [adminId, id, JSON.stringify({ reason }), ip]
      );

      await client.query('COMMIT');
      return result.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async getLedger() {
    const { items: donations } = await this.getAllDonations('CONFIRMED', { limit: 1000 });
    const { items: withdrawals } = await this.getAllWithdrawals('APPROVED', { limit: 1000 });
    
    // Campaign financial flow
    const campaigns = await pool.query(`
      SELECT id, title, goal_pkr, raised_pkr, spent_pkr, (raised_pkr - spent_pkr) as remaining_balance
      FROM campaigns
      ORDER BY raised_pkr DESC
    `);

    return {
      donations,
      withdrawals,
      campaigns: campaigns.rows
    };
  }
}

export const adminService = new AdminService();
