export type WithdrawalStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export interface Withdrawal {
  id: number;
  ngo_user_id: number;
  amount: number;
  status: WithdrawalStatus;
  bank_account: string;
  created_at: string;
  ngo_name?: string;
  ngo_email?: string;
}
