/**
 * Delivery Mapper
 */
export const mapDelivery = (raw: any) => {
  return {
    id: Number(raw.id),
    task_id: Number(raw.task_id),
    volunteer_id: Number(raw.volunteer_id),
    photo_urls: raw.photo_urls || [],
    notes: raw.notes || '',
    verified_by: raw.verified_by ? Number(raw.verified_by) : null,
    verified_at: raw.verified_at ? new Date(raw.verified_at).toISOString() : null,
    submitted_at: raw.submitted_at ? new Date(raw.submitted_at).toISOString() : null,
    latitude: raw.latitude ? parseFloat(raw.latitude) : null,
    longitude: raw.longitude ? parseFloat(raw.longitude) : null,
  };
};

export const mapDeliveryList = (rawList: any[]) => {
  return {
    data: rawList.map(mapDelivery),
    meta: { total: rawList.length }
  };
};
