import { UpdateCampaignInput } from '../../modules/campaigns/campaigns.schema.js';
import { campaignsService } from '../../modules/campaigns/campaigns.service.js';
import { UpdateCampaignStatusCommand } from './admin.command.types.js';

export async function handleCampaignCommand(command: UpdateCampaignStatusCommand) {
  return campaignsService.update(
    command.targetId,
    { status: command.metadata.status } as UpdateCampaignInput,
    command.actorAdminId,
    command.ipAddress,
    'ADMIN'
  );
}
