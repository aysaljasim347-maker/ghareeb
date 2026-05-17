import { pool } from '../../config/database.js';
import { deliveriesService } from '../../modules/deliveries/deliveries.service.js';
import { VerifyDeliveryCommand } from './admin.command.types.js';

async function writeAuditLog(
  adminId: number,
  actionType: string,
  targetId: number,
  metadata: Record<string, unknown>,
  ipAddress?: string
): Promise<void> {
  try {
    await pool.query(
      `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata, ip_address)
       VALUES ($1, $2, 'deliveries', $3, $4, $5)`,
      [adminId, actionType, targetId, JSON.stringify(metadata), ipAddress || null]
    );
  } catch {
    // best-effort: audit failure does not roll back the committed action
  }
}

export async function handleDeliveryCommand(command: VerifyDeliveryCommand) {
  const result = await deliveriesService.verifyDelivery(
    command.targetId,
    command.actorAdminId,
    { 
      verified: command.metadata.verified, 
      notes: command.metadata.notes,
      outcome: command.metadata.outcome
    }
  );
  
  const outcome = command.metadata.outcome || (command.metadata.verified ? 'VERIFY' : 'FLAG');
  let actionType = 'VERIFY_DELIVERY';
  if (outcome === 'FLAG') actionType = 'FLAG_DELIVERY';
  if (outcome === 'REJECT') actionType = 'REJECT_DELIVERY';

  await writeAuditLog(command.actorAdminId, actionType, command.targetId, {
    outcome: outcome,
    notes: command.metadata.notes
  }, command.ipAddress);
  return result;
}
