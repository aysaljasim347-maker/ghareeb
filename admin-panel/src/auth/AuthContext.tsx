import React, { createContext, useState, useEffect, useCallback, useContext } from 'react';
import type { User } from '../types/user';
import { authService } from './authService';
import { message } from 'antd';

export interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
  isAuthenticated: boolean;
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuthContext = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuthContext must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem('admin_token'));
  const [isLoading, setIsLoading] = useState<boolean>(!!localStorage.getItem('admin_token'));

  const logout = useCallback(() => {
    authService.logout();
    setUser(null);
    setToken(null);
    setIsLoading(false);
  }, []);

  const verifySession = useCallback(async () => {
    const currentToken = localStorage.getItem('admin_token');
    if (!currentToken) {
      setIsLoading(false);
      return;
    }

    try {
      const userData = await authService.getMe();
      if (userData.role !== 'ADMIN' && userData.role !== 'NGO') {
        message.error('Access denied. Authorized personnel only.');
        logout();
      } else {
        setUser(userData);
        setToken(currentToken);
      }
    } catch (error) {
      console.error('Session verification failed', error);
      logout();
    } finally {
      setIsLoading(false);
    }
  }, [logout]);

  useEffect(() => {
    if (token) {
      verifySession();
    } else {
      setIsLoading(false);
    }
  }, [verifySession, token]);

  const login = async (email: string, password: string) => {
    try {
      const data = await authService.login(email, password);
      if (data.user.role !== 'ADMIN' && data.user.role !== 'NGO') {
        message.error('Access denied. Authorized personnel only.');
        authService.logout();
        throw new Error('Access denied. Authorized personnel only.');
      }
      setUser(data.user);
      setToken(data.token);
      message.success('Login successful');
    } catch (error: any) {
      const errorMsg = error.response?.data?.error || 'Login failed';
      message.error(errorMsg);
      throw error;
    }
  };

  const value = {
    user,
    token,
    login,
    logout,
    isLoading,
    isAuthenticated: !!user && !!token,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
