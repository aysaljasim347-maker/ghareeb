import React, { useState } from 'react';
import { Table, Tag, Button, Space, Typography, Modal, notification, Card } from 'antd';
import { PlayCircleOutlined, PauseCircleOutlined, StopOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { AxiosError } from 'axios';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import type { Campaign, CampaignStatus } from '../../types/campaign';
import dayjs from 'dayjs';
import { unwrapResponse, normalizeCampaign, safeFormatCurrency } from '../../utils/apiNormalizer';

const { Title, Text } = Typography;

const CampaignsPage: React.FC = () => {
  const queryClient = useQueryClient();
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);

  const { data, isLoading } = useQuery({
    queryKey: ['admin', 'campaigns', 'list'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.CAMPAIGNS);
      return unwrapResponse<Record<string, unknown>>(response.data, 'campaigns').map(normalizeCampaign);
    }
  });

  const campaigns = data || [];

  const bulkStatusMutation = useMutation({
    mutationFn: async ({ campaign_ids, status }: { campaign_ids: number[], status: CampaignStatus }) => {
      return axiosClient.post('/admin/campaigns/bulk-status', { campaign_ids, status });
    },
    onSuccess: (data) => {
      const { success, failed } = data.data;
      notification.success({ 
        message: 'Bulk Action Complete', 
        description: `Successfully updated ${success.length} campaigns. ${failed.length} failed.` 
      });
      setSelectedRowKeys([]);
      queryClient.invalidateQueries({ queryKey: ['admin', 'campaigns'] });
    }
  });

  const handleBulkStatus = (status: CampaignStatus) => {
    Modal.confirm({
      title: `Bulk ${status.toLowerCase()} Campaigns`,
      content: `Are you sure you want to set status to ${status} for ${selectedRowKeys.length} selected campaigns?`,
      onOk: () => bulkStatusMutation.mutateAsync({ 
        campaign_ids: selectedRowKeys.map(k => Number(k)), 
        status 
      }),
    });
  };

  const statusMutation = useMutation({
    mutationFn: async ({ id, status }: { id: number, status: CampaignStatus }) => {
      return axiosClient.patch(API_ENDPOINTS.CAMPAIGNS.UPDATE_STATUS(id), { status });
    },
    onSuccess: () => {
      notification.success({ message: 'Campaign status updated' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'campaigns'] });
    },
    onError: (error: AxiosError<{ error?: string }>) => {
      notification.error({ 
        message: 'Failed to update campaign status',
        description: error.response?.data?.error || 'Internal error'
      });
    }
  });

  const handleStatusChange = (campaign: Campaign, newStatus: CampaignStatus) => {
    const actionLabel = newStatus.toLowerCase();
    
    Modal.confirm({
      title: `Confirm Status Change`,
      content: `Are you sure you want to ${actionLabel} the campaign "${campaign.title}"?`,
      onOk: () => statusMutation.mutateAsync({ id: campaign.id, status: newStatus }),
      okText: 'Confirm',
      cancelText: 'Cancel',
    });
  };

  const getStatusColor = (status: CampaignStatus) => {
    switch (status) {
      case 'ACTIVE': return 'green';
      case 'PAUSED': return 'orange';
      case 'CLOSED': return 'red';
      case 'DRAFT': return 'blue';
      default: return 'default';
    }
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
    },
    {
      title: 'Title',
      dataIndex: 'title',
      key: 'title',
      ellipsis: true,
      render: (text: string) => <Typography.Text strong>{text}</Typography.Text>
    },
    {
      title: 'NGO / Owner',
      dataIndex: 'ngo_name',
      key: 'ngo_name',
      render: (text: string, record: Campaign) => text || record.created_by_name || 'N/A'
    },
    {
      title: 'Progress',
      key: 'progress',
      render: (_: unknown, record: Campaign) => (
        <Space direction="vertical" size={0}>
          <Typography.Text style={{ fontSize: '12px' }}>
            {safeFormatCurrency(record.raised_pkr)} / {safeFormatCurrency(record.goal_pkr)}
          </Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: '11px' }}>
            {((record.raised_pkr / (record.goal_pkr || 1)) * 100).toFixed(1)}% funded
          </Typography.Text>
        </Space>
      )
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: CampaignStatus) => <Tag color={getStatusColor(status)}>{status}</Tag>
    },
    {
      title: 'Created At',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (date: string) => dayjs(date).format('MMM D, YYYY'),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: unknown, record: Campaign) => {
        const isClosed = record.status === 'CLOSED';
        return (
          <Space>
            {record.status !== 'ACTIVE' && !isClosed && (
              <Button 
                icon={<PlayCircleOutlined />} 
                size="small" 
                type="primary"
                ghost
                onClick={() => handleStatusChange(record, 'ACTIVE')}
              >
                Activate
              </Button>
            )}
            {record.status === 'ACTIVE' && (
              <Button 
                icon={<PauseCircleOutlined />} 
                size="small" 
                onClick={() => handleStatusChange(record, 'PAUSED')}
                style={{ color: '#faad14', borderColor: '#faad14' }}
              >
                Pause
              </Button>
            )}
            {!isClosed && (
              <Button 
                danger 
                icon={<StopOutlined />} 
                size="small"
                onClick={() => handleStatusChange(record, 'CLOSED')}
              >
                Close
              </Button>
            )}
            {isClosed && <Typography.Text type="secondary" disabled>No actions</Typography.Text>}
          </Space>
        );
      },
    },
  ];

  return (
    <Card>
      <div style={{ marginBottom: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={3}>Campaign Governance</Title>
        {selectedRowKeys.length > 0 && (
          <Space>
            <Text strong>{selectedRowKeys.length} selected</Text>
            <Button 
              type="primary" 
              ghost 
              onClick={() => handleBulkStatus('ACTIVE')}
              loading={bulkStatusMutation.isPending}
            >
              Bulk Activate
            </Button>
            <Button 
              onClick={() => handleBulkStatus('PAUSED')}
              loading={bulkStatusMutation.isPending}
            >
              Bulk Pause
            </Button>
            <Button 
              danger 
              onClick={() => handleBulkStatus('CLOSED')}
              loading={bulkStatusMutation.isPending}
            >
              Bulk Close
            </Button>
          </Space>
        )}
      </div>
      <Table 
        rowSelection={{
          selectedRowKeys,
          onChange: (keys) => setSelectedRowKeys(keys),
        }}
        columns={columns} 
        dataSource={campaigns} 
        rowKey="id" 
        loading={isLoading}
        pagination={{ pageSize: 10 }}
      />
    </Card>
  );
};

export default CampaignsPage;
