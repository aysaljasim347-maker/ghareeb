import { pool } from '../../config/database.js';
import { AdminCommandType, BLOCKED_CATEGORIES, STATE_DESCRIPTIONS, STATE_POLICY, SystemState } from './system.state.js';
import { systemStateStore } from './system.state.store.js';

class SystemStateService {
  getCurrentState(): SystemState {
    return systemStateStore.getState();
  }

  isAllowed(commandType: AdminCommandType): boolean {
    const policy = STATE_POLICY[this.getCurrentState()];
    if (policy === 'ALL') return true;
    return policy.has(commandType);
  }

  getBlockedCategories(): string[] {
    return BLOCKED_CATEGORIES[this.getCurrentState()];
  }

  getAllowedActions(): 'ALL' | AdminCommandType[] {
    const policy = STATE_POLICY[this.getCurrentState()];
    if (policy === 'ALL') return 'ALL';
    return Array.from(policy);
  }

  async setState(
    newState: SystemState,
    actorAdminId: number,
    reason?: string,
  ): Promise<{ previous_state: SystemState; current_state: SystemState }> {
    const previous = this.getCurrentState();
    // DB-first: throws if write fails — memory stays in previous state
    await systemStateStore.setState(newState, actorAdminId, reason);
    // DB + memory both updated — write audit best-effort
    await this.writeTransitionAudit(previous, newState, actorAdminId, reason);
    return { previous_state: previous, current_state: newState };
  }

  private async writeTransitionAudit(
    previousState: SystemState,
    newState: SystemState,
    actorAdminId: number,
    reason?: string,
  ): Promise<void> {
    try {
      await pool.query(
        `INSERT INTO audit_logs (admin_id, action_type, target_entity, target_id, metadata)
         VALUES ($1, 'SET_SYSTEM_STATE', 'system', 0, $2)`,
        [
          actorAdminId,
          JSON.stringify({
            previous_state: previousState,
            new_state: newState,
            description: STATE_DESCRIPTIONS[newState],
            reason: reason ?? null,
            timestamp: new Date().toISOString(),
          }),
        ],
      );
    } catch {
      // best-effort
    }
  }
}

export const systemStateService = new SystemStateService();
