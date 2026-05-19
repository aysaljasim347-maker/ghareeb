/**
 * Task Mapper
 */

interface TaskRow {
  id: string | number;
  campaign_id?: string | number | null;
  beneficiary_id?: string | number | null;
  created_by?: string | number | null;
  claimed_by?: string | number | null;
  coordinator_id?: string | number | null;
  source_type?: string | null;
  title?: string | null;
  description?: string | null;
  category?: string | null;
  family_size?: string | number | null;
  items_needed?: unknown; // Could be more specific if we knew the structure
  latitude?: string | number | null;
  longitude?: string | number | null;
  location_text?: string | null;
  radius_km?: string | number | null;
  budget_pkr?: string | number | null;
  urgency?: string | null;
  status?: string | null;
  upvotes?: string | number | null;
  downvotes?: string | number | null;
  view_count?: string | number | null;
  created_at?: string | Date | null;
  updated_at?: string | Date | null;
  claimed_at?: string | Date | null;
  created_by_name?: string | null;
  claimed_by_name?: string | null;
  coordinator_name?: string | null;
  beneficiary_name?: string | null;
  campaign_title?: string | null;
  ngo_name?: string | null;
}

export const mapTask = (raw: TaskRow) => {
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
    latitude: raw.latitude ? parseFloat(raw.latitude.toString()) : null,
    longitude: raw.longitude ? parseFloat(raw.longitude.toString()) : null,
    location_text: raw.location_text || '',
    radius_km: Number(raw.radius_km || 5),
    budget_pkr: raw.budget_pkr ? parseFloat(raw.budget_pkr.toString()) : 0,
    urgency: raw.urgency || 'MEDIUM',
    status: raw.status || 'OPEN',
    upvotes: Number(raw.upvotes || 0),
    downvotes: Number(raw.downvotes || 0),
    view_count: Number(raw.view_count || 0),
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
    updated_at: raw.updated_at ? new Date(raw.updated_at).toISOString() : null,
    claimed_at: raw.claimed_at ? new Date(raw.claimed_at).toISOString() : null,
    created_by_name: raw.created_by_name || null,
    claimed_by_name: raw.claimed_by_name || null,
    coordinator_name: raw.coordinator_name || null,
    beneficiary_name: raw.beneficiary_name || null,
    campaign_title: raw.campaign_title || null,
    ngo_name: raw.ngo_name || null,
  };
};

export const mapTaskList = (rawList: TaskRow[]) => {
  return {
    data: rawList.map(mapTask),
    meta: {
      total: rawList.length,
    },
  };
};
