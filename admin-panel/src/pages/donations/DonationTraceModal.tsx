import React from 'react';
import { Modal, Spin, Alert, Descriptions, Table, Tag, Typography, Divider, Space, Timeline } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';
import { safeFormatCurrency } from '../../utils/apiNormalizer';
import type { Donation } from '../../types/donation';

const { Text } = Typography;

interface LedgerEntry {
  id: number;
  type: string;
  amount_pkr: number;
  created_at: string;
}

interface AuditLog {
  id: number;
  action_type: string;
  admin_name: string;
  ip_address: string;
  created_at: string;
  metadata?: Record<string, unknown>;
}

interface TraceData {
  donation: Donation;
  ledger_entries: LedgerEntry[];
  audit_logs: AuditLog[];
}

interface DonationTraceModalProps {
  id: number | null;
  onClose: () => void;
}

const DonationTraceModal: React.FC<DonationTraceModalProps> = ({ id, onClose }) => {
  const { data, isLoading, error } = useQuery<TraceData | null>({
    queryKey: ['admin', 'donation', 'trace', id],
    queryFn: async () => {
      if (!id) return null;
      const response = await axiosClient.get(`/admin/donations/${id}/full`);
      return response.data.data;
    },
    enabled: !!id,
  });

  if (!id) return null;

  const renderContent = () => {
    if (isLoading) return <div style={{ textAlign: 'center', padding: '40px' }}><Spin /></div>;
    if (error) return <Alert message="Failed to load trace" type="error" />;
    if (!data) return null;

    const { donation, ledger_entries, audit_logs } = data;

    const ledgerColumns = [
      { title: 'Type', dataIndex: 'type', key: 'type', render: (t: string) => <Tag>{t}</Tag> },
      { title: 'Amount', dataIndex: 'amount_pkr', key: 'amount_pkr', render: (v: number) => safeFormatCurrency(v) },
      { title: 'Date', dataIndex: 'created_at', key: 'created_at', render: (d: string) => dayjs(d).format('HH:mm:ss') },
    ];

    return (
      <div>
        <Descriptions title="Donation Info" bordered size="small" column={2}>
          <Descriptions.Item label="ID">{donation.id}</Descriptions.Item>
          <Descriptions.Item label="Status"><Tag color="blue">{donation.status}</Tag></Descriptions.Item>
          <Descriptions.Item label="Donor">{donation.donor_name}</Descriptions.Item>
          <Descriptions.Item label="Email">{donation.donor_email}</Descriptions.Item>
          <Descriptions.Item label="Campaign">{donation.campaign_title}</Descriptions.Item>
          <Descriptions.Item label="Amount">{safeFormatCurrency(donation.amount_pkr)}</Descriptions.Item>
          <Descriptions.Item label="Ref">{donation.gateway_ref}</Descriptions.Item>
          <Descriptions.Item label="Created">{dayjs(donation.created_at).format('MMM D, YYYY HH:mm')}</Descriptions.Item>
        </Descriptions>

        <Divider orientation="left">Ledger Evidence</Divider>
        <Table 
          columns={ledgerColumns} 
          dataSource={ledger_entries} 
          rowKey="id" 
          pagination={false} 
          size="small" 
          footer={() => ledger_entries.length === 0 ? <Text type="danger">No ledger entries found! Financial mismatch risk.</Text> : null}
        />

        <Divider orientation="left">Audit Trail</Divider>
        <Timeline
          items={audit_logs.map((log) => ({
            children: (
              <Space direction="vertical" size={0}>
                <Text strong>{log.action_type}</Text>
                <Text type="secondary" style={{ fontSize: '12px' }}>
                  by {log.admin_name} from {log.ip_address || 'unknown'} at {dayjs(log.created_at).format('MMM D, HH:mm:ss')}
                </Text>
                {log.metadata && <pre style={{ fontSize: '10px' }}>{JSON.stringify(log.metadata)}</pre>}
              </Space>
            ),
            color: log.action_type.includes('REJECT') ? 'red' : 'blue',
          }))}
        />
      </div>
    );
  };

  return (
    <Modal
      title={`Donation Investigation: #${id}`}
      open={!!id}
      onCancel={onClose}
      footer={null}
      width={800}
    >
      {renderContent()}
    </Modal>
  );
};

export default DonationTraceModal;
