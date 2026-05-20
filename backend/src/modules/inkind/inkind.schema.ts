import { z } from 'zod';

export const createInKindDonationSchema = z.object({
  title:        z.string().min(3).max(255),
  description:  z.string().max(1000).optional(),
  photo_url:    z.string().min(1).optional(),
  address_text: z.string().min(3),
  latitude:     z.number().min(-90).max(90),
  longitude:    z.number().min(-180).max(180),
});

export const createInKindRequestSchema = z.object({
  message: z.string().max(500).optional(),
  phone:   z.string().min(7).max(30),
  email:   z.string().email().optional(),
});

export const acceptRequestSchema = z.object({
  donor_shared_phone: z.string().max(30).optional(),
});

export const donationIdParam  = z.object({ id:        z.coerce.number().int().positive() });
export const requestIdParam   = z.object({ requestId: z.coerce.number().int().positive() });

export type CreateInKindDonationInput = z.infer<typeof createInKindDonationSchema>;
export type CreateInKindRequestInput  = z.infer<typeof createInKindRequestSchema>;
export type AcceptRequestInput        = z.infer<typeof acceptRequestSchema>;
