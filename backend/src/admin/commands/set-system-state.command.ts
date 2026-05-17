import { systemStateService } from '../../system/state/system.state.service.js';
import { SetSystemStateCommand } from './admin.command.types.js';

export async function handleSetSystemStateCommand(command: SetSystemStateCommand) {
  return systemStateService.setState(
    command.metadata.state,
    command.actorAdminId,
    command.metadata.reason,
  );
}
