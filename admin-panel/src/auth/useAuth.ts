import { useState } from 'react';
import type { User } from '../types/user';
import { authService } from './authService';

export const useAuth = () => {
  const [user] = useState<User | null>(() => authService.getCurrentUser());
  const [isAuthenticated] = useState<boolean>(() => {
    const currentUser = authService.getCurrentUser();
    const token = authService.getToken();
    return !!(currentUser && token && currentUser.role === 'ADMIN');
  });

  return { user, isAuthenticated };
};
