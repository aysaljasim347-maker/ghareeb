import React, { useState } from 'react';
import { Table, Button, Space, Typography, Modal, notification, Card } from 'antd';
import { CheckCircleOutlined, CloseCircleOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';

const { Title, Text } = Typography;

const NgoVerificationPage: React.FC = () => {
  const queryClient = useQueryClient();
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);

  const { data, isLoading } = useQuery({
    queryKey: ['admin', 'ngos', 'pending'],
    queryFn: async () => {
      const response = await axiosClient.get('/admin/ngos/pending');
      return response.data.data;
    }
  });

  const bulkVerifyMutation = useMutation({
    mutationFn: async ({ ngo_ids }: { ngo_ids: number[] }) => {
      return axiosClient.post('/admin/ngos/bulk-verify', { ngo_ids, action: 'VERIFY' });
    },
    onSuccess: (data) => {
      const { success, failed } = data.data;
      notification.success({ 
        message: 'Bulk Action Complete', 
        description: `Successfully verified ${success.length} NGOs. ${failed.length} failed.` 
      });
      setSelectedRowKeys([]);
      queryClient.invalidateQueries({ queryKey: ['admin', 'ngos'] });
    }
  });

  const handleBulkVerify = () => {
    Modal.confirm({
      title: 'Bulk Verify NGOs',
      content: `Are you sure you want to verify ${selectedRowKeys.length} selected NGOs?`,
      onOk: () => bulkVerifyMutation.mutateAsync({ ngo_ids: selectedRowKeys.map(k => Number(k)) }),
    });
  };

  const verifyMutation = useMutation({
    mutationFn: async (id: number) => {
      return axiosClient.post(`/admin/ngos/${id}/verify`);
    },
    onSuccess: () => {
      notification.success({ message: 'NGO verified successfully' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'ngos'] });
    }
  });

  const rejectMutation = useMutation({
    mutationFn: async ({ id, reason }: { id: number, reason: string }) => {
      return axiosClient.post(`/admin/ngos/${id}/reject`, { reason });
    },
    onSuccess: () => {
      notification.success({ message: 'NGO rejected' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'ngos'] });
    }
  });

  const handleVerify = (ngo: { id: number, org_name: string }) => {
    Modal.confirm({
      title: 'Verify NGO',
      content: `Verify "${ngo.org_name}"? This allows them to create campaigns and request withdrawals.`,
      onOk: () => verifyMutation.mutateAsync(ngo.id),
    });
  };

  const handleReject = (ngo: { id: number }) => {
    let reason = '';
    Modal.confirm({
      title: 'Reject NGO Registration',
      content: (
        <div style={{ marginTop: 16 }}>
          <p>Reason for rejection:</p>
          <input 
            className="ant-input" 
            onChange={(e) => reason = e.target.value} 
            placeholder="e.g. Invalid registration documents"
          />
        </div>
      ),
      onOk: () => rejectMutation.mutateAsync({ id: ngo.id, reason }),
      okType: 'danger',
    });
  };

  const columns = [
    { title: 'Org Name', dataIndex: 'org_name', key: 'org_name', render: (val: string) => <Text strong>{val}</Text> },
    { title: 'Reg #', dataIndex: 'registration_number', key: 'registration_number' },
    { title: 'Representative', dataIndex: 'user_name', key: 'user_name', render: (val: string, record: { email: string }) => (
      <div>{val}<br/><Text type="secondary">{record.email}</Text></div>
    )},
    { title: 'Submitted', dataIndex: 'created_at', key: 'created_at', render: (val: string) => dayjs(val).format('MMM D, YYYY') },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: unknown, record: { id: number, org_name: string }) => (
        <Space>
          <Button 
            type="primary" 
            icon={<CheckCircleOutlined />} 
            size="small"
            onClick={() => handleVerify(record)}
          >
            Verify
          </Button>
          <Button 
            danger 
            icon={<CloseCircleOutlined />} 
            size="small"
            onClick={() => handleReject(record)}
          >
            Reject
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <Card>
      <div style={{ marginBottom: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <Title level={2} style={{ marginBottom: 0 }}>Pending NGO Verifications</Title>
          <Text type="secondary">Review and approve NGO platform registrations</Text>
        </div>
        {selectedRowKeys.length > 0 && (
          <Space>
            <Text strong>{selectedRowKeys.length} selected</Text>
            <Button 
              type="primary" 
              icon={<CheckCircleOutlined />}
              onClick={handleBulkVerify}
              loading={bulkVerifyMutation.isPending}
            >
              Bulk Verify
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
        dataSource={data} 
        rowKey="id" 
        loading={isLoading}
        style={{ marginTop: 24 }}
      />
    </Card>
  );
};

export default NgoVerificationPage;
