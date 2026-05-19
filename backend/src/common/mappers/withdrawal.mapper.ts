/**
 * Withdrawal Mapper
 */

interface WithdrawalRow {
  id: string | number;
  ngo_user_id?: string | number | null;
  amount?: string | number | null;
  bank_account?: string | null;
  status?: string | null;
  ngo_name?: string | null;
  ngo_email?: string | null;
  approved_by?: string | number | null;
  rejected_by?: string | number | null;
  created_at?: string | Date | null;
  updated_at?: string | Date | null;
}

export const mapWithdrawal = (raw: WithdrawalRow) => {
  return {
    id: Number(raw.id),
    ngo_user_id: raw.ngo_user_id ? Number(raw.ngo_user_id) : null,
    amount: raw.amount ? parseFloat(raw.amount.toString()) : 0,
    bank_account: raw.bank_account || '',
    status: raw.status || 'PENDING',
    ngo_name: raw.ngo_name || null,
    ngo_email: raw.ngo_email || null,
    approved_by: raw.approved_by ? Number(raw.approved_by) : null,
    rejected_by: raw.rejected_by ? Number(raw.rejected_by) : null,
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
    updated_at: raw.updated_at ? new Date(raw.updated_at).toISOString() : null,
  };
};

export const mapWithdrawalList = (rawList: WithdrawalRow[]) => {
  return {
    data: rawList.map(mapWithdrawal),
    meta: {
      total: rawList.length,
    },
  };
};
