import { z } from 'zod';

export const createGoodsCampaignSchema = z.object({
  title:          z.string().min(3).max(255),
  item_needed:    z.string().min(1).max(255),
  category:       z.string().min(1).max(100),
  category_other: z.string().max(255).optional(),
  target_qty:     z.number().positive(),
  unit:           z.string().min(1).max(50),
  description:    z.string().min(10),
  location_text:  z.string().min(1),
  latitude:       z.number().min(-90).max(90).optional(),
  longitude:      z.number().min(-180).max(180).optional(),
  deadline:       z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'deadline must be YYYY-MM-DD'),
  cover_image_url: z.string().url().optional(),
});

export const updateGoodsCampaignSchema = createGoodsCampaignSchema
  .partial()
  .extend({
    status: z.enum(['ACTIVE', 'PAUSED', 'CLOSED', 'DRAFT']).optional(),
  });

export const campaignIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type CreateGoodsCampaignInput = z.infer<typeof createGoodsCampaignSchema>;
export type UpdateGoodsCampaignInput = z.infer<typeof updateGoodsCampaignSchema>;
