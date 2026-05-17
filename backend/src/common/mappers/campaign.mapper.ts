/**
 * Campaign Mapper
 * Standardizes campaign responses for all frontends.
 */
export const mapCampaign = (raw: any) => {
  return {
    id: Number(raw.id),
    ngo_id: raw.ngo_id ? Number(raw.ngo_id) : null,
    created_by: raw.created_by ? Number(raw.created_by) : null,
    title: raw.title || '',
    description: raw.description || '',
    goal_pkr: raw.goal_pkr ? parseFloat(raw.goal_pkr) : 0,
    raised_pkr: raw.raised_pkr ? parseFloat(raw.raised_pkr) : 0,
    spent_pkr: raw.spent_pkr ? parseFloat(raw.spent_pkr) : 0,
    status: raw.status || 'DRAFT',
    latitude: raw.latitude ? parseFloat(raw.latitude) : null,
    longitude: raw.longitude ? parseFloat(raw.longitude) : null,
    ngo_name: raw.ngo_name || null,
    created_by_name: raw.created_by_name || null,
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
    updated_at: raw.updated_at ? new Date(raw.updated_at).toISOString() : null,
  };
};

export const mapCampaignList = (rawList: any[]) => {
  return {
    data: rawList.map(mapCampaign),
    meta: {
      total: rawList.length,
    },
  };
};
