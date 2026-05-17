import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { tasksService } from './tasks.service.js';
import { CreateTaskInput, UpdateTaskInput } from './tasks.schema.js';
import { mapTask, mapTaskList } from '../../common/mappers/task.mapper.js';

export class TasksController {
  async create(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const task = await tasksService.createTask(req.body as CreateTaskInput, req.user.id);
      res.status(201).json(mapTask(task));
    } catch (err) { next(err); }
  }

  async getAvailable(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const source = req.query.source as string | undefined;
      const zoom = req.query.zoom ? parseInt(req.query.zoom as string, 10) : undefined;
      const bbox = req.query.bbox as string | undefined;

      const data = await tasksService.getAvailableTasks(source, zoom, bbox);
      res.json(data);
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

      res.json(mapTask(task));
    } catch (err) { next(err); }
  }

  async getMyTasks(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const tasks = await tasksService.getMyTasks(req.user.id);
      res.json(mapTaskList(tasks));
    } catch (err) { next(err); }
  }

  async getCoordinatorTasks(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const tasks = await tasksService.getCoordinatorTasks(req.user.id);
      res.json(mapTaskList(tasks));
    } catch (err) { next(err); }
  }

  async update(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const id = parseInt(req.params.id as string, 10);
      const task = await tasksService.updateTask(id, req.body as UpdateTaskInput, req.user.id, req.user.role);
      res.json(mapTask(task));
    } catch (err) { next(err); }
  }

  async claim(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const taskId = parseInt(req.params.id as string, 10);
      const task = await tasksService.claimTask(taskId, req.user.id);
      res.json({ 
        message: 'Task claimed successfully', 
        data: mapTask(task)
      });
    } catch (err) { next(err); }
  }

  async start(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const taskId = parseInt(req.params.id as string, 10);
      const task = await tasksService.startTask(taskId, req.user.id);
      res.json({ 
        message: 'Task started', 
        data: mapTask(task) 
      });
    } catch (err) { next(err); }
  }

  async unclaim(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const taskId = parseInt(req.params.id as string, 10);
      const task = await tasksService.unclaimTask(taskId, req.user.id);
      res.json({ 
        message: 'Task unclaimed', 
        data: mapTask(task) 
      });
    } catch (err) { next(err); }
  }

  async getEvents(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const taskId = parseInt(req.params.id as string, 10);
      const events = await tasksService.getTaskEvents(taskId);
      res.json({
        data: events.map(e => ({
          ...e,
          id: Number(e.id),
          task_id: Number(e.task_id),
          user_id: e.user_id ? Number(e.user_id) : null,
          created_at: new Date(e.created_at).toISOString()
        })),
        meta: { total: events.length }
      });
    } catch (err) { next(err); }
  }
}

export const tasksController = new TasksController();
