import { z } from 'zod';

export const createTaskSchema = z.object({
  campaign_id: z.number().int().positive().optional(),
  beneficiary_id: z.number().int().positive().optional(),
  source_type: z.enum(['BENEFICIARY_REQUEST', 'NGO_CAMPAIGN', 'PLATFORM_CAMPAIGN', 'ADMIN_CREATED']),
  title: z.string().min(1).max(500),
  description: z.string().optional(),
  category: z.string().max(50).optional(),
  family_size: z.number().int().positive().default(1),
  items_needed: z.array(z.any()).default([]),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  location_text: z.string().optional(),
  radius_km: z.number().int().positive().default(5),
  budget_pkr: z.number().min(0).default(0),
  urgency: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).default('MEDIUM'),
});

export const updateTaskSchema = z.object({
  title: z.string().min(1).max(500).optional(),
  description: z.string().optional(),
  category: z.string().max(50).optional(),
  family_size: z.number().int().positive().optional(),
  items_needed: z.array(z.object({
    item: z.string().max(100),
    quantity: z.string().or(z.number()),
  })).max(100).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  location_text: z.string().optional(),
  radius_km: z.number().int().positive().optional(),
  budget_pkr: z.number().min(0).optional(),
  urgency: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
});

export const taskIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type CreateTaskInput = z.infer<typeof createTaskSchema>;
export type UpdateTaskInput = z.infer<typeof updateTaskSchema>;
