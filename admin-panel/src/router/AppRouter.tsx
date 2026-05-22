import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import AdminLayout from '../layout/AdminLayout';
import ProtectedRoute from './ProtectedRoute';
import LoginPage from '../pages/login/LoginPage';
import DashboardPage from '../pages/dashboard/DashboardPage';
import DonationsPage from '../pages/donations/DonationsPage';
import WithdrawalsPage from '../pages/withdrawals/WithdrawalsPage';
import CampaignsPage from '../pages/campaigns/CampaignsPage';
import UsersPage from '../pages/users/UsersPage';
import NgoVerificationPage from '../pages/users/NgoVerificationPage';
import NgoDetailPage from '../pages/users/NgoDetailPage';
import LedgerPage from '../pages/ledger/LedgerPage';

// NGO Pages
import NgoDashboardPage from '../pages/ngo/NgoDashboardPage';
import NgoCampaignsPage from '../pages/ngo/NgoCampaignsPage';
import NgoCampaignCreatePage from '../pages/ngo/NgoCampaignCreatePage';
import NgoCampaignEditPage from '../pages/ngo/NgoCampaignEditPage';
import NgoProfilePage from '../pages/ngo/NgoProfilePage';
import NgoPublicProfilePage from '../pages/ngo/NgoPublicProfilePage';

// NGO Task Pages
import NgoTasksPage from '../pages/ngo/NgoTasksPage';
import NgoTaskDetailPage from '../pages/ngo/NgoTaskDetailPage';
import NgoTaskCreatePage from '../pages/ngo/NgoTaskCreatePage';
import NgoBeneficiaryRequestsPage from '../pages/ngo/NgoBeneficiaryRequestsPage';

import InKindRecordsPage from '../pages/inkind/InKindRecordsPage';
import NgoGoodsDonationsPage from '../pages/ngo/NgoGoodsDonationsPage';
import { AuthProvider, useAuthContext } from '../auth/AuthContext.tsx';

const DashboardRedirect: React.FC = () => {
  const { user } = useAuthContext();
  if (user?.role === 'NGO') return <Navigate to="/ngo/dashboard" replace />;
  return <Navigate to="/dashboard" replace />;
};

const AppRouter: React.FC = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          
          <Route element={<ProtectedRoute />}>
            <Route element={<AdminLayout />}>
              {/* Admin Routes */}
              <Route path="/dashboard" element={<DashboardPage />} />
              <Route path="/donations" element={<DonationsPage />} />
              <Route path="/withdrawals" element={<WithdrawalsPage />} />
              <Route path="/campaigns" element={<CampaignsPage />} />
              <Route path="/users" element={<UsersPage />} />
              <Route path="/ngos/verification" element={<NgoVerificationPage />} />
              <Route path="/ngos/:id" element={<NgoDetailPage />} />
              <Route path="/ledger" element={<LedgerPage />} />
              <Route path="/inkind" element={<InKindRecordsPage />} />

              {/* NGO Specific Routes */}
              <Route path="/ngo/dashboard" element={<NgoDashboardPage />} />
              <Route path="/ngo/campaigns" element={<NgoCampaignsPage />} />
              <Route path="/ngo/campaigns/new" element={<NgoCampaignCreatePage />} />
              <Route path="/ngo/campaigns/:id/edit" element={<NgoCampaignEditPage />} />
              <Route path="/ngo/profile" element={<NgoProfilePage />} />

              <Route path="/ngo/tasks" element={<NgoTasksPage />} />
              <Route path="/ngo/tasks/new" element={<NgoTaskCreatePage />} />
              <Route path="/ngo/tasks/:id" element={<NgoTaskDetailPage />} />
              <Route path="/ngo/beneficiaries/requests" element={<NgoBeneficiaryRequestsPage />} />
              <Route path="/ngo/goods-donations" element={<NgoGoodsDonationsPage />} />
              
              <Route path="/" element={<DashboardRedirect />} />
            </Route>
          </Route>

          {/* Public NGO Profile */}
          <Route path="/ngo/public/:id" element={<NgoPublicProfilePage />} />

          <Route path="*" element={<DashboardRedirect />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default AppRouter;
