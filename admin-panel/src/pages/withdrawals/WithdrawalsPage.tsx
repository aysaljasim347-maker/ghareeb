import React, { useState } from 'react';
import { Table, Tag, Button, Space, Typography, Modal, notification, Card } from 'antd';
import { CheckOutlined, CloseOutlined, DownloadOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import type { Withdrawal } from '../../types/withdrawal';
import dayjs from 'dayjs';
import { unwrapResponse, normalizeWithdrawal, safeFormatCurrency } from '../../utils/apiNormalizer';

import { AxiosError } from 'axios';

const { Title } = Typography;

const WithdrawalsPage: React.FC = () => {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const { data, isLoading } = useQuery({
    queryKey: ['admin', 'withdrawals', 'list', page, pageSize],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.WITHDRAWALS, {
        params: { status: 'ALL', page, limit: pageSize }
      });
      return {
        items: unwrapResponse<Withdrawal>(response.data, 'withdrawals').map(normalizeWithdrawal),
        total: response.data.meta?.total || 0
      };
    }
  });

  const withdrawals = data?.items || [];
  const total = data?.total || 0;

  const handleDownloadReport = () => {
    window.open(`${import.meta.env.VITE_API_URL || 'http://127.0.0.1:3000/api'}/admin/reports/withdrawals.csv`, '_blank');
  };

  const approveMutation = useMutation({
    mutationFn: async (id: number) => {
      return axiosClient.post(`/withdrawals/${id}/approve`);
    },
    onSuccess: () => {
      notification.success({ message: 'Withdrawal approved successfully' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'withdrawals'] });
    },
    onError: (error: AxiosError<{ error?: string }>) => {
      notification.error({ 
        message: 'Failed to approve withdrawal',
        description: error.response?.data?.error || 'Internal error'
      });
    }
  });

  const rejectMutation = useMutation({
    mutationFn: async (id: number) => {
      return axiosClient.post(`/withdrawals/${id}/reject`);
    },
    onSuccess: () => {
      notification.success({ message: 'Withdrawal rejected' });
      queryClient.invalidateQueries({ queryKey: ['admin', 'withdrawals'] });
    },
    onError: (error: AxiosError<{ error?: string }>) => {
      notification.error({ 
        message: 'Failed to reject withdrawal',
        description: error.response?.data?.error || 'Internal error'
      });
    }
  });

  const handleApprove = (withdrawal: Withdrawal) => {
    Modal.confirm({
      title: 'Approve Withdrawal',
      content: `Are you sure you want to approve the withdrawal of PKR ${withdrawal.amount} for ${withdrawal.ngo_name}? This will deduct the amount from their wallet.`,
      onOk: () => approveMutation.mutateAsync(withdrawal.id),
      okText: 'Approve',
      cancelText: 'Cancel',
    });
  };

  const handleReject = (withdrawal: Withdrawal) => {
    Modal.confirm({
      title: 'Reject Withdrawal',
      content: `Are you sure you want to reject this withdrawal request?`,
      onOk: () => rejectMutation.mutateAsync(withdrawal.id),
      okType: 'danger',
      okText: 'Reject',
      cancelText: 'Cancel',
    });
  };

  const maskBankAccount = (account: string) => {
    if (account.length <= 8) return account;
    return account.substring(0, 4) + '****' + account.substring(account.length - 4);
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
    },
    {
      title: 'NGO',
      dataIndex: 'ngo_name',
      key: 'ngo_name',
      render: (text: string, record: Withdrawal) => (
        <Space direction="vertical" size={0}>
          <Typography.Text strong>{text}</Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: '12px' }}>{record.ngo_email}</Typography.Text>
        </Space>
      )
    },
    {
      title: 'Amount',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount: number) => safeFormatCurrency(amount),
    },
    {
      title: 'Bank Account',
      dataIndex: 'bank_account',
      key: 'bank_account',
      render: (text: string) => maskBankAccount(text),
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        let color = 'gold';
        if (status === 'APPROVED') color = 'green';
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
      render: (_: unknown, record: Withdrawal) => (
        <Space>
          {record.status === 'PENDING' && (
            <>
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
            </>
          )}
        </Space>
      ),
    },
  ];

  return (
    <Card>
      <div style={{ marginBottom: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title level={3}>Manage Withdrawals</Title>
        <Button 
          icon={<DownloadOutlined />} 
          onClick={handleDownloadReport}
        >
          Download CSV
        </Button>
      </div>
      <Table 
        columns={columns} 
        dataSource={withdrawals} 
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
    </Card>
  );
};

export default WithdrawalsPage;
