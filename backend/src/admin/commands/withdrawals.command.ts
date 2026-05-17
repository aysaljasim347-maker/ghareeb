import { withdrawalsService } from '../../modules/withdrawals/withdrawals.service.js';
import { ApproveWithdrawalCommand, RejectWithdrawalCommand } from './admin.command.types.js';

export async function handleWithdrawalCommand(
  command: ApproveWithdrawalCommand | RejectWithdrawalCommand
) {
  if (command.type === 'APPROVE_WITHDRAWAL') {
    return withdrawalsService.approveWithdrawal(command.targetId, command.actorAdminId, command.ipAddress);
  }
  return withdrawalsService.rejectWithdrawal(command.targetId, command.actorAdminId, command.ipAddress);
}
