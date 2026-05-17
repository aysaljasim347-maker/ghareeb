import { z } from 'zod';

export const submitDeliverySchema = z.object({
  task_id: z.number().int().positive(),
  photo_urls: z.array(z.string().url()).min(1, 'At least one photo is required'),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  notes: z.string().optional(),
});

export const verifyDeliverySchema = z.object({
  verified: z.boolean(),
  outcome: z.enum(['VERIFY', 'FLAG', 'REJECT']).optional(),
  notes: z.string().optional(),
});

export const deliveryIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type SubmitDeliveryInput = z.infer<typeof submitDeliverySchema>;
export type VerifyDeliveryInput = z.infer<typeof verifyDeliverySchema>;
