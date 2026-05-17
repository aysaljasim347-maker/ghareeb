/**
 * User Mapper
 * Standardizes user responses for all frontends.
 */
export const mapUser = (raw: any) => {
  return {
    id: Number(raw.id),
    name: raw.name || '',
    email: raw.email || null,
    phone: raw.phone || null,
    role: raw.role || null,
    status: raw.status || 'ACTIVE',
    cnic: raw.cnic || null,
    locale: raw.locale || 'en',
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
  };
};

export const mapUserList = (rawList: any[]) => {
  return {
    data: rawList.map(mapUser),
    meta: {
      total: rawList.length,
    },
  };
};
