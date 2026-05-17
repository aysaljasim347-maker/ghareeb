import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useAuthContext } from '../auth/AuthContext';
import { Spin } from 'antd';

const ProtectedRoute: React.FC = () => {
  const { isAuthenticated, user, isLoading } = useAuthContext();

  if (isLoading) {
    return (
      <div style={{ height: '100vh', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
        <Spin size="large" tip="Verifying session..." />
      </div>
    );
  }

  if (!isAuthenticated || (user?.role !== 'ADMIN' && user?.role !== 'NGO')) {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
};

export default ProtectedRoute;
