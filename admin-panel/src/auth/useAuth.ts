import { useState, useEffect } from 'react';
import type { User } from '../types/user';
import { authService } from './authService';

export const useAuth = () => {
  const [user, setUser] = useState<User | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);

  useEffect(() => {
    const currentUser = authService.getCurrentUser();
    const token = authService.getToken();
    
    if (currentUser && token && currentUser.role === 'ADMIN') {
      setUser(currentUser);
      setIsAuthenticated(true);
    } else {
      setUser(null);
      setIsAuthenticated(false);
    }
  }, []);

  return { user, isAuthenticated };
};
