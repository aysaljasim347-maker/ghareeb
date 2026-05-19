import React from 'react';
import { Row, Col, Card, Statistic, Typography, Progress, Table, Tag, Space, Alert, Divider } from 'antd';
import { 
  ProjectOutlined, 
  RocketOutlined, 
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { safeFormatCurrency } from '../../utils/apiNormalizer';

import { API_ENDPOINTS } from '../../api/endpoints';

const { Title, Text } = Typography;

const NgoDashboardPage: React.FC = () => {
  const { data: stats, isLoading: loadingStats, error: statsError } = useQuery({
    queryKey: ['ngo', 'dashboard', 'stats'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.NGO.STATS);
      return response.data.data;
    }
  });

  const { data: campaigns, isLoading: loadingCampaigns } = useQuery({
    queryKey: ['ngo', 'campaigns'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.NGO.CAMPAIGNS);
      return response.data.data;
    }
  });

  if (statsError) {
    return <Alert message="Failed to load dashboard data" type="error" showIcon />;
  }

  const campaignStats = stats?.campaigns || { total: 0, active: 0, total_raised: 0, total_goal: 0 };
  const overallProgress = campaignStats.total_goal > 0 
    ? (campaignStats.total_raised / campaignStats.total_goal) * 100 
    : 0;

  const campaignColumns = [
    { title: 'Title', dataIndex: 'title', key: 'title', ellipsis: true },
    { 
      title: 'Status', 
      dataIndex: 'status', 
      key: 'status',
      render: (status: string) => {
        let color = 'default';
        if (status === 'ACTIVE') color = 'green';
        if (status === 'PAUSED') color = 'orange';
        return <Tag color={color}>{status}</Tag>;
      }
    },
    { 
      title: 'Progress', 
      key: 'progress',
      render: (_: unknown, record: { raised_pkr: number; goal_pkr: number }) => {
        const percent = (record.raised_pkr / record.goal_pkr) * 100;
        return <Progress percent={Math.min(100, Math.round(percent))} size="small" />;
      }
    },
    { 
      title: 'Raised', 
      dataIndex: 'raised_pkr', 
      key: 'raised_pkr',
      render: (val: number) => safeFormatCurrency(val) 
    },
  ];

  return (
    <div style={{ padding: '0 0 24px 0' }}>
      <Title level={2}>NGO Control Center</Title>
      <Text type="secondary">Overview of your humanitarian impact and active fundraising</Text>
      <Divider />

      <Row gutter={[16, 16]}>
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingStats}>
            <Statistic 
              title="Total Campaigns" 
              value={campaignStats.total} 
              prefix={<ProjectOutlined />} 
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingStats}>
            <Statistic 
              title="Active Now" 
              value={campaignStats.active} 
              valueStyle={{ color: '#52c41a' }}
              prefix={<RocketOutlined />} 
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingStats}>
            <Statistic 
              title="Total Raised" 
              value={campaignStats.total_raised} 
              precision={0}
              prefix="PKR "
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card loading={loadingStats}>
            <Statistic 
              title="Target Goal" 
              value={campaignStats.total_goal} 
              precision={0}
              prefix="PKR "
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        <Col span={16}>
          <Card title="Your Active Campaigns" extra={<Text style={{ color: '#1677ff', cursor: 'pointer' }}>View All</Text>}>
            <Table 
              columns={campaignColumns} 
              dataSource={campaigns?.slice(0, 5)} 
              rowKey="id" 
              loading={loadingCampaigns}
              pagination={false}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card title="Funding Health">
            <div style={{ textAlign: 'center', padding: '20px 0' }}>
              <Progress 
                type="dashboard" 
                percent={Math.round(overallProgress)} 
                strokeColor={{ '0%': '#108ee9', '100%': '#87d068' }}
              />
              <div style={{ marginTop: 16 }}>
                <Text strong>Overall Progress</Text><br/>
                <Text type="secondary">Calculated from confirmed donations vs goals</Text>
              </div>
            </div>
            <Divider />
            <Space direction="vertical" style={{ width: '100%' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <Text>Confirmed Donations</Text>
                <Text strong>{stats?.donations?.count || 0}</Text>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <Text>Trust Score (NGO)</Text>
                <Tag color="blue">BETA</Tag>
              </div>
            </Space>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default NgoDashboardPage;
