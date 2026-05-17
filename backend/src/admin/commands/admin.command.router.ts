import { AdminCommand } from './admin.command.types.js';
import { handleDonationCommand } from './donations.command.js';
import { handleWithdrawalCommand } from './withdrawals.command.js';
import { handleUserCommand } from './users.command.js';
import { handleCampaignCommand } from './campaigns.command.js';
import { handleDeliveryCommand } from './deliveries.command.js';
import { handleTaskCommand } from './tasks.command.js';
import { handleSetSystemStateCommand } from './set-system-state.command.js';
import { systemStateService } from '../../system/state/system.state.service.js';
import { createError } from '../../middleware/errorHandler.js';

export async function executeAdminCommand(command: AdminCommand): Promise<unknown> {
  if (!systemStateService.isAllowed(command.type)) {
    throw createError(
      `Action '${command.type}' is blocked in system state '${systemStateService.getCurrentState()}'`,
      503,
    );
  }

  if (systemStateService.getCurrentState() === 'HIGH_LOAD') {
    console.warn('[HIGH_LOAD]', command.type, 'actorAdminId:', command.actorAdminId);
  }

  switch (command.type) {
    case 'APPROVE_DONATION':
    case 'REJECT_DONATION':
      return handleDonationCommand(command);

    case 'APPROVE_WITHDRAWAL':
    case 'REJECT_WITHDRAWAL':
      return handleWithdrawalCommand(command);

    case 'SUSPEND_USER':
    case 'REACTIVATE_USER':
      return handleUserCommand(command);

    case 'UPDATE_CAMPAIGN_STATUS':
      return handleCampaignCommand(command);

    case 'VERIFY_DELIVERY':
      return handleDeliveryCommand(command);

    case 'UPDATE_TASK':
      return handleTaskCommand(command);

    case 'SET_SYSTEM_STATE':
      return handleSetSystemStateCommand(command);
  }
}
