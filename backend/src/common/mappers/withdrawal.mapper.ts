/**
 * Withdrawal Mapper
 */
export const mapWithdrawal = (raw: any) => {
  return {
    id: Number(raw.id),
    ngo_user_id: raw.ngo_user_id ? Number(raw.ngo_user_id) : null,
    amount: raw.amount ? parseFloat(raw.amount) : 0,
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

export const mapWithdrawalList = (rawList: any[]) => {
  return {
    data: rawList.map(mapWithdrawal),
    meta: {
      total: rawList.length,
    },
  };
};
