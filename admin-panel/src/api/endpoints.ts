export const API_ENDPOINTS = {
  AUTH: {
    LOGIN: '/auth/login',
    ME: '/auth/me',
  },
  DONATIONS: {
    LIST: '/donations',
    DETAILS: (id: number) => `/donations/${id}`,
    APPROVE: (id: number) => `/donations/${id}/approve`,
  },
  WITHDRAWALS: {
    LIST: '/withdrawals',
    APPROVE: (id: number) => `/withdrawals/${id}/approve`,
    REJECT: (id: number) => `/withdrawals/${id}/reject`,
  },
  CAMPAIGNS: {
    LIST: '/campaigns',
    CREATE: '/campaigns',
    UPDATE: (id: number) => `/campaigns/${id}`,
    UPDATE_STATUS: (id: number) => `/campaigns/${id}/status`,
  },
  USERS: {
    LIST: '/users',
    UPDATE: (id: number) => `/users/${id}`,
    SUSPEND: (id: number) => `/users/${id}/suspend`,
    REACTIVATE: (id: number) => `/users/${id}/reactivate`,
  },
  ADMIN: {
    DONATIONS: '/admin/donations',
    DONATIONS_STATS: '/admin/donations/stats',
    WITHDRAWALS: '/admin/withdrawals',
    WITHDRAWALS_STATS: '/admin/withdrawals/stats',
    CAMPAIGNS: '/admin/campaigns',
    CAMPAIGNS_STATS: '/admin/campaigns/stats',
    USERS: '/admin/users',
    USERS_STATS: '/admin/users/stats',
    LEDGER: '/admin/ledger',
    AUDIT_LOGS: '/admin/audit-logs',
  },
  NGO: {
    STATS: '/ngo/dashboard/stats',
    PROFILE: '/ngo/profile',
    CAMPAIGNS: '/ngo/campaigns',
    PUBLIC: (id: number) => `/ngo/public/${id}`,
  }
};
