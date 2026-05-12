import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { tasksService } from './tasks.service.js';
import { CreateTaskInput, UpdateTaskInput } from './tasks.schema.js';

export class TasksController {
  async create(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const task = await tasksService.createTask(req.body as CreateTaskInput, req.user.id);
      res.status(201).json(task);
    } catch (err) { next(err); }
  }

  async getAvailable(_req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const tasks = await tasksService.getAvailableTasks();
      res.json({ tasks, count: tasks.length });
    } catch (err) { next(err); }
  }

  async getById(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const task = await tasksService.getTaskById(id);

      // Record view if authenticated
      if (req.user) {
        await tasksService.recordView(id, req.user.id);
      }

      res.json(task);
    } catch (err) { next(err); }
  }

  async update(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = parseInt(req.params.id as string, 10);
      const task = await tasksService.updateTask(id, req.body as UpdateTaskInput);
      res.json(task);
    } catch (err) { next(err); }
  }

  async claim(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const taskId = parseInt(req.params.id as string, 10);
      const task = await tasksService.claimTask(taskId, req.user.id);
      res.json({ message: 'Task claimed successfully', task });
    } catch (err) { next(err); }
  }

  async getEvents(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const taskId = parseInt(req.params.id as string, 10);
      const events = await tasksService.getTaskEvents(taskId);
      res.json({ events });
    } catch (err) { next(err); }
  }
}

export const tasksController = new TasksController();
