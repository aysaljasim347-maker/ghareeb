import React, { useState } from 'react';
import { Layout, Menu, Button, theme, Avatar, Dropdown } from 'antd';
import {
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  DashboardOutlined,
  DollarOutlined,
  SwapOutlined,
  ProfileOutlined,
  ProjectOutlined,
  UserOutlined,
  SafetyCertificateOutlined,
  BookOutlined,
  LogoutOutlined,
  GiftOutlined,
} from '@ant-design/icons';
import { useNavigate, useLocation, Outlet } from 'react-router-dom';
import { useAuthContext } from '../auth/useAuthContext';
import Logo from '../components/Logo';

const { Header, Sider, Content } = Layout;

const AdminLayout: React.FC = () => {
  const [collapsed, setCollapsed] = useState(false);
  const { user, logout } = useAuthContext();
  const navigate = useNavigate();
  const location = useLocation();
  const {
    token: { colorBgContainer, borderRadiusLG },
  } = theme.useToken();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const userMenuItems = [
    {
      key: 'logout',
      label: 'Logout',
      icon: <LogoutOutlined />,
      onClick: handleLogout,
    },
  ];

  const isAdmin = user?.role === 'ADMIN';
  const isNgo = user?.role === 'NGO';

  const menuItems = [
    // Shared or conditional items
    ...(isAdmin ? [
      {
        key: '/dashboard',
        icon: <DashboardOutlined />,
        label: 'Dashboard',
      },
      {
        key: '/donations',
        icon: <DollarOutlined />,
        label: 'Donations',
      },
      {
        key: '/withdrawals',
        icon: <SwapOutlined />,
        label: 'Withdrawals',
      },
      {
        key: '/campaigns',
        icon: <ProfileOutlined />,
        label: 'Campaigns',
      },
      {
        key: '/users',
        icon: <UserOutlined />,
        label: 'Users',
      },
      {
        key: '/ngos/verification',
        icon: <SafetyCertificateOutlined />,
        label: 'NGO Verification',
      },
      {
        key: '/ledger',
        icon: <BookOutlined />,
        label: 'Ledger',
      },
      {
        key: '/inkind',
        icon: <GiftOutlined />,
        label: 'InKind Records',
      },
    ] : []),
    ...(isNgo ? [
      {
        key: '/ngo/dashboard',
        icon: <DashboardOutlined />,
        label: 'NGO Dashboard',
      },
      {
        key: '/ngo/campaigns',
        icon: <ProfileOutlined />,
        label: 'My Campaigns',
      },
      {
        key: 'tasks-group',
        icon: <ProjectOutlined />,
        label: 'Tasks & Relief',
        children: [
          { key: '/ngo/tasks', label: 'All Tasks' },
          { key: '/ngo/tasks/new', label: 'Create Task' },
          { key: '/ngo/beneficiaries/requests', label: 'Beneficiary Requests' },
        ]
      },
      {
        key: '/ngo/goods-donations',
        icon: <GiftOutlined />,
        label: 'Goods Donations',
      },
      {
        key: '/ngo/profile',
        icon: <UserOutlined />,
        label: 'Organization Profile',
      },
    ] : []),
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider trigger={null} collapsible collapsed={collapsed}>
        <div style={{ height: 64, margin: '16px 0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Logo size={collapsed ? 32 : 40} color="white" showText={!collapsed} />
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          onClick={({ key }) => navigate(key)}
          items={menuItems}
        />
      </Sider>
      <Layout>
        <Header style={{ padding: '0 24px', background: colorBgContainer, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
            style={{
              fontSize: '16px',
              width: 64,
              height: 64,
            }}
          />
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
              <div style={{ cursor: 'pointer', display: 'flex', alignItems: 'center' }}>
                <span style={{ marginRight: 12, fontWeight: 500 }}>{user?.name || 'Admin'}</span>
                <Avatar icon={<UserOutlined />} />
              </div>
            </Dropdown>
          </div>
        </Header>
        <Content
          style={{
            margin: '24px 16px',
            padding: 24,
            minHeight: 280,
            background: colorBgContainer,
            borderRadius: borderRadiusLG,
            overflow: 'initial'
          }}
        >
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
};

export default AdminLayout;
