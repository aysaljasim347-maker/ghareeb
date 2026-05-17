import React from 'react';
import { Table, Typography, Card, Tabs, Alert } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import dayjs from 'dayjs';
import { normalizeDonation, normalizeWithdrawal, normalizeCampaign, safeFormatCurrency } from '../../utils/apiNormalizer';
import AuditLogsTable from './AuditLogsTable';

const { Title, Text } = Typography;

const LedgerPage: React.FC = () => {
  const { data: ledger, isLoading: loadingLedger, error: ledgerError } = useQuery({
    queryKey: ['admin', 'ledger'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.LEDGER);
      const rawData = response.data?.data || response.data;
      return {
        donations: (rawData.donations || []).map(normalizeDonation),
        withdrawals: (rawData.withdrawals || []).map(normalizeWithdrawal),
        campaigns: (rawData.campaigns || []).map(normalizeCampaign),
      };
    }
  });

  const donationColumns = [
    { title: 'ID', dataIndex: 'id', key: 'id', width: 80 },
    { title: 'Donor', dataIndex: 'donor_name', key: 'donor_name' },
    { title: 'Campaign', dataIndex: 'campaign_title', key: 'campaign_title', ellipsis: true },
    { title: 'Amount', dataIndex: 'amount_pkr', key: 'amount_pkr', render: (val: number) => safeFormatCurrency(val) },
    { title: 'Reference', dataIndex: 'gateway_ref', key: 'gateway_ref' },
    { title: 'Date', dataIndex: 'created_at', key: 'created_at', render: (d: string) => dayjs(d).format('MMM D, YYYY HH:mm') },
  ];

  const withdrawalColumns = [
    { title: 'ID', dataIndex: 'id', key: 'id', width: 80 },
    { title: 'NGO', dataIndex: 'ngo_name', key: 'ngo_name' },
    { title: 'Amount', dataIndex: 'amount', key: 'amount', render: (val: number) => safeFormatCurrency(val) },
    { title: 'Account', dataIndex: 'bank_account', key: 'bank_account', render: (val: string) => val.substring(0, 4) + '****' },
    { title: 'Date', dataIndex: 'created_at', key: 'created_at', render: (d: string) => dayjs(d).format('MMM D, YYYY HH:mm') },
  ];

  const campaignFlowColumns = [
    { title: 'ID', dataIndex: 'id', key: 'id', width: 80 },
    { title: 'Campaign', dataIndex: 'title', key: 'title', ellipsis: true },
    { title: 'Target', dataIndex: 'goal_pkr', key: 'goal_pkr', render: (val: number) => safeFormatCurrency(val) },
    { title: 'Raised', dataIndex: 'raised_pkr', key: 'raised_pkr', render: (val: number) => safeFormatCurrency(val) },
    { title: 'Spent', dataIndex: 'spent_pkr', key: 'spent_pkr', render: (val: number) => safeFormatCurrency(val) },
    { 
      title: 'Balance', 
      key: 'remaining_balance', 
      render: (_: any, record: any) => {
        const balance = record.raised_pkr - record.spent_pkr;
        return (
          <Text strong style={{ color: balance < 0 ? 'red' : 'green' }}>
            {safeFormatCurrency(balance)}
          </Text>
        );
      }
    },
  ];

  if (ledgerError) {
    return <Alert message="Error loading ledger data" type="error" showIcon />;
  }

  const items = [
    {
      key: 'donations',
      label: 'Donations Ledger',
      children: (
        <Table 
          columns={donationColumns} 
          dataSource={ledger?.donations} 
          rowKey="id" 
          loading={loadingLedger} 
          size="small"
        />
      ),
    },
    {
      key: 'withdrawals',
      label: 'Withdrawals Ledger',
      children: (
        <Table 
          columns={withdrawalColumns} 
          dataSource={ledger?.withdrawals} 
          rowKey="id" 
          loading={loadingLedger} 
          size="small"
        />
      ),
    },
    {
      key: 'campaigns',
      label: 'Campaign Financial Flow',
      children: (
        <Table 
          columns={campaignFlowColumns} 
          dataSource={ledger?.campaigns} 
          rowKey="id" 
          loading={loadingLedger} 
          size="small"
        />
      ),
    },
    {
      key: 'audit',
      label: 'Audit Logs (Advanced)',
      children: <AuditLogsTable />,
    },
  ];

  return (
    <Card>
      <Title level={2}>Financial Ledger & Audit Trail</Title>
      <Text type="secondary">Authoritative platform record (Read-Only)</Text>
      <Tabs defaultActiveKey="donations" items={items} style={{ marginTop: 24 }} />
    </Card>
  );
};

export default LedgerPage;
