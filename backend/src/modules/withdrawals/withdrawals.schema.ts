import { z } from 'zod';

export const createWithdrawalSchema = z.object({
  amount:       z.number().positive().max(99999999.99),
  bank_account: z.string().min(1).max(500),
});

export const withdrawalIdParam = z.object({
  id: z.coerce.number().int().positive(),
});

export type CreateWithdrawalInput = z.infer<typeof createWithdrawalSchema>;
