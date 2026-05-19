import React from 'react';
import { Typography, notification, Button, Spin, Alert } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useNavigate, useParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import CampaignForm from './components/CampaignForm';

const { Title, Text } = Typography;

const NgoCampaignEditPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data: campaign, isLoading, error } = useQuery({
    queryKey: ['ngo', 'campaign', id],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.CAMPAIGNS.UPDATE(Number(id)));
      return response.data;
    }
  });

  const updateMutation = useMutation({
    mutationFn: async (values: unknown) => {
      return axiosClient.patch(API_ENDPOINTS.CAMPAIGNS.UPDATE(Number(id)), values);
    },
    onSuccess: () => {
      notification.success({
        message: 'Campaign Updated',
        description: 'Changes have been saved successfully.',
      });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'campaign', id] });
      navigate('/ngo/campaigns');
    },
    onError: (error: unknown) => {
      const err = error as { response?: { data?: { error?: string } } };
      notification.error({
        message: 'Update Failed',
        description: err.response?.data?.error || 'Could not update campaign. Please check your network.',
      });
    }
  });

  if (isLoading) return <div style={{ textAlign: 'center', padding: '100px' }}><Spin size="large" /></div>;
  if (error) return <Alert message="Error" description="Could not load campaign data." type="error" showIcon />;

  if (campaign.status === 'CLOSED') {
    return (
      <div style={{ padding: '24px' }}>
        <Alert
          message="Campaign Locked"
          description="Closed campaigns cannot be edited. Please contact support if you need to make changes."
          type="warning"
          showIcon
        />
        <Button onClick={() => navigate('/ngo/campaigns')} style={{ marginTop: 16 }}>
          Back to Campaigns
        </Button>
      </div>
    );
  }

  return (
    <div style={{ padding: '0 0 24px 0' }}>
      <Button 
        icon={<ArrowLeftOutlined />} 
        onClick={() => navigate('/ngo/campaigns')} 
        style={{ marginBottom: 16 }}
      >
        Back to Campaigns
      </Button>
      
      <div style={{ marginBottom: 32 }}>
        <Title level={2}>Edit Campaign</Title>
        <Text type="secondary">Update your campaign details and mission objectives.</Text>
      </div>

      <CampaignForm 
        initialValues={campaign}
        onFinish={(v) => updateMutation.mutate(v)} 
        loading={updateMutation.isPending}
        submitText="Save Changes"
      />
    </div>
  );
};

export default NgoCampaignEditPage;
