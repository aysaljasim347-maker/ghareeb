import axios from 'axios';

const axiosClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://127.0.0.1:3000/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

axiosClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('admin_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

axiosClient.interceptors.response.use(
  (response) => {
    // Inject Request ID from header into the response object for tracing if needed
    const requestId = response.headers['x-request-id'];
    if (requestId) {
      (response as any).requestId = requestId;
    }
    return response;
  },
  (error) => {
    const requestId = error.response?.headers['x-request-id'];
    const { method, url } = error.config || {};
    const status = error.response?.status;

    console.error(`[API FAILURE] ${method?.toUpperCase()} ${url}`, {
      status,
      requestId,
      message: error.message,
      data: error.response?.data,
    });

    if (error.response?.status === 401) {
      localStorage.removeItem('admin_token');
      localStorage.removeItem('admin_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default axiosClient;
