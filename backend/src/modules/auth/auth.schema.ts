import { z } from 'zod';

export const registerSchema = z.object({
  email: z.string().email().optional(),
  phone: z.string().min(10).max(20).optional(),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(255),
  role: z.enum(['DONOR', 'BENEFICIARY', 'VOLUNTEER', 'NGO', 'COORDINATOR']),
  cnic: z.string().max(15).optional(),
  locale: z.string().max(5).default('en'),
}).refine((data) => data.email || data.phone, {
  message: 'Either email or phone is required',
});

export const loginSchema = z.object({
  email: z.string().email().optional(),
  phone: z.string().min(10).max(20).optional(),
  password: z.string().min(1),
}).refine((data) => data.email || data.phone, {
  message: 'Either email or phone is required',
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
