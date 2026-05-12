import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { chatService } from './chat.service.js';

export class ChatController {
  async createRoom(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const { taskId } = req.body;
      const room = await chatService.createRoom(taskId, req.user.id);
      res.status(201).json(room);
    } catch (err) { next(err); }
  }

  async sendMessage(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const roomId = parseInt(req.params.roomId as string, 10);
      const { text } = req.body;
      const message = await chatService.sendMessage(roomId, req.user.id, text);
      res.status(201).json(message);
    } catch (err) { next(err); }
  }

  async getMessages(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const roomId = parseInt(req.params.roomId as string, 10);
      const limit = parseInt(req.query.limit as string, 10) || 50;
      const offset = parseInt(req.query.offset as string, 10) || 0;
      const messages = await chatService.getMessages(roomId, limit, offset);
      res.json({ messages });
    } catch (err) { next(err); }
  }

  async getMyRooms(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) { res.status(401).json({ error: 'Auth required' }); return; }
      const rooms = await chatService.getUserRooms(req.user.id);
      res.json({ rooms });
    } catch (err) { next(err); }
  }
}

export const chatController = new ChatController();
