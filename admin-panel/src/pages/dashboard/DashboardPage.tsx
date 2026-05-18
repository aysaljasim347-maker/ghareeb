import React from 'react';
import { Row, Col, Card, Statistic, Typography, Alert, Divider } from 'antd';
import { 
  DollarOutlined, 
  SwapOutlined, 
  ProfileOutlined, 
  UserOutlined
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import { toNumber } from '../../utils/apiNormalizer';

const { Title, Text } = Typography;

const DashboardPage: React.FC = () => {
  // Fetch Operational Overview (Enhanced Snapshot)
  const { 
    data: operationalData, 
    isLoading: loadingOperational 
  } = useQuery({
    queryKey: ['admin', 'operational'],
    queryFn: async () => {
      const response = await axiosClient.get('/admin/operational');
      return response.data;
    }
  });

  // Fetch Donations Stats
  const { 
    data: donationStats, 
    isLoading: loadingDonations, 
    error: donationError 
  } = useQuery({
    queryKey: ['admin', 'donations', 'stats'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.DONATIONS_STATS);
      return response.data;
    }
  });

  // Fetch Withdrawals Stats
  const { 
    data: withdrawalStats, 
    isLoading: loadingWithdrawals, 
    error: withdrawalError 
  } = useQuery({
    queryKey: ['admin', 'withdrawals', 'stats'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.WITHDRAWALS_STATS);
      return response.data;
    }
  });

  // Fetch Campaign Stats
  const { 
    data: campaignStats, 
    isLoading: loadingCampaigns, 
    error: campaignError 
  } = useQuery({
    queryKey: ['admin', 'campaigns', 'stats'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.CAMPAIGNS_STATS);
      return response.data;
    }
  });

  // Fetch User Stats
  const { 
    data: userStats, 
    isLoading: loadingUsers, 
    error: userError 
  } = useQuery({
    queryKey: ['admin', 'users', 'stats'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.USERS_STATS);
      return response.data;
    }
  });

  const hasError = donationError || withdrawalError || campaignError || userError;

  if (hasError) {
    return (
      <div style={{ padding: '24px' }}>
        <Alert
          message="Error"
          description="Failed to load dashboard data. Please try again later."
          type="error"
          showIcon
        />
      </div>
    );
  }

  return (
    <div style={{ padding: '0 0 24px 0' }}>
      <Title level={2}>System Overview</Title>
      <Divider />

      <Row gutter={[16, 16]}>
        {/* Donations Column */}
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingDonations} title={<span><DollarOutlined /> Donations</span>}>
            <Statistic 
              title="Total Confirmed" 
              value={toNumber(donationStats?.total_amount)} 
              prefix="PKR" 
              precision={0}
            />
            <Row gutter={16} style={{ marginTop: 16 }}>
              <Col span={12}>
                <Statistic 
                  title="Pending" 
                  value={toNumber(donationStats?.pending_count)} 
                  valueStyle={{ color: '#faad14', fontSize: '14px' }}
                />
              </Col>
              <Col span={12}>
                <Statistic 
                  title="Confirmed" 
                  value={toNumber(donationStats?.confirmed_count)} 
                  valueStyle={{ color: '#52c41a', fontSize: '14px' }}
                />
              </Col>
            </Row>
          </Card>
        </Col>

        {/* Withdrawals Column */}
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingWithdrawals} title={<span><SwapOutlined /> Withdrawals</span>}>
            <Statistic 
              title="Total Approved" 
              value={toNumber(withdrawalStats?.total_amount)} 
              prefix="PKR" 
              precision={0}
            />
            <Row gutter={16} style={{ marginTop: 16 }}>
              <Col span={12}>
                <Statistic 
                  title="Pending" 
                  value={toNumber(withdrawalStats?.pending_count)} 
                  valueStyle={{ color: '#faad14', fontSize: '14px' }}
                />
              </Col>
              <Col span={12}>
                <Statistic 
                  title="Approved" 
                  value={toNumber(withdrawalStats?.approved_count)} 
                  valueStyle={{ color: '#1890ff', fontSize: '14px' }}
                />
              </Col>
            </Row>
          </Card>
        </Col>

        {/* Campaigns Column */}
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingCampaigns} title={<span><ProfileOutlined /> Campaigns</span>}>
            <Statistic 
              title="Total Raised" 
              value={toNumber(campaignStats?.total_raised)} 
              prefix="PKR" 
              precision={0}
            />
            <Row gutter={16} style={{ marginTop: 16 }}>
              <Col span={12}>
                <Statistic 
                  title="Total" 
                  value={toNumber(campaignStats?.total_count)} 
                  valueStyle={{ fontSize: '14px' }}
                />
              </Col>
              <Col span={12}>
                <Statistic 
                  title="Active" 
                  value={toNumber(campaignStats?.active_count)} 
                  valueStyle={{ color: '#52c41a', fontSize: '14px' }}
                />
              </Col>
            </Row>
          </Card>
        </Col>

        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingUsers} title={<span><UserOutlined /> Users</span>}>
            <Statistic 
              title="Total Platform Users" 
              value={toNumber(userStats?.total_count)} 
            />
            <Row gutter={8} style={{ marginTop: 16 }}>
              <Col span={6}>
                <Statistic title="NGOs" value={toNumber(userStats?.ngo_count)} valueStyle={{ fontSize: '11px' }} />
              </Col>
              <Col span={6}>
                <Statistic title="Vol" value={toNumber(userStats?.volunteer_count)} valueStyle={{ fontSize: '11px' }} />
              </Col>
              <Col span={6}>
                <Statistic title="Donors" value={toNumber(userStats?.donor_count)} valueStyle={{ fontSize: '11px' }} />
              </Col>
              <Col span={6}>
                <Statistic title="Pending" value={toNumber(userStats?.pending_ngo_count)} valueStyle={{ color: '#faad14', fontSize: '11px' }} />
              </Col>
            </Row>
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        <Col span={24}>
          <Card title="Operational Bottlenecks (Forensic View)" loading={loadingOperational}>
            <Row gutter={24}>
              <Col span={8}>
                <Statistic 
                  title="Oldest Pending Donation" 
                  value={operationalData?.oldest_pending_hours?.donation ?? 'None'} 
                  suffix={operationalData?.oldest_pending_hours?.donation !== null ? ' hours' : ''}
                  valueStyle={{ color: (operationalData?.oldest_pending_hours?.donation || 0) > 24 ? 'red' : 'inherit' }}
                />
                <Text type="secondary">{operationalData?.pending?.donations || 0} total pending</Text>
              </Col>
              <Col span={8}>
                <Statistic 
                  title="Oldest Pending Withdrawal" 
                  value={operationalData?.oldest_pending_hours?.withdrawal ?? 'None'} 
                  suffix={operationalData?.oldest_pending_hours?.withdrawal !== null ? ' hours' : ''}
                  valueStyle={{ color: (operationalData?.oldest_pending_hours?.withdrawal || 0) > 12 ? 'orange' : 'inherit' }}
                />
                <Text type="secondary">{operationalData?.pending?.withdrawals || 0} total pending</Text>
              </Col>
              <Col span={8}>
                <Statistic 
                  title="Oldest Unverified Delivery" 
                  value={operationalData?.oldest_pending_hours?.delivery ?? 'None'} 
                  suffix={operationalData?.oldest_pending_hours?.delivery !== null ? ' hours' : ''}
                />
                <Text type="secondary">{operationalData?.pending?.deliveries || 0} awaiting coordinator</Text>
              </Col>
            </Row>
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        <Col span={24}>
          <Card title="System Operational Status">
            <div style={{ display: 'flex', gap: '24px' }}>
              <Alert message="Backend API: Online" type="success" showIcon style={{ flex: 1 }} />
              <Alert message="Database: Connected" type="success" showIcon style={{ flex: 1 }} />
              <Alert message="Payment Gateway: Sandbox" type="info" showIcon style={{ flex: 1 }} />
            </div>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default DashboardPage;
