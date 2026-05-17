import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { cloudinaryService } from './cloudinary.service.js';
import { createError } from '../../middleware/errorHandler.js';

export class MediaController {
  async upload(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      if (!req.file) {
        throw createError('No image file provided', 400);
      }

      // Default folder based on role or context if needed, otherwise 'general'
      const folder = req.user?.role ? `disasteraid/${req.user.role.toLowerCase()}` : 'disasteraid/general';
      
      const url = await cloudinaryService.uploadImage(req.file.buffer, folder);

      res.status(201).json({ url });
    } catch (err) {
      next(err);
    }
  }
}

export const mediaController = new MediaController();
