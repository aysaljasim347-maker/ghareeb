export type UserRole = 'ADMIN' | 'NGO' | 'VOLUNTEER' | 'COORDINATOR' | 'DONOR';

export type UserStatus = 'ACTIVE' | 'SUSPENDED';

export interface User {
  id: number;
  name: string;
  email: string;
  role: UserRole;
  status: UserStatus;
  created_at: string;
}
