import { pool } from '../../config/database.js';
import { systemStateService } from '../../system/state/system.state.service.js';
import { systemStateStore } from '../../system/state/system.state.store.js';
import { STATE_DESCRIPTIONS } from '../../system/state/system.state.js';

export class AdminSnapshotService {
  async getSystemSnapshot() {
    const [users, donations, withdrawals, campaigns] = await Promise.all([
      pool.query(`
        SELECT
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'ADMIN'))       as admin_count,
          COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'NGO'))         as ngo_count,
          COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'VOLUNTEER'))   as volunteer_count,
          COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'COORDINATOR')) as coordinator_count,
          COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'DONOR'))       as donor_count,
          COUNT(*) FILTER (WHERE role_id = (SELECT id FROM roles WHERE name = 'BENEFICIARY')) as beneficiary_count,
          COUNT(*) FILTER (WHERE status = 'SUSPENDED') as suspended_count
        FROM users
      `),
      pool.query(`
        SELECT
          COUNT(*) FILTER (WHERE status = 'PENDING')   as pending,
          COUNT(*) FILTER (WHERE status = 'CONFIRMED')  as confirmed,
          COUNT(*) FILTER (WHERE status = 'REJECTED')   as rejected,
          COALESCE(SUM(amount_pkr) FILTER (WHERE status = 'CONFIRMED'), 0) as total_confirmed_pkr
        FROM donations
      `),
      pool.query(`
        SELECT
          COUNT(*) FILTER (WHERE status = 'PENDING')   as pending,
          COUNT(*) FILTER (WHERE status = 'APPROVED')  as approved,
          COUNT(*) FILTER (WHERE status = 'REJECTED')  as rejected,
          COALESCE(SUM(amount) FILTER (WHERE status = 'APPROVED'), 0) as total_approved_pkr
        FROM withdrawals
      `),
      pool.query(`
        SELECT
          COUNT(*)                    as total,
          COUNT(*) FILTER (WHERE status = 'ACTIVE') as active,
          COALESCE(SUM(raised_pkr), 0) as total_raised_pkr,
          COALESCE(SUM(goal_pkr), 0)   as total_goal_pkr,
          COALESCE(SUM(spent_pkr), 0)  as total_spent_pkr
        FROM campaigns
      `),
    ]);

    const u = users.rows[0];
    const d = donations.rows[0];
    const w = withdrawals.rows[0];
    const c = campaigns.rows[0];

    return {
      users: {
        total: Number(u.total),
        by_role: {
          admin: Number(u.admin_count),
          ngo: Number(u.ngo_count),
          volunteer: Number(u.volunteer_count),
          coordinator: Number(u.coordinator_count),
          donor: Number(u.donor_count),
          beneficiary: Number(u.beneficiary_count),
        },
        suspended: Number(u.suspended_count),
      },
      donations: {
        pending: Number(d.pending),
        confirmed: Number(d.confirmed),
        rejected: Number(d.rejected),
        total_confirmed_pkr: parseFloat(d.total_confirmed_pkr),
      },
      withdrawals: {
        pending: Number(w.pending),
        approved: Number(w.approved),
        rejected: Number(w.rejected),
        total_approved_pkr: parseFloat(w.total_approved_pkr),
      },
      campaigns: {
        total: Number(c.total),
        active: Number(c.active),
        total_raised_pkr: parseFloat(c.total_raised_pkr),
        total_goal_pkr: parseFloat(c.total_goal_pkr),
        total_spent_pkr: parseFloat(c.total_spent_pkr),
      },
      generated_at: new Date().toISOString(),
      system: (() => {
        const state = systemStateService.getCurrentState();
        return {
          state,
          description: STATE_DESCRIPTIONS[state],
          allowed_actions: systemStateService.getAllowedActions(),
          blocked_categories: systemStateService.getBlockedCategories(),
          state_persistence: {
            source: systemStateStore.getPersistenceSource(),
            last_updated: systemStateStore.getLastUpdatedAt(),
            recovery_status: systemStateStore.getRecoveryStatus(),
          },
        };
      })(),
    };
  }

  async getOperationalOverview() {
    const [pendingApprovals, tasks] = await Promise.all([
      pool.query(`
        SELECT
          COUNT(*) FILTER (WHERE entity = 'donation') as donation_count,
          COUNT(*) FILTER (WHERE entity = 'withdrawal') as withdrawal_count,
          COUNT(*) FILTER (WHERE entity = 'delivery') as delivery_count,
          MIN(CASE WHEN entity = 'donation'   THEN created_at END) as oldest_donation_at,
          MIN(CASE WHEN entity = 'withdrawal' THEN created_at END) as oldest_withdrawal_at,
          MIN(CASE WHEN entity = 'delivery'   THEN created_at END) as oldest_delivery_at
        FROM (
          SELECT 'donation'   AS entity, created_at FROM donations   WHERE status = 'PENDING'
          UNION ALL
          SELECT 'withdrawal' AS entity, created_at FROM withdrawals WHERE status = 'PENDING'
          UNION ALL
          SELECT 'delivery'   AS entity, submitted_at as created_at FROM deliveries WHERE verified_at IS NULL
        ) pending
      `),
      pool.query(`
        SELECT
          COUNT(*) FILTER (WHERE status = 'OPEN')                 as open,
          COUNT(*) FILTER (WHERE status = 'CLAIMED')              as claimed,
          COUNT(*) FILTER (WHERE status = 'IN_PROGRESS')          as in_progress,
          COUNT(*) FILTER (WHERE status = 'SUBMITTED')            as submitted,
          COUNT(*) FILTER (WHERE status IN ('COORDINATOR_VERIFIED','PAID')) as completed
        FROM tasks
      `),
    ]);

    const p = pendingApprovals.rows[0];
    const t = tasks.rows[0];

    const hoursAgo = (ts: string | null): number | null => {
      if (!ts) return null;
      return Math.round((Date.now() - new Date(ts).getTime()) / 3_600_000);
    };

    return {
      pending: {
        donations: Number(p.donation_count),
        withdrawals: Number(p.withdrawal_count),
        deliveries: Number(p.delivery_count),
      },
      oldest_pending_hours: {
        donation: hoursAgo(p.oldest_donation_at),
        withdrawal: hoursAgo(p.oldest_withdrawal_at),
        delivery: hoursAgo(p.oldest_delivery_at),
      },
      tasks: {
        open: Number(t.open),
        claimed: Number(t.claimed),
        in_progress: Number(t.in_progress),
        submitted: Number(t.submitted),
        completed: Number(t.completed),
      },
      generated_at: new Date().toISOString(),
    };
  }
}

export const adminSnapshotService = new AdminSnapshotService();
