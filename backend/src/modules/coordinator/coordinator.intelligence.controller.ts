import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { coordinatorIntelligenceService } from './coordinator.intelligence.service.js';
import { broadcastService } from './broadcast.service.js';

export class CoordinatorIntelligenceController {
  async getIntelligence(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const data = await coordinatorIntelligenceService.getOperationalIntelligence(req.user.id);
      res.json({ data });
    } catch (err) { next(err); }
  }

  async getSignals(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const data = await coordinatorIntelligenceService.getFraudSignals(req.user.id);
      res.json({ data });
    } catch (err) { next(err); }
  }

  async flagFraud(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const { entity, id, payload } = req.body;
      const ip = req.ip || 'unknown';
      const result = await coordinatorIntelligenceService.flagFraud(req.user.id, entity, id, payload, ip);
      res.json(result);
    } catch (err) { next(err); }
  }

  async escalate(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const { entity, id, payload } = req.body;
      const ip = req.ip || 'unknown';
      const result = await coordinatorIntelligenceService.escalateIssue(req.user.id, entity, id, payload, ip);
      res.json(result);
    } catch (err) { next(err); }
  }

  async emergencyEscalate(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const ip = req.ip || 'unknown';
      const result = await coordinatorIntelligenceService.emergencyEscalate(req.user.id, req.body, ip);
      res.json(result);
    } catch (err) { next(err); }
  }

  async getReports(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const period = (req.params.period as string) || 'daily';
      const data = await coordinatorIntelligenceService.getInsightReports(req.user.id, period);
      res.json({ data });
    } catch (err) { next(err); }
  }

  async getEscalations(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const data = await coordinatorIntelligenceService.getEscalationHistory(req.user.id);
      res.json({ data });
    } catch (err) { next(err); }
  }

  async broadcast(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.user) return;
      const ip = req.ip || 'unknown';
      const result = await broadcastService.broadcast({ ...req.body, senderId: req.user.id }, ip);
      res.json(result);
    } catch (err) { next(err); }
  }
}

export const coordinatorIntelligenceController = new CoordinatorIntelligenceController();
