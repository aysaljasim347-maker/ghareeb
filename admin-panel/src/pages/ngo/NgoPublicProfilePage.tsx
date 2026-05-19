import React from 'react';
import { useParams } from 'react-router-dom';
import { Card, Row, Col, Statistic, Table, Tag, Typography, Progress, Space, Divider, Spin, Alert } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { safeFormatCurrency } from '../../utils/apiNormalizer';
import dayjs from 'dayjs';

const { Title, Text, Paragraph } = Typography;

const NgoPublicProfilePage: React.FC = () => {
  const { id } = useParams<{ id: string }>();

  const { data, isLoading, error } = useQuery({
    queryKey: ['ngo', 'public', id],
    queryFn: async () => {
      const response = await axiosClient.get(`/ngo/public/${id}`);
      return response.data.data;
    }
  });

  if (isLoading) return <div style={{ textAlign: 'center', padding: '50px' }}><Spin size="large" /></div>;
  if (error) return <Alert message="NGO not found or profile is private" type="error" showIcon />;

  const { profile, campaigns } = data;
  const totalRaised = campaigns.reduce((acc: number, c: unknown) => acc + parseFloat((c as { raised_pkr: string }).raised_pkr), 0);

  const columns = [
    { title: 'Campaign', dataIndex: 'title', key: 'title', ellipsis: true },
    { 
      title: 'Status', 
      dataIndex: 'status', 
      key: 'status',
      render: (s: string) => <Tag color={s === 'ACTIVE' ? 'green' : 'blue'}>{s}</Tag>
    },
    { 
      title: 'Funding', 
      key: 'funding',
      render: (_: unknown, record: { raised_pkr: number; goal_pkr: number }) => {
        const percent = Math.round((record.raised_pkr / record.goal_pkr) * 100);
        return <Progress percent={Math.min(100, percent)} size="small" />;
      }
    },
    { 
      title: 'Raised', 
      dataIndex: 'raised_pkr', 
      key: 'raised_pkr',
      render: (v: number) => safeFormatCurrency(v)
    },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1200, margin: '0 auto', background: '#fff', minHeight: '100vh' }}>
      <Row gutter={24}>
        <Col span={18}>
          <Title level={2}>{profile.org_name}</Title>
          <Space>
            <Tag color="blue">NGO</Tag>
            {profile.status === 'VERIFIED' && <Tag color="green">VERIFIED ORGANIZATION</Tag>}
          </Space>
          <Paragraph style={{ marginTop: 24, fontSize: '16px' }}>
            {profile.description || "This organization is dedicated to providing humanitarian aid and disaster relief."}
          </Paragraph>
        </Col>
        <Col span={6} style={{ textAlign: 'right' }}>
          <Card>
            <Statistic title="Total Impact (Raised)" value={totalRaised} prefix="PKR " />
            <Divider />
            <Statistic title="Total Campaigns" value={campaigns.length} />
          </Card>
        </Col>
      </Row>

      <Divider />
      
      <Title level={4}>Current & Past Campaigns</Title>
      <Table 
        columns={columns} 
        dataSource={campaigns} 
        rowKey="id" 
        pagination={false}
      />
      
      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Text type="secondary">Member since {dayjs(profile.created_at).format('MMMM YYYY')}</Text>
      </div>
    </div>
  );
};

export default NgoPublicProfilePage;
