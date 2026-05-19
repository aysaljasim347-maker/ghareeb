import React, { useState } from 'react';
import { Table, Tag, Button, Space, Typography, Modal, notification, Card } from 'antd';
import { CheckOutlined, CloseOutlined, EyeOutlined, DownloadOutlined, ProfileOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { AxiosError } from 'axios';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import type { Donation } from '../../types/donation';
import dayjs from 'dayjs';
import { unwrapResponse, normalizeDonation, safeFormatCurrency } from '../../utils/apiNormalizer';
import DonationTraceModal from './DonationTraceModal';

const { Title, Text } = Typography;

const DonationsPage: React.FC = () => {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [selectedDonationId, setSelectedDonationId] = useState<number | null>(null);
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);

  const { data, isLoading } = useQuery({
    queryKey: ['admin', 'donations', 'list', page, pageSize],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.DONATIONS, {
        params: { status: 'ALL', page, limit: pageSize }
      });
      return {
        items: unwrapResponse<Record<string, unknown>>(response.data, 'donations').map(normalizeDonation),
        total: (response.data as { meta?: { total?: number } }).meta?.total || 0
      };
    }
  });

  const donations = data?.items || [];
  const total = data?.total || 0;

  const bulkActionMutation = useMutation({
    mutationFn: async ({ donation_ids, action }: { donation_ids: number[], action: string }) => {
      return axiosClient.post('/admin/donations/bulk-action', { donation_ids, action });
    },
    onSuccess: (data) => {
      const { success, failed } = data.data;
      notification.success({ 
        message: 'Bulk Action Complete', 
        description: `Successfully processed ${success.length} donations. ${failed.length} failed.` 
      });
      setSelectedRowKeys([]);
      queryClient.invalidateQueries({ queryKey: ['admin', 'donations'] });
    }
  });

  const handleBulkAction = (action: 'APPROVE' | 'REJECT') => {
    Modal.confirm({
      title: `Bulk ${action === 'APPROVE' ? 'Approve' : 'Reject'}`,
      content: `Are you sure you want to ${action.toLowerCase()} ${selectedRowKeys.length} selected donations? This will update campaign balances.`,
      onOk: () => bulkActionMutation.mutateAsync({ 
        donation_ids: selectedRowKeys.map(k => Number(k)), 
        action 
      }),
    });
  };

  const handleDownloadReport = () => {
    window.open(`${import.meta.env.VITE_API_URL || 'http://127.0.0.1:3000/api'}/admin/reports/donations.csv`, '_blank');
  };

  const approveMutation = useMutation({
    mutationFn: async (id: number) => {
      return axiosClient.post(`/donations/${id}/approve`);
    },
    onSuccess: () => {
      notification.success({ message: 'Donation confirmed successfully' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'donations'] });
    },
    onError: (error: AxiosError<{ error?: string }>) => {
      notification.error({ 
        message: 'Failed to confirm donation',
        description: error.response?.data?.error || 'Internal error'
      });
    }
  });

  const rejectMutation = useMutation({
    mutationFn: async (id: number) => {
      return axiosClient.post(`/donations/${id}/reject`);
    },
    onSuccess: () => {
      notification.success({ message: 'Donation rejected' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'donations'] });
    },
    onError: (error: AxiosError<{ error?: string }>) => {
      notification.error({ 
        message: 'Failed to reject donation',
        description: error.response?.data?.error || 'Internal error'
      });
    }
  });

  const handleApprove = (donation: Donation) => {
    Modal.confirm({
      title: 'Confirm Donation',
      content: `Are you sure you want to confirm the donation of PKR ${donation.amount_pkr} from ${donation.donor_name}? This will update the campaign balance.`,
      onOk: () => approveMutation.mutateAsync(donation.id),
      okText: 'Confirm',
      cancelText: 'Cancel',
    });
  };

  const handleReject = (donation: Donation) => {
    Modal.confirm({
      title: 'Reject Donation',
      content: `Are you sure you want to reject this donation?`,
      onOk: () => rejectMutation.mutateAsync(donation.id),
      okType: 'danger',
      okText: 'Reject',
      cancelText: 'Cancel',
    });
  };

  const flagMutation = useMutation({
    mutationFn: async ({ id, reason }: { id: number, reason: string }) => {
      return axiosClient.post(`/admin/donations/${id}/flag`, { reason });
    },
    onSuccess: () => {
      notification.success({ message: 'Donation flagged for review' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'donations'] });
    }
  });

  const handleFlag = (donation: Donation) => {
    let reason = '';
    Modal.confirm({
      title: 'Flag Donation for Dispute',
      content: (
        <div style={{ marginTop: 16 }}>
          <p>Reason for dispute/flag:</p>
          <input 
            className="ant-input" 
            onChange={(e) => reason = e.target.value} 
            placeholder="e.g. Fraudulent receipt"
          />
        </div>
      ),
      onOk: () => flagMutation.mutateAsync({ id: donation.id, reason }),
      okType: 'danger',
    });
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
    },
    {
      title: 'Donor',
      dataIndex: 'donor_name',
      key: 'donor_name',
      render: (text: string, record: Donation) => (
        <Space orientation="vertical" size={0}>
          <Typography.Text strong>{text}</Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: '12px' }}>{record.donor_email}</Typography.Text>
        </Space>
      )
    },
    {
      title: 'Campaign',
      dataIndex: 'campaign_title',
      key: 'campaign_title',
      ellipsis: true,
    },
    {
      title: 'Amount',
      dataIndex: 'amount_pkr',
      key: 'amount_pkr',
      render: (amount: number) => safeFormatCurrency(amount),
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        let color = 'gold';
        if (status === 'CONFIRMED') color = 'green';
        if (status === 'REJECTED') color = 'red';
        return <Tag color={color}>{status}</Tag>;
      }
    },
    {
      title: 'Date',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (date: string) => dayjs(date).format('MMM D, YYYY HH:mm'),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: unknown, record: Donation) => (
        <Space>
          {record.receipt_url && (
            <Button 
              icon={<EyeOutlined />} 
              size="small" 
              onClick={() => window.open(record.receipt_url, '_blank')}
            >
              Receipt
            </Button>
          )}
          {record.status === 'PENDING' && (
            <Button 
              type="primary" 
              icon={<CheckOutlined />} 
              size="small"
              loading={approveMutation.isPending && approveMutation.variables === record.id}
              disabled={approveMutation.isPending || rejectMutation.isPending}
              onClick={() => handleApprove(record)}
            >
              Approve
            </Button>
          )}
          {record.status === 'PENDING' && (
            <Button 
              danger 
              icon={<CloseOutlined />} 
              size="small"
              loading={rejectMutation.isPending && rejectMutation.variables === record.id}
              disabled={approveMutation.isPending || rejectMutation.isPending}
              onClick={() => handleReject(record)}
            >
              Reject
            </Button>
          )}
          {record.status === 'CONFIRMED' && !record.metadata?.disputed && (
            <Button 
              danger 
              ghost 
              size="small"
              onClick={() => handleFlag(record)}
            >
              Flag Dispute
            </Button>
          )}
          {record.metadata?.disputed && <Tag color="error">DISPUTED</Tag>}
          <Button 
            icon={<ProfileOutlined />} 
            size="small"
            onClick={() => setSelectedDonationId(record.id)}
          >
            Investigate
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <Card>
      <div style={{ marginBottom: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={3}>Manage Donations</Title>
        <Space>
          {selectedRowKeys.length > 0 && (
            <Space style={{ marginRight: 16 }}>
              <Text strong>{selectedRowKeys.length} selected</Text>
              <Button 
                type="primary" 
                onClick={() => handleBulkAction('APPROVE')}
                loading={bulkActionMutation.isPending}
              >
                Bulk Approve
              </Button>
              <Button 
                danger 
                onClick={() => handleBulkAction('REJECT')}
                loading={bulkActionMutation.isPending}
              >
                Bulk Reject
              </Button>
            </Space>
          )}
          <Button 
            icon={<DownloadOutlined />} 
            onClick={handleDownloadReport}
          >
            Download CSV
          </Button>
        </Space>
      </div>
      <Table 
        rowSelection={{
          selectedRowKeys,
          onChange: (keys) => setSelectedRowKeys(keys),
          getCheckboxProps: (record: Donation) => ({
            disabled: record.status !== 'PENDING',
          }),
        }}
        columns={columns} 
        dataSource={donations} 
        rowKey="id" 
        loading={isLoading}
        pagination={{
          current: page,
          pageSize: pageSize,
          total: total,
          showSizeChanger: true,
          onChange: (p, s) => {
            setPage(p);
            setPageSize(s);
          }
        }}
      />
      <DonationTraceModal 
        id={selectedDonationId} 
        onClose={() => setSelectedDonationId(null)} 
      />
    </Card>
  );
};

export default DonationsPage;
