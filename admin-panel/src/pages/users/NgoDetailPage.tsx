import React from 'react';
import { useParams } from 'react-router-dom';
import { Card, Row, Col, Statistic, Table, Tag, Typography, Button, Space, Divider, Spin, Alert } from 'antd';
import { ArrowLeftOutlined, GlobalOutlined, MailOutlined, ProfileOutlined } from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';
import { safeFormatCurrency } from '../../utils/apiNormalizer';

const { Title, Text } = Typography;

const NgoDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'ngo', id],
    queryFn: async () => {
      const response = await axiosClient.get(`/admin/ngos/${id}`);
      return response.data.data;
    }
  });

  if (isLoading) return <div style={{ textAlign: 'center', padding: '50px' }}><Spin size="large" /></div>;
  if (error) return <Alert message="Error loading NGO details" type="error" showIcon />;

  const { ngo, stats, recent_campaigns } = data;

  const campaignColumns = [
    { title: 'Title', dataIndex: 'title', key: 'title', ellipsis: true },
    { 
      title: 'Status', 
      dataIndex: 'status', 
      key: 'status',
      render: (status: string) => (
        <Tag color={status === 'ACTIVE' ? 'green' : 'blue'}>{status}</Tag>
      )
    },
    { 
      title: 'Raised / Goal', 
      key: 'progress',
      render: (_: unknown, record: { raised_pkr: number, goal_pkr: number }) => (
        <span>{safeFormatCurrency(record.raised_pkr)} / {safeFormatCurrency(record.goal_pkr)}</span>
      )
    },
    { 
      title: 'Created', 
      dataIndex: 'created_at', 
      key: 'created_at',
      render: (d: string) => dayjs(d).format('MMM D, YYYY')
    },
  ];

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }}>
      <Button icon={<ArrowLeftOutlined />} onClick={() => window.history.back()}>
        Back to Users
      </Button>

      <Card>
        <Row gutter={24}>
          <Col span={16}>
            <Title level={2}>{ngo.org_name}</Title>
            <Space direction="vertical">
              <Text><MailOutlined /> {ngo.email}</Text>
              <Text><ProfileOutlined /> Registration: {ngo.registration_number}</Text>
              <Text><GlobalOutlined /> Website: {ngo.website_url || 'N/A'}</Text>
              <Text type="secondary">{ngo.description}</Text>
            </Space>
          </Col>
          <Col span={8} style={{ textAlign: 'right' }}>
            <Tag color={ngo.status === 'VERIFIED' ? 'success' : 'warning'} style={{ fontSize: '14px', padding: '4px 12px' }}>
              {ngo.status}
            </Tag>
            <Divider />
            <Statistic title="Wallet Balance" value={ngo.wallet_balance} prefix="PKR " precision={2} />
          </Col>
        </Row>
      </Card>

      <Row gutter={16}>
        <Col span={6}>
          <Card size="small"><Statistic title="Total Campaigns" value={stats.total_campaigns} /></Card>
        </Col>
        <Col span={6}>
          <Card size="small"><Statistic title="Active Campaigns" value={stats.active_campaigns} valueStyle={{ color: '#3f8600' }} /></Card>
        </Col>
        <Col span={6}>
          <Card size="small"><Statistic title="Total Raised" value={stats.total_raised} prefix="PKR " /></Card>
        </Col>
        <Col span={6}>
          <Card size="small"><Statistic title="Total Spent" value={stats.total_spent} prefix="PKR " /></Card>
        </Col>
      </Row>

      <Card title="Recent Campaigns">
        <Table 
          columns={campaignColumns} 
          dataSource={recent_campaigns} 
          rowKey="id" 
          pagination={false} 
        />
      </Card>
    </Space>
  );
};

export default NgoDetailPage;
