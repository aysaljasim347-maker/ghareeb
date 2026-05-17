import React, { useState } from 'react';
import { Table, Tag, Typography, Card, Space, Progress, Input, Select, Divider, Button, Modal, notification, Tooltip } from 'antd';
import { 
  PlusOutlined, 
  EditOutlined, 
  PlayCircleOutlined, 
  PauseCircleOutlined, 
  StopOutlined 
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate, Link } from 'react-router-dom';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import { safeFormatCurrency } from '../../utils/apiNormalizer';
import type { Campaign, CampaignStatus } from '../../types/campaign';
import dayjs from 'dayjs';

const { Title, Text } = Typography;
const { Search } = Input;

const NgoCampaignsPage: React.FC = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [searchText, setSearchText] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['ngo', 'campaigns'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.NGO.CAMPAIGNS);
      return response.data.data;
    }
  });

  const statusMutation = useMutation({
    mutationFn: async ({ id, status }: { id: number, status: CampaignStatus }) => {
      return axiosClient.patch(API_ENDPOINTS.CAMPAIGNS.UPDATE_STATUS(id), { status });
    },
    onSuccess: (_, variables) => {
      notification.success({ 
        message: 'Status Updated', 
        description: `Campaign is now ${variables.status}.` 
      });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'campaigns'] });
    },
    onError: (error: any) => {
      notification.error({ 
        message: 'Update Failed',
        description: error.response?.data?.error || 'Could not change status.'
      });
    }
  });

  const handleStatusChange = (campaign: Campaign, newStatus: CampaignStatus) => {
    Modal.confirm({
      title: `Confirm Status Change`,
      content: `Are you sure you want to change status to ${newStatus} for "${campaign.title}"?`,
      onOk: () => statusMutation.mutateAsync({ id: campaign.id, status: newStatus }),
    });
  };

  const campaigns = (data || []).filter((c: any) => {
    const matchesStatus = statusFilter === 'ALL' || c.status === statusFilter;
    const matchesSearch = c.title.toLowerCase().includes(searchText.toLowerCase());
    return matchesStatus && matchesSearch;
  });

  const columns = [
    {
      title: 'Campaign Title',
      dataIndex: 'title',
      key: 'title',
      render: (text: string) => <Text strong>{text}</Text>,
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        let color = 'default';
        if (status === 'ACTIVE') color = 'green';
        if (status === 'PAUSED') color = 'orange';
        if (status === 'CLOSED') color = 'red';
        if (status === 'DRAFT') color = 'blue';
        return <Tag color={color}>{status}</Tag>;
      },
    },
    {
      title: 'Progress',
      key: 'progress',
      width: 200,
      render: (_: any, record: any) => {
        const percent = Math.round((record.raised_pkr / record.goal_pkr) * 100);
        const isUrgent = percent >= 70 && record.status === 'ACTIVE';
        return (
          <Space direction="vertical" size={0} style={{ width: '100%' }}>
            <Progress 
              percent={Math.min(100, percent)} 
              status={isUrgent ? 'exception' : 'normal'}
              strokeColor={isUrgent ? '#f5222d' : undefined}
              size="small" 
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px' }}>
              <Text type="secondary">{safeFormatCurrency(record.raised_pkr)}</Text>
              <Text type="secondary">Goal: {safeFormatCurrency(record.goal_pkr)}</Text>
            </div>
          </Space>
        );
      }
    },
    {
      title: 'Created',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (d: string) => dayjs(d).format('MMM D, YYYY'),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: Campaign) => {
        const isClosed = record.status === 'CLOSED';
        return (
          <Space>
            {!isClosed && (
              <Tooltip title="Edit Details">
                <Link to={`/ngo/campaigns/${record.id}/edit`}>
                  <Button icon={<EditOutlined />} size="small" />
                </Link>
              </Tooltip>
            )}
            
            {record.status === 'DRAFT' && (
              <Button 
                size="small" 
                type="primary" 
                ghost 
                icon={<PlayCircleOutlined />}
                onClick={() => handleStatusChange(record, 'ACTIVE')}
              >
                Activate
              </Button>
            )}

            {record.status === 'ACTIVE' && (
              <Button 
                size="small" 
                icon={<PauseCircleOutlined />}
                onClick={() => handleStatusChange(record, 'PAUSED')}
              />
            )}

            {record.status === 'PAUSED' && (
              <Button 
                size="small" 
                type="primary" 
                ghost 
                icon={<PlayCircleOutlined />}
                onClick={() => handleStatusChange(record, 'ACTIVE')}
              >
                Resume
              </Button>
            )}

            {!isClosed && record.status !== 'DRAFT' && (
              <Button 
                danger 
                size="small" 
                icon={<StopOutlined />}
                onClick={() => handleStatusChange(record, 'CLOSED')}
              />
            )}
          </Space>
        );
      }
    }
  ];

  return (
    <Card>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={3} style={{ margin: 0 }}>My Campaigns</Title>
        <Button 
          type="primary" 
          icon={<PlusOutlined />} 
          size="large"
          onClick={() => navigate('/ngo/campaigns/new')}
        >
          Launch New Campaign
        </Button>
      </div>
      
      <Divider />
      
      <div style={{ marginBottom: 24, display: 'flex', gap: 16 }}>
        <Search 
          placeholder="Search campaigns..." 
          onSearch={setSearchText} 
          style={{ width: 300 }} 
          allowClear
        />
        <Select 
          defaultValue="ALL" 
          style={{ width: 150 }} 
          onChange={setStatusFilter}
          options={[
            { value: 'ALL', label: 'All Status' },
            { value: 'DRAFT', label: 'Draft' },
            { value: 'ACTIVE', label: 'Active' },
            { value: 'PAUSED', label: 'Paused' },
            { value: 'CLOSED', label: 'Closed' },
          ]}
        />
      </div>

      <Table 
        columns={columns} 
        dataSource={campaigns} 
        rowKey="id" 
        loading={isLoading}
        pagination={{ pageSize: 10 }}
      />
    </Card>
  );
};

export default NgoCampaignsPage;
