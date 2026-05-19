/**
 * User Mapper
 * Standardizes user responses for all frontends.
 */

interface UserRow {
  id: string | number;
  name?: string | null;
  email?: string | null;
  phone?: string | null;
  role?: string | null;
  status?: string | null;
  cnic?: string | null;
  locale?: string | null;
  created_at?: string | Date | null;
}

export const mapUser = (raw: UserRow) => {
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

export const mapUserList = (rawList: UserRow[]) => {
  return {
    data: rawList.map(mapUser),
    meta: {
      total: rawList.length,
    },
  };
};
