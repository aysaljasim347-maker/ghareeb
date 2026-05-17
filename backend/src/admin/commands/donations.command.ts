import { donationsService } from '../../modules/donations/donations.service.js';
import { ApproveDonationCommand, RejectDonationCommand } from './admin.command.types.js';

export async function handleDonationCommand(
  command: ApproveDonationCommand | RejectDonationCommand
) {
  if (command.type === 'APPROVE_DONATION') {
    return donationsService.approveDonation(command.targetId, command.actorAdminId, command.ipAddress);
  }
  return donationsService.rejectDonation(command.targetId, command.actorAdminId, command.ipAddress);
}
