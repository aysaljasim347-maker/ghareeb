/**
 * Delivery Mapper
 */

export interface DeliveryRow {
  id: string | number;
  task_id: string | number;
  volunteer_id: string | number;
  storage_keys?: string[];
  notes?: string | null;
  verified_by?: string | number | null;
  verified_at?: string | Date | null;
  submitted_at?: string | Date | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
}

export const mapDelivery = (raw: DeliveryRow) => {
  return {
    id: Number(raw.id),
    task_id: Number(raw.task_id),
    volunteer_id: Number(raw.volunteer_id),
    storage_keys: raw.storage_keys || [],
    notes: raw.notes || '',
    verified_by: raw.verified_by ? Number(raw.verified_by) : null,
    verified_at: raw.verified_at ? new Date(raw.verified_at).toISOString() : null,
    submitted_at: raw.submitted_at ? new Date(raw.submitted_at).toISOString() : null,
    latitude: raw.latitude ? parseFloat(raw.latitude.toString()) : null,
    longitude: raw.longitude ? parseFloat(raw.longitude.toString()) : null,
  };
};

export const mapDeliveryList = (rawList: DeliveryRow[]) => {
  return {
    data: rawList.map(mapDelivery),
    meta: { total: rawList.length }
  };
};
