/**
 * Task Mapper
 */
export const mapTask = (raw: any) => {
  return {
    id: Number(raw.id),
    campaign_id: raw.campaign_id ? Number(raw.campaign_id) : null,
    beneficiary_id: raw.beneficiary_id ? Number(raw.beneficiary_id) : null,
    created_by: raw.created_by ? Number(raw.created_by) : null,
    claimed_by: raw.claimed_by ? Number(raw.claimed_by) : null,
    coordinator_id: raw.coordinator_id ? Number(raw.coordinator_id) : null,
    source_type: raw.source_type || 'BENEFICIARY_REQUEST',
    title: raw.title || '',
    description: raw.description || '',
    category: raw.category || '',
    family_size: Number(raw.family_size || 1),
    items_needed: raw.items_needed || [],
    latitude: raw.latitude ? parseFloat(raw.latitude) : null,
    longitude: raw.longitude ? parseFloat(raw.longitude) : null,
    location_text: raw.location_text || '',
    budget_pkr: raw.budget_pkr ? parseFloat(raw.budget_pkr) : 0,
    urgency: raw.urgency || 'MEDIUM',
    status: raw.status || 'OPEN',
    upvotes: Number(raw.upvotes || 0),
    downvotes: Number(raw.downvotes || 0),
    view_count: Number(raw.view_count || 0),
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
    updated_at: raw.updated_at ? new Date(raw.updated_at).toISOString() : null,
    claimed_at: raw.claimed_at ? new Date(raw.claimed_at).toISOString() : null,
  };
};

export const mapTaskList = (rawList: any[]) => {
  return {
    data: rawList.map(mapTask),
    meta: {
      total: rawList.length,
    },
  };
};
