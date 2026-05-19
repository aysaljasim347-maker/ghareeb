import React, { useState } from 'react';
import {
  Table,
  Tag,
  Typography,
  Card,
  Tabs,
  Space,
  Image,
  Tooltip,
  Input,
  Spin,
  Alert,
} from 'antd';
import { SearchOutlined } from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import dayjs from 'dayjs';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';

const { Title, Text } = Typography;
const { Search } = Input;

interface GoodsDonation {
  id: number;
  campaign_title: string;
  donor_name: string;
  item_name: string;
  category: string;
  quantity: number;
  unit: string;
  pickup_address: string;
  contact_number: string;
  status: string;
  volunteer_name: string | null;
  proof_photo_url: string | null;
  delivered_at: string | null;
  approved_at: string | null;
  rejected_at: string | null;
  rejection_reason: string | null;
  submitted_at: string;
}

const STATUS_COLORS: Record<string, string> = {
  PENDING:   'orange',
  ASSIGNED:  'blue',
  DELIVERED: 'purple',
  APPROVED:  'green',
  REJECTED:  'red',
};

const STATUS_TABS = ['ALL', 'PENDING', 'ASSIGNED', 'DELIVERED', 'APPROVED', 'REJECTED'];

const NgoGoodsDonationsPage: React.FC = () => {
  const [activeTab, setActiveTab] = useState('ALL');
  const [search, setSearch] = useState('');

  const { data: donations = [], isLoading, error } = useQuery<GoodsDonation[]>({
    queryKey: ['ngo', 'goods-donations'],
    queryFn: async () => {
      const res = await axiosClient.get(API_ENDPOINTS.GOODS_DONATIONS.NGO);
      return (res.data as { data: GoodsDonation[] }).data;
    },
  });

  const filtered = donations.filter((d) => {
    const matchesTab = activeTab === 'ALL' || d.status === activeTab;
    const q = search.toLowerCase();
    const matchesSearch =
      !q ||
      d.item_name.toLowerCase().includes(q) ||
      d.donor_name.toLowerCase().includes(q) ||
      d.campaign_title.toLowerCase().includes(q);
    return matchesTab && matchesSearch;
  });

  const columns = [
    {
      title: 'Item',
      key: 'item',
      render: (_: unknown, r: GoodsDonation) => (
        <Space direction="vertical" size={0}>
          <Text strong>{r.item_name}</Text>
          <Text type="secondary" style={{ fontSize: 12 }}>
            {r.quantity} {r.unit} · {r.category}
          </Text>
        </Space>
      ),
    },
    {
      title: 'Campaign',
      dataIndex: 'campaign_title',
      key: 'campaign',
      render: (t: string) => (
        <Text style={{ fontSize: 13 }} ellipsis={{ tooltip: t }}>
          {t}
        </Text>
      ),
    },
    {
      title: 'Donor',
      key: 'donor',
      render: (_: unknown, r: GoodsDonation) => (
        <Space direction="vertical" size={0}>
          <Text>{r.donor_name}</Text>
          <Text type="secondary" style={{ fontSize: 12 }}>
            {r.contact_number}
          </Text>
        </Space>
      ),
    },
    {
      title: 'Pickup Address',
      dataIndex: 'pickup_address',
      key: 'address',
      render: (addr: string) => (
        <Tooltip title={addr}>
          <Text ellipsis style={{ maxWidth: 180, fontSize: 13 }}>
            {addr}
          </Text>
        </Tooltip>
      ),
    },
    {
      title: 'Volunteer',
      key: 'volunteer',
      render: (_: unknown, r: GoodsDonation) =>
        r.volunteer_name ? (
          <Text>{r.volunteer_name}</Text>
        ) : (
          <Text type="secondary">—</Text>
        ),
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (s: string) => <Tag color={STATUS_COLORS[s] ?? 'default'}>{s}</Tag>,
    },
    {
      title: 'Proof',
      key: 'proof',
      render: (_: unknown, r: GoodsDonation) =>
        r.proof_photo_url ? (
          <Image
            src={r.proof_photo_url}
            width={48}
            height={48}
            style={{ objectFit: 'cover', borderRadius: 6 }}
          />
        ) : (
          <Text type="secondary" style={{ fontSize: 12 }}>—</Text>
        ),
    },
    {
      title: 'Submitted',
      dataIndex: 'submitted_at',
      key: 'submitted',
      render: (d: string) => dayjs(d).format('MMM D, YYYY'),
    },
    {
      title: 'Notes',
      key: 'notes',
      render: (_: unknown, r: GoodsDonation) => {
        if (r.status === 'REJECTED' && r.rejection_reason) {
          return (
            <Tooltip title={r.rejection_reason}>
              <Tag color="red" style={{ cursor: 'help' }}>See Reason</Tag>
            </Tooltip>
          );
        }
        if (r.status === 'APPROVED' && r.approved_at) {
          return (
            <Text type="secondary" style={{ fontSize: 12 }}>
              Approved {dayjs(r.approved_at).format('MMM D')}
            </Text>
          );
        }
        return null;
      },
    },
  ];

  const tabItems = STATUS_TABS.map((s) => ({
    key: s,
    label: (
      <span>
        {s === 'ALL' ? 'All' : s[0] + s.slice(1).toLowerCase()}
        {s !== 'ALL' && (
          <Tag
            color={STATUS_COLORS[s] ?? 'default'}
            style={{ marginLeft: 6, fontSize: 10 }}
          >
            {donations.filter((d) => d.status === s).length}
          </Tag>
        )}
      </span>
    ),
  }));

  return (
    <Card>
      <div style={{ marginBottom: 24 }}>
        <Title level={3}>Goods Donations</Title>
        <Text type="secondary">
          Track item donations across all your goods campaigns.
        </Text>
      </div>

      {error && (
        <Alert
          type="error"
          message="Failed to load donations"
          style={{ marginBottom: 16 }}
        />
      )}

      <div style={{ marginBottom: 16 }}>
        <Search
          placeholder="Search by item, donor, or campaign…"
          prefix={<SearchOutlined />}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ width: 320 }}
          allowClear
        />
      </div>

      <Tabs
        activeKey={activeTab}
        onChange={setActiveTab}
        items={tabItems}
        style={{ marginBottom: 16 }}
      />

      <Spin spinning={isLoading}>
        <Table
          columns={columns}
          dataSource={filtered}
          rowKey="id"
          pagination={{ pageSize: 15, showSizeChanger: true }}
          scroll={{ x: 900 }}
        />
      </Spin>
    </Card>
  );
};

export default NgoGoodsDonationsPage;
