import { z } from 'zod';

export const createDonationSchema = z.object({
  campaign_id: z.number().int().positive(),
  amount_pkr: z.number().positive().max(99999999.99),
  gateway_ref: z.string().max(255).optional(),
});

export const updateDonationSchema = z.object({
  status: z.enum(['PENDING', 'COMPLETED', 'FAILED', 'REFUNDED']),
  gateway_ref: z.string().max(255).optional(),
});

export const donationIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type CreateDonationInput = z.infer<typeof createDonationSchema>;
export type UpdateDonationInput = z.infer<typeof updateDonationSchema>;
