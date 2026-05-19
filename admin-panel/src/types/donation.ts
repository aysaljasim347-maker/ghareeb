export type DonationStatus = 'PENDING' | 'CONFIRMED' | 'REJECTED';

export interface Donation {
  id: number;
  user_id: number;
  donor_id: number;
  campaign_id: number;
  amount_pkr: number;
  status: DonationStatus;
  reference_number?: string;
  gateway_ref?: string;
  receipt_url?: string;
  created_at: string;
  donor_name?: string;
  donor_email?: string;
  campaign_title?: string;
  metadata?: {
    disputed?: boolean;
    [key: string]: unknown;
  };
}
