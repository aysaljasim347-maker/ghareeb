import { pool } from '../../config/database.js';
import { usersService } from '../../modules/users/users.service.js';
import { ReactivateUserCommand, SuspendUserCommand } from './admin.command.types.js';

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
       VALUES ($1, $2, 'users', $3, $4, $5)`,
      [adminId, actionType, targetId, JSON.stringify(metadata), ipAddress || null]
    );
  } catch {
    // best-effort: audit failure does not roll back the committed action
  }
}

export async function handleUserCommand(
  command: SuspendUserCommand | ReactivateUserCommand
) {
  if (command.type === 'SUSPEND_USER') {
    const result = await usersService.suspendUser(command.targetId, command.actorAdminId);
    await writeAuditLog(command.actorAdminId, 'SUSPEND_USER', command.targetId, command.metadata ?? {}, command.ipAddress);
    return result;
  }
  const result = await usersService.reactivateUser(command.targetId);
  await writeAuditLog(command.actorAdminId, 'REACTIVATE_USER', command.targetId, {}, command.ipAddress);
  return result;
}
