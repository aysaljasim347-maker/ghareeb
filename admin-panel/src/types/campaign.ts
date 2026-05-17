export type CampaignStatus = 'DRAFT' | 'ACTIVE' | 'PAUSED' | 'CLOSED';

export interface Campaign {
  id: number;
  title: string;
  ngo_id: number;
  ngo_name?: string;
  goal_pkr: number;
  raised_pkr: number;
  status: CampaignStatus;
  created_at: string;
  created_by_name?: string;
}
