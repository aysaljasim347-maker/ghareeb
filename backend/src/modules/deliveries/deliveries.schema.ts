import { z } from 'zod';

export const submitDeliverySchema = z.object({
  task_id: z.number().int().positive(),
  storage_keys: z.array(z.string().min(1)).min(1, 'At least one storage key is required'),
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
