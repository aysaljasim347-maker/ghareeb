import React, { useState } from 'react';
import { Table, Tag, Typography, Card, Space, Button, Tabs, notification, Modal, Tooltip } from 'antd';
import { 
  PlusOutlined, 
  EyeOutlined, 
  StopOutlined,
  UserOutlined
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate, Link } from 'react-router-dom';
import axiosClient from '../../api/axiosClient';

const { Title, Text } = Typography;

const NgoTasksPage: React.FC = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState('ALL');

  const { data, isLoading } = useQuery({
    queryKey: ['ngo', 'tasks'],
    queryFn: async () => {
      const response = await axiosClient.get('/tasks/my');
      return response.data.data;
    }
  });

  const tasks = data || [];
  
  const filteredTasks = tasks.filter((t: { status: string }) => {
    if (activeTab === 'ALL') return true;
    if (activeTab === 'ACTIVE') return ['CLAIMED', 'IN_PROGRESS', 'SUBMITTED'].includes(t.status);
    return t.status === activeTab;
  });

  const cancelMutation = useMutation({
    mutationFn: async (id: number) => {
      return axiosClient.patch(`/tasks/${id}`, { status: 'CANCELLED' });
    },
    onSuccess: () => {
      notification.success({ message: 'Task Cancelled' });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'tasks'] });
    }
  });

  const handleCancel = (id: number) => {
    Modal.confirm({
      title: 'Cancel Task',
      content: 'Are you sure you want to cancel this task? It will be removed from volunteer discovery.',
      okType: 'danger',
      onOk: () => cancelMutation.mutateAsync(id),
    });
  };

  const columns = [
    {
      title: 'Task Title',
      dataIndex: 'title',
      key: 'title',
      ellipsis: true,
      render: (text: string) => <Text strong>{text}</Text>,
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        let color = 'default';
        if (status === 'OPEN') color = 'blue';
        if (status === 'CLAIMED') color = 'cyan';
        if (status === 'IN_PROGRESS') color = 'orange';
        if (status === 'SUBMITTED') color = 'purple';
        if (status === 'VERIFIED' || status === 'PAID') color = 'green';
        if (status === 'CANCELLED') color = 'red';
        return <Tag color={color}>{status}</Tag>;
      },
    },
    {
      title: 'Volunteer',
      dataIndex: 'claimed_by_name',
      key: 'claimed_by_name',
      render: (name: string) => name ? (
        <Space>
          <UserOutlined />
          <Text style={{ fontSize: '12px' }}>{name}</Text>
        </Space>
      ) : <Text type="secondary" style={{ fontSize: '12px' }}>-</Text>
    },
    {
      title: 'Urgency',
      dataIndex: 'urgency',
      key: 'urgency',
      render: (u: string) => {
        const colors: Record<string, string> = { CRITICAL: 'red', HIGH: 'volcano', MEDIUM: 'gold', LOW: 'blue' };
        return <Tag color={colors[u]}>{u}</Tag>;
      }
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: unknown, record: { id: number; status: string }) => (
        <Space>
          <Tooltip title="View Details">
            <Link to={`/ngo/tasks/${record.id}`}>
              <Button icon={<EyeOutlined />} size="small" />
            </Link>
          </Tooltip>
          {record.status === 'OPEN' && (
            <Tooltip title="Cancel Task">
              <Button 
                danger 
                icon={<StopOutlined />} 
                size="small" 
                onClick={() => handleCancel(record.id)}
              />
            </Tooltip>
          )}
        </Space>
      ),
    },
  ];

  const tabItems = [
    { key: 'ALL', label: 'All Tasks' },
    { key: 'OPEN', label: 'Open' },
    { key: 'ACTIVE', label: 'In Execution' },
    { key: 'VERIFIED', label: 'Completed' },
    { key: 'CANCELLED', label: 'Cancelled' },
  ];

  return (
    <Card>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={3} style={{ margin: 0 }}>Operational Tasks</Title>
        <Button 
          type="primary" 
          icon={<PlusOutlined />} 
          size="large"
          onClick={() => navigate('/ngo/tasks/new')}
        >
          Create New Task
        </Button>
      </div>

      <Tabs 
        activeKey={activeTab} 
        onChange={setActiveTab} 
        items={tabItems} 
        style={{ marginBottom: 24 }}
      />

      <Table 
        columns={columns} 
        dataSource={filteredTasks} 
        rowKey="id" 
        loading={isLoading}
        pagination={{ pageSize: 10 }}
      />
    </Card>
  );
};

export default NgoTasksPage;
