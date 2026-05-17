import React from 'react';
import { Typography, notification, Button } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import CampaignForm from './components/CampaignForm';

const { Title, Text } = Typography;

const NgoCampaignCreatePage: React.FC = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const createMutation = useMutation({
    mutationFn: async (values: any) => {
      return axiosClient.post(API_ENDPOINTS.CAMPAIGNS.CREATE, values);
    },
    onSuccess: () => {
      notification.success({
        message: 'Campaign Created',
        description: 'Your campaign has been successfully created as a DRAFT. You can activate it from the list view.',
      });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'campaigns'] });
      navigate('/ngo/campaigns');
    },
    onError: (error: any) => {
      notification.error({
        message: 'Creation Failed',
        description: error.response?.data?.error || 'Could not create campaign. Please check your network.',
      });
    }
  });

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
        <Title level={2}>Launch New Campaign</Title>
        <Text type="secondary">Define your mission and set a funding goal to start receiving donations.</Text>
      </div>

      <CampaignForm 
        onFinish={(v) => createMutation.mutate(v)} 
        loading={createMutation.isPending}
        submitText="Create Campaign"
      />
    </div>
  );
};

export default NgoCampaignCreatePage;
