/**
 * Donation Mapper
 */

interface DonationRow {
  id: string | number;
  donor_id?: string | number | null;
  campaign_id?: string | number | null;
  amount_pkr?: string | number | null;
  status?: string | null;
  payment_method?: string | null;
  receipt_url?: string | null;
  gateway_ref?: string | null;
  donor_name?: string | null;
  donor_email?: string | null;
  campaign_title?: string | null;
  created_at?: string | Date | null;
  updated_at?: string | Date | null;
}

export const mapDonation = (raw: DonationRow) => {
  return {
    id: Number(raw.id),
    donor_id: raw.donor_id ? Number(raw.donor_id) : null,
    campaign_id: raw.campaign_id ? Number(raw.campaign_id) : null,
    amount_pkr: raw.amount_pkr ? parseFloat(raw.amount_pkr.toString()) : 0,
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

export const mapDonationList = (rawList: DonationRow[]) => {
  return {
    data: rawList.map(mapDonation),
    meta: {
      total: rawList.length,
    },
  };
};
