import { z } from 'zod';

export const createDonationSchema = z.object({
  campaign_id:      z.number().int().positive(),
  amount_pkr:       z.number().positive().max(99999999.99),
  reference_number: z.string().min(1).max(255),
  receipt_url:      z.string().url().optional(),
});

export const donationIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type CreateDonationInput = z.infer<typeof createDonationSchema>;
