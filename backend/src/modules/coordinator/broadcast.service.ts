import { pool } from '../../config/database.js';
import { createError } from '../../middleware/errorHandler.js';
import { emitToUser } from '../chat/chat.gateway.js';

export interface BroadcastPayload {
  type: 'COORDINATOR_BROADCAST';
  scope: 'REGION' | 'CAMPAIGN' | 'TASK' | 'NGO';
  targetId: string;
  message: string;
  urgency: 'LOW' | 'MEDIUM' | 'HIGH';
  senderId: number;
}

export class BroadcastService {
  /**
   * Broadcast an alert to a specific target scope.
   */
  async broadcast(payload: BroadcastPayload, ip: string) {
    // 1. Persist in audit logs as an immutable record
    await pool.query(
      `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
       VALUES ($1, 'COORDINATOR_BROADCAST', $2, $3, $4, $5)`,
      [
        payload.senderId,
        'broadcast_scope',
        0, // Generic ID for broadcast entity
        JSON.stringify({
          scope: payload.scope,
          target_id: payload.targetId,
          message: payload.message,
          urgency: payload.urgency,
          timestamp: new Date().toISOString()
        }),
        ip
      ]
    );

    // 2. Identify target users based on scope
    const userIds = await this.getTargetUserIds(payload.scope, payload.targetId);

    // 3. Emit via Socket.IO to each user's private room
    for (const userId of userIds) {
      emitToUser(userId, 'broadcast_alert', {
        title: `Operational Alert (${payload.urgency})`,
        message: payload.message,
        urgency: payload.urgency,
        timestamp: new Date().toISOString(),
        sender_id: payload.senderId
      });
    }

    return { total_notified: userIds.length };
  }

  private async getTargetUserIds(scope: string, targetId: string): Promise<number[]> {
    const id = parseInt(targetId, 10);
    let query = '';
    let values: any[] = [];

    switch (scope) {
      case 'TASK':
        // Volunteers assigned to this task + beneficiary
        query = 'SELECT claimed_by as user_id, beneficiary_id FROM tasks WHERE id = $1';
        values = [id];
        break;
      case 'CAMPAIGN':
        // All volunteers working on any task in this campaign
        query = 'SELECT DISTINCT claimed_by as user_id FROM tasks WHERE campaign_id = $1 AND claimed_by IS NOT NULL';
        values = [id];
        break;
      case 'NGO':
        // NGO team members (created_by for NGO tasks)
        query = 'SELECT user_id FROM ngo_profiles WHERE id = $1';
        values = [id];
        break;
      default:
        throw createError(`Broadcast scope '${scope}' is not yet supported`, 501);
    }

    const result = await pool.query(query, values);
    const ids = new Set<number>();
    for (const row of result.rows) {
      if (row.user_id) ids.add(row.user_id);
      if (row.beneficiary_id) ids.add(row.beneficiary_id);
    }
    return Array.from(ids);
  }
}

export const broadcastService = new BroadcastService();
