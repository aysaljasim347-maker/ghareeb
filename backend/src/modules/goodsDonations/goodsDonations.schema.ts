import { z } from 'zod';

export const submitGoodsDonationSchema = z.object({
  campaign_id:     z.number().int().positive(),
  item_name:       z.string().min(1).max(255),
  category:        z.string().min(1).max(100),
  description:     z.string().min(5),
  photo_url:       z.string().url().optional(),
  quantity:        z.number().positive(),
  unit:            z.string().min(1).max(50),
  pickup_address:  z.string().min(1),
  pickup_lat:      z.number().min(-90).max(90).optional(),
  pickup_lng:      z.number().min(-180).max(180).optional(),
  contact_number:  z.string().min(5).max(20),
});

export const deliverGoodsDonationSchema = z.object({
  proof_photo_url: z.string().url(),
  qty_confirmed:   z.number().positive(),
  volunteer_note:  z.string().max(1000).optional(),
});

export const rejectGoodsDonationSchema = z.object({
  rejection_reason: z.string().min(5).max(1000),
});

export const overrideGoodsDonationSchema = z.object({
  status:          z.enum(['PENDING', 'ASSIGNED', 'DELIVERED', 'APPROVED', 'REJECTED']),
  rejection_reason: z.string().max(1000).optional(),
  note:            z.string().max(1000).optional(),
});

export const donationIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type SubmitGoodsDonationInput   = z.infer<typeof submitGoodsDonationSchema>;
export type DeliverGoodsDonationInput  = z.infer<typeof deliverGoodsDonationSchema>;
export type RejectGoodsDonationInput   = z.infer<typeof rejectGoodsDonationSchema>;
export type OverrideGoodsDonationInput = z.infer<typeof overrideGoodsDonationSchema>;
