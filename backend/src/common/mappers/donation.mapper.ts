/**
 * Donation Mapper
 */
export const mapDonation = (raw: any) => {
  return {
    id: Number(raw.id),
    donor_id: raw.donor_id ? Number(raw.donor_id) : null,
    campaign_id: raw.campaign_id ? Number(raw.campaign_id) : null,
    amount_pkr: raw.amount_pkr ? parseFloat(raw.amount_pkr) : 0,
    status: raw.status || 'PENDING',
    payment_method: raw.payment_method || 'BANK_TRANSFER',
    receipt_url: raw.receipt_url || null,
    gateway_ref: raw.gateway_ref || null,
    donor_name: raw.donor_name || null,
    donor_email: raw.donor_email || null,
    campaign_title: raw.campaign_title || null,
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
    updated_at: raw.updated_at ? new Date(raw.updated_at).toISOString() : null,
  };
};

export const mapDonationList = (rawList: any[]) => {
  return {
    data: rawList.map(mapDonation),
    meta: {
      total: rawList.length,
    },
  };
};
