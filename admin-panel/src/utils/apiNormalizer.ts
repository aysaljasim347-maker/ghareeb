import type { Campaign } from '../types/campaign';
import type { User } from '../types/user';
import type { Donation } from '../types/donation';
import type { Withdrawal } from '../types/withdrawal';

/**
 * Safely converts any value to a number.
 */
export const toNumber = (value: any, defaultValue = 0): number => {
  if (value === null || value === undefined) return defaultValue;
  if (typeof value === 'number') return value;
  const parsed = parseFloat(value);
  return isNaN(parsed) ? defaultValue : parsed;
};

/**
 * Safely formats currency with PKR prefix.
 */
export const safeFormatCurrency = (value: unknown): string => {
  const num = toNumber(value);
  return `PKR ${num.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
};

/**
 * Unwraps API responses that might be { data: [...] } or just [...]
 */
export const unwrapResponse = <T>(response: any, key?: string): T[] => {
  if (!response) return [];
  
  // Handle new standardized { data: [...], meta: {} }
  if (response.data && Array.isArray(response.data)) {
    return response.data;
  }

  // Handle legacy { [key]: [...] }
  if (key && response[key] && Array.isArray(response[key])) {
    return response[key];
  }

  // Handle raw array
  if (Array.isArray(response)) {
    return response;
  }

  return [];
};

/**
 * Normalizes a Campaign object from the API.
 */
export const normalizeCampaign = (raw: any): Campaign => ({
  id: toNumber(raw.id),
  title: String(raw.title || 'Untitled'),
  ngo_id: toNumber(raw.ngo_id),
  ngo_name: raw.ngo_name || raw.org_name || null,
  goal_pkr: toNumber(raw.goal_pkr),
  raised_pkr: toNumber(raw.raised_pkr),
  status: raw.status || 'DRAFT',
  created_at: raw.created_at || new Date().toISOString(),
  created_by_name: raw.created_by_name || null,
});

/**
 * Normalizes a User object from the API.
 */
export const normalizeUser = (raw: any): User => ({
  id: toNumber(raw.id),
  name: String(raw.name || 'Unknown'),
  email: String(raw.email || ''),
  role: raw.role || 'DONOR',
  status: raw.status || 'ACTIVE',
  created_at: raw.created_at || new Date().toISOString(),
});

/**
 * Normalizes a Donation object from the API.
 */
export const normalizeDonation = (raw: any): Donation => ({
  id: toNumber(raw.id),
  user_id: toNumber(raw.user_id),
  donor_id: toNumber(raw.donor_id),
  campaign_id: toNumber(raw.campaign_id),
  amount_pkr: toNumber(raw.amount_pkr),
  status: raw.status || 'PENDING',
  reference_number: raw.reference_number || raw.gateway_ref || null,
  gateway_ref: raw.gateway_ref || null,
  receipt_url: raw.receipt_url || null,
  created_at: raw.created_at || new Date().toISOString(),
  donor_name: raw.donor_name || null,
  donor_email: raw.donor_email || null,
  campaign_title: raw.campaign_title || null,
});

/**
 * Normalizes a Withdrawal object from the API.
 */
export const normalizeWithdrawal = (raw: any): Withdrawal => ({
  id: toNumber(raw.id),
  ngo_user_id: toNumber(raw.ngo_user_id),
  amount: toNumber(raw.amount),
  status: raw.status || 'PENDING',
  bank_account: String(raw.bank_account || ''),
  created_at: raw.created_at || new Date().toISOString(),
  ngo_name: raw.ngo_name || null,
  ngo_email: raw.ngo_email || null,
});
