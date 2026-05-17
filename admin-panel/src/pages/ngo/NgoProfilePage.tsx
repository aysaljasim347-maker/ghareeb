import React from 'react';
import { Card, Descriptions, Typography, Tag, Divider, Spin, Alert, Row, Col, Statistic } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';

import { API_ENDPOINTS } from '../../api/endpoints';

const { Title, Paragraph } = Typography;

const NgoProfilePage: React.FC = () => {
  const { data, isLoading, error } = useQuery({
    queryKey: ['ngo', 'profile'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.NGO.PROFILE);
      return response.data.data;
    }
  });

  if (isLoading) return <div style={{ textAlign: 'center', padding: '50px' }}><Spin size="large" /></div>;
  if (error) return <Alert message="Error loading profile" type="error" showIcon />;

  const profile = data;

  return (
    <div style={{ maxWidth: 1000, margin: '0 auto' }}>
      <Title level={2}>Organization Profile</Title>
      <Paragraph type="secondary">Verification and registration details for your NGO</Paragraph>
      <Divider />

      <Row gutter={16}>
        <Col span={16}>
          <Card title="Business Identity" bordered={false}>
            <Descriptions column={1} bordered size="small">
              <Descriptions.Item label="Organization Name">
                <Typography.Text strong>{profile.org_name}</Typography.Text>
              </Descriptions.Item>
              <Descriptions.Item label="Registration #">
                <Typography.Text code>{profile.registration_number || 'N/A'}</Typography.Text>
              </Descriptions.Item>
              <Descriptions.Item label="Official Email">{profile.email}</Descriptions.Item>
              <Descriptions.Item label="Primary Contact">{profile.name}</Descriptions.Item>
              <Descriptions.Item label="Joined Platform">
                {dayjs(profile.created_at).format('MMMM D, YYYY')}
              </Descriptions.Item>
            </Descriptions>
          </Card>

          <Card title="About Organization" style={{ marginTop: 16 }} bordered={false}>
            <Paragraph>
              {profile.description || "No description provided yet. Complete your profile in the next phase to help donors understand your mission."}
            </Paragraph>
          </Card>
        </Col>

        <Col span={8}>
          <Card title="Trust & Status" bordered={false}>
            <div style={{ textAlign: 'center', padding: '10px 0' }}>
              <Tag color={profile.status === 'VERIFIED' ? 'success' : 'warning'} style={{ fontSize: '14px', padding: '4px 12px' }}>
                {profile.status}
              </Tag>
              <div style={{ marginTop: 12 }}>
                {profile.status === 'VERIFIED' ? (
                  <Typography.Text type="secondary">Verified on {dayjs(profile.verified_at).format('MMM D, YYYY')}</Typography.Text>
                ) : (
                  <Typography.Text type="secondary">Account pending manual verification</Typography.Text>
                )}
              </div>
            </div>
            <Divider />
            <Statistic 
              title="Wallet Balance" 
              value={profile.wallet_balance} 
              prefix="PKR " 
              precision={2} 
              valueStyle={{ color: '#1677ff' }}
            />
            <Paragraph type="secondary" style={{ marginTop: 8, fontSize: '12px' }}>
              Available funds for withdrawal. Updates automatically after campaign verification.
            </Paragraph>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default NgoProfilePage;
