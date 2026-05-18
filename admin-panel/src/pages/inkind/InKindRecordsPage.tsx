import React from 'react';
import { Table, Card, Typography, Tag, Image, Space } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';

const { Title } = Typography;

interface InKindRecord {
  donation_id: number;
  title: string;
  photo_url: string | null;
  address_text: string;
  accepted_at: string;
  donor_name: string;
  donor_shared_phone: string | null;
  beneficiary_name: string;
  beneficiary_phone: string;
  beneficiary_email: string | null;
}

const InKindRecordsPage: React.FC = () => {
  const { data: records = [], isLoading } = useQuery<InKindRecord[]>({
    queryKey: ['admin', 'inkind', 'records'],
    queryFn: async () => {
      const res = await axiosClient.get('/inkind/admin/records');
      return res.data as InKindRecord[];
    },
  });

  const columns = [
    {
      title: 'Photo',
      key: 'photo',
      width: 80,
      render: (_: unknown, record: InKindRecord) =>
        record.photo_url ? (
          <Image src={record.photo_url} width={60} height={60} style={{ objectFit: 'cover', borderRadius: 6 }} />
        ) : (
          <div
            style={{
              width: 60,
              height: 60,
              background: '#f0f0f0',
              borderRadius: 6,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 10,
              color: '#999',
            }}
          >
            No photo
          </div>
        ),
    },
    {
      title: 'Item',
      key: 'title',
      render: (_: unknown, record: InKindRecord) => (
        <Space direction="vertical" size={0}>
          <Typography.Text strong>{record.title}</Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {record.address_text}
          </Typography.Text>
        </Space>
      ),
    },
    {
      title: 'Donor',
      key: 'donor',
      render: (_: unknown, record: InKindRecord) => (
        <Space direction="vertical" size={0}>
          <Typography.Text>{record.donor_name}</Typography.Text>
          {record.donor_shared_phone ? (
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              {record.donor_shared_phone}
            </Typography.Text>
          ) : (
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              Phone not shared
            </Typography.Text>
          )}
        </Space>
      ),
    },
    {
      title: 'Beneficiary',
      key: 'beneficiary',
      render: (_: unknown, record: InKindRecord) => (
        <Space direction="vertical" size={0}>
          <Typography.Text>{record.beneficiary_name}</Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {record.beneficiary_phone}
          </Typography.Text>
          {record.beneficiary_email && (
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              {record.beneficiary_email}
            </Typography.Text>
          )}
        </Space>
      ),
    },
    {
      title: 'Status',
      key: 'status',
      width: 100,
      render: () => <Tag color="green">COMPLETED</Tag>,
    },
    {
      title: 'Accepted',
      dataIndex: 'accepted_at',
      key: 'accepted_at',
      width: 160,
      render: (date: string) => dayjs(date).format('MMM D, YYYY HH:mm'),
    },
  ];

  return (
    <Card>
      <div style={{ marginBottom: 24 }}>
        <Title level={3}>InKind Donation Records</Title>
        <Typography.Text type="secondary">
          Read-only log of all completed physical item donations.
        </Typography.Text>
      </div>
      <Table
        columns={columns}
        dataSource={records}
        rowKey="donation_id"
        loading={isLoading}
        pagination={{ pageSize: 20, showSizeChanger: true }}
      />
    </Card>
  );
};

export default InKindRecordsPage;
