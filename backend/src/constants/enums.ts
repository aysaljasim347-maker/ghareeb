export const TaskStatus = {
  OPEN: 'OPEN',
  ASSIGNED: 'ASSIGNED',
  CLAIMED: 'CLAIMED',
  IN_PROGRESS: 'IN_PROGRESS',
  SUBMITTED: 'SUBMITTED',
  COORDINATOR_VERIFIED: 'COORDINATOR_VERIFIED',
  PAID: 'PAID',
  FLAGGED: 'FLAGGED',
  CANCELLED: 'CANCELLED',
} as const;

export const DonationStatus = {
  PENDING: 'PENDING',
  CONFIRMED: 'CONFIRMED',
  REJECTED: 'REJECTED',
  REFUNDED: 'REFUNDED',
} as const;

export const VolunteerType = {
  INDEPENDENT: 'INDEPENDENT',
  NGO: 'NGO',
} as const;

export const WithdrawalStatus = {
  PENDING: 'PENDING',
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
} as const;

export const CampaignStatus = {
  DRAFT: 'DRAFT',
  PENDING_APPROVAL: 'PENDING_APPROVAL',
  ACTIVE: 'ACTIVE',
  PAUSED: 'PAUSED',
  CLOSED: 'CLOSED',
  REJECTED: 'REJECTED',
  COMPLETED: 'COMPLETED',
} as const;

// PostgreSQL error codes
export const PgErrorCode = {
  TRIGGER_EXCEPTION: 'P0001',
  UNIQUE_VIOLATION: '23505',
  CHECK_VIOLATION: '23514',
  FOREIGN_KEY_VIOLATION: '23503',
  NOT_NULL_VIOLATION: '23502',
} as const;

// Substrings to match against trigger exception messages
export const TriggerMessage = {
  TASK_STATUS_TRANSITION: 'Invalid task status transition',
  CANNOT_CLAIM: 'cannot claim a task',
  NOT_BENEFICIARY: 'is not the beneficiary',
  FEEDBACK_NO_BENEFICIARY: 'has no associated task beneficiary',
} as const;

// CHECK constraint names that map to specific HTTP errors
export const CheckConstraint = {
  WALLET_BALANCE: 'ngo_profiles_wallet_balance_check',
  TOTAL_EARNED: 'volunteer_profiles_total_earned_check',
  AMOUNT_POSITIVE: 'donations_amount_positive',
  BUDGET_NON_NEGATIVE: 'tasks_budget_non_negative',
} as const;

// UNIQUE constraint names
export const UniqueConstraint = {
  LEDGER_EVENT: 'ledger_entries_unique_event',
} as const;
