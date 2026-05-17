import { v2 as cloudinary } from 'cloudinary';
import { env } from '../../config/env.js';
import { createError } from '../../middleware/errorHandler.js';
import { logger } from '../common/logger.js';

cloudinary.config({
  cloud_name: env.CLOUDINARY_CLOUD_NAME,
  api_key: env.CLOUDINARY_API_KEY,
  api_secret: env.CLOUDINARY_API_SECRET,
});

export class CloudinaryService {
  /**
   * Upload an image from a buffer or file path.
   */
  async uploadImage(fileBuffer: Buffer, folder: string = 'disasteraid'): Promise<string> {
    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder,
          resource_type: 'image',
          quality: 'auto',
          fetch_format: 'auto',
        },
        (error, result) => {
          if (error) {
            logger.error('[CLOUDINARY] Upload failed', { error });
            return reject(createError('Image upload failed', 500));
          }
          if (!result) {
            return reject(createError('Image upload failed: no result', 500));
          }
          resolve(result.secure_url);
        }
      );

      uploadStream.end(fileBuffer);
    });
  }

  /**
   * Delete an image from Cloudinary by its public ID.
   */
  async deleteImage(publicId: string): Promise<void> {
    try {
      await cloudinary.uploader.destroy(publicId);
    } catch (error) {
      logger.error('[CLOUDINARY] Delete failed', { publicId, error });
    }
  }
}

export const cloudinaryService = new CloudinaryService();
