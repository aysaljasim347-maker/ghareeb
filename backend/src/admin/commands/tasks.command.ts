import { UpdateTaskInput } from '../../modules/tasks/tasks.schema.js';
import { tasksService } from '../../modules/tasks/tasks.service.js';
import { UpdateTaskCommand } from './admin.command.types.js';

export async function handleTaskCommand(command: UpdateTaskCommand) {
  return tasksService.updateTask(
    command.targetId,
    command.metadata as UpdateTaskInput,
    command.actorAdminId,
    'ADMIN'
  );
}
