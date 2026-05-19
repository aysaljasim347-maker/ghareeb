/**
 * Campaign Mapper
 * Standardizes campaign responses for all frontends.
 */

interface CampaignRow {
  id: string | number;
  ngo_id?: string | number | null;
  created_by?: string | number | null;
  title?: string | null;
  description?: string | null;
  goal_pkr?: string | number | null;
  raised_pkr?: string | number | null;
  spent_pkr?: string | number | null;
  status?: string | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
  ngo_name?: string | null;
  created_by_name?: string | null;
  created_at?: string | Date | null;
  updated_at?: string | Date | null;
}

export const mapCampaign = (raw: CampaignRow) => {
  return {
    id: Number(raw.id),
    ngo_id: raw.ngo_id ? Number(raw.ngo_id) : null,
    created_by: raw.created_by ? Number(raw.created_by) : null,
    title: raw.title || '',
    description: raw.description || '',
    goal_pkr: raw.goal_pkr ? parseFloat(raw.goal_pkr.toString()) : 0,
    raised_pkr: raw.raised_pkr ? parseFloat(raw.raised_pkr.toString()) : 0,
    spent_pkr: raw.spent_pkr ? parseFloat(raw.spent_pkr.toString()) : 0,
    status: raw.status || 'DRAFT',
    latitude: raw.latitude ? parseFloat(raw.latitude.toString()) : null,
    longitude: raw.longitude ? parseFloat(raw.longitude.toString()) : null,
    ngo_name: raw.ngo_name || null,
    created_by_name: raw.created_by_name || null,
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
    updated_at: raw.updated_at ? new Date(raw.updated_at).toISOString() : null,
  };
};

export const mapCampaignList = (rawList: CampaignRow[]) => {
  return {
    data: rawList.map(mapCampaign),
    meta: {
      total: rawList.length,
    },
  };
};
