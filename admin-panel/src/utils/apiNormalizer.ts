import type { Campaign, CampaignStatus } from '../types/campaign';
import type { User, UserRole, UserStatus } from '../types/user';
import type { Donation, DonationStatus } from '../types/donation';
import type { Withdrawal, WithdrawalStatus } from '../types/withdrawal';

/**
 * Safely converts any value to a number.
 */
export const toNumber = (value: unknown, defaultValue = 0): number => {
  if (value === null || value === undefined) return defaultValue;
  if (typeof value === 'number') return value;
  const parsed = parseFloat(String(value));
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
export const unwrapResponse = <T>(response: unknown, key?: string): T[] => {
  if (!response || typeof response !== 'object') return [];
  
  const res = response as Record<string, unknown>;

  // Handle new standardized { data: [...], meta: {} }
  if (res.data && Array.isArray(res.data)) {
    return res.data;
  }

  // Handle legacy { [key]: [...] }
  if (key && res[key] && Array.isArray(res[key])) {
    return res[key] as T[];
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
export const normalizeCampaign = (raw: Record<string, unknown>): Campaign => ({
  id: toNumber(raw.id),
  title: String(raw.title || 'Untitled'),
  ngo_id: toNumber(raw.ngo_id),
  ngo_name: (raw.ngo_name as string) || (raw.org_name as string) || undefined,
  goal_pkr: toNumber(raw.goal_pkr),
  raised_pkr: toNumber(raw.raised_pkr),
  status: (raw.status as CampaignStatus) || 'DRAFT',
  created_at: (raw.created_at as string) || new Date().toISOString(),
  created_by_name: (raw.created_by_name as string) || undefined,
});

/**
 * Normalizes a User object from the API.
 */
export const normalizeUser = (raw: Record<string, unknown>): User => ({
  id: toNumber(raw.id),
  name: String(raw.name || 'Unknown'),
  email: String(raw.email || ''),
  role: (raw.role as UserRole) || 'DONOR',
  status: (raw.status as UserStatus) || 'ACTIVE',
  created_at: (raw.created_at as string) || new Date().toISOString(),
});

/**
 * Normalizes a Donation object from the API.
 */
export const normalizeDonation = (raw: Record<string, unknown>): Donation => ({
  id: toNumber(raw.id),
  user_id: toNumber(raw.user_id),
  donor_id: toNumber(raw.donor_id),
  campaign_id: toNumber(raw.campaign_id),
  amount_pkr: toNumber(raw.amount_pkr),
  status: (raw.status as DonationStatus) || 'PENDING',
  reference_number: (raw.reference_number as string) || (raw.gateway_ref as string) || undefined,
  gateway_ref: (raw.gateway_ref as string) || undefined,
  receipt_url: (raw.receipt_url as string) || undefined,
  created_at: (raw.created_at as string) || new Date().toISOString(),
  donor_name: (raw.donor_name as string) || undefined,
  donor_email: (raw.donor_email as string) || undefined,
  campaign_title: (raw.campaign_title as string) || undefined,
});

/**
 * Normalizes a Withdrawal object from the API.
 */
export const normalizeWithdrawal = (raw: Record<string, unknown>): Withdrawal => ({
  id: toNumber(raw.id),
  ngo_user_id: toNumber(raw.ngo_user_id),
  amount: toNumber(raw.amount),
  status: (raw.status as WithdrawalStatus) || 'PENDING',
  bank_account: String(raw.bank_account || ''),
  created_at: (raw.created_at as string) || new Date().toISOString(),
  ngo_name: (raw.ngo_name as string) || undefined,
  ngo_email: (raw.ngo_email as string) || undefined,
});
