import { z } from 'zod';

export const createCampaignSchema = z.object({
  title: z.string().min(1).max(255),
  description: z.string().optional(),
  goal_pkr: z.number().positive().max(999999999999.99),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

export const updateCampaignSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  description: z.string().optional(),
  goal_pkr: z.number().positive().optional(),
  status: z.enum(['DRAFT', 'PENDING_APPROVAL', 'ACTIVE', 'PAUSED', 'CLOSED', 'REJECTED', 'COMPLETED']).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

export const campaignIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type CreateCampaignInput = z.infer<typeof createCampaignSchema>;
export type UpdateCampaignInput = z.infer<typeof updateCampaignSchema>;
