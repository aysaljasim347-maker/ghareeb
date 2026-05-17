import axiosClient from '../api/axiosClient';
import { API_ENDPOINTS } from '../api/endpoints';
import { normalizeUser } from '../utils/apiNormalizer';

export const authService = {
  login: async (email: string, password: string) => {
    const response = await axiosClient.post(API_ENDPOINTS.AUTH.LOGIN, { email, password });
    if (response.data.token && response.data.user) {
      const user = normalizeUser(response.data.user);
      localStorage.setItem('admin_token', response.data.token);
      localStorage.setItem('admin_user', JSON.stringify(user));
      return { token: response.data.token, user };
    }
    return response.data;
  },

  getMe: async () => {
    const response = await axiosClient.get(API_ENDPOINTS.AUTH.ME);
    return normalizeUser(response.data.user || response.data);
  },

  logout: () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
  },

  getCurrentUser: () => {
    const user = localStorage.getItem('admin_user');
    return user ? JSON.parse(user) : null;
  },

  getToken: () => {
    return localStorage.getItem('admin_token');
  }
};
