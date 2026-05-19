import React, { useState } from 'react';
import { Table, Tag, Typography, Space, Input, Select, DatePicker, Button, Form } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import dayjs from 'dayjs';

const { Text } = Typography;
const { RangePicker } = DatePicker;

interface AuditLogEntry {
  id: number;
  admin_name: string;
  admin_email: string;
  action_type: string;
  target_entity: string;
  target_id: string | number;
  metadata: Record<string, unknown>;
  ip_address: string;
  created_at: string;
}

interface AuditLogFilters {
  action_type?: string;
  target_entity?: string;
  target_id?: string | number;
  from_date?: string;
  to_date?: string;
}

interface FilterFormValues {
  action_type?: string;
  target_entity?: string;
  target_id?: string | number;
  date_range?: [dayjs.Dayjs, dayjs.Dayjs];
}

const AuditLogsTable: React.FC = () => {
  const [form] = Form.useForm<FilterFormValues>();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [filters, setFilters] = useState<AuditLogFilters>({});

  const { data, isLoading } = useQuery({
    queryKey: ['admin', 'audit-logs', page, pageSize, filters],
    queryFn: async () => {
      const params = {
        page,
        limit: pageSize,
        ...filters,
      };
      const response = await axiosClient.get(API_ENDPOINTS.ADMIN.AUDIT_LOGS, { params });
      return response.data;
    }
  });

  const onFilter = (values: FilterFormValues) => {
    const newFilters: AuditLogFilters = {};
    if (values.action_type) newFilters.action_type = values.action_type;
    if (values.target_entity) newFilters.target_entity = values.target_entity;
    if (values.target_id) newFilters.target_id = values.target_id;
    if (values.date_range && values.date_range[0] && values.date_range[1]) {
      newFilters.from_date = values.date_range[0].toISOString();
      newFilters.to_date = values.date_range[1].toISOString();
    }
    setFilters(newFilters);
    setPage(1);
  };

  const columns = [
    { 
      title: 'Admin', 
      dataIndex: 'admin_name', 
      key: 'admin_name',
      render: (name: string, record: AuditLogEntry) => (
        <Space direction="vertical" size={0}>
          <Text strong>{name}</Text>
          <Text type="secondary" style={{ fontSize: '11px' }}>{record.admin_email}</Text>
        </Space>
      )
    },
    { 
      title: 'Action', 
      dataIndex: 'action_type', 
      key: 'action_type',
      render: (type: string) => (
        <Tag color={type.includes('REJECT') || type.includes('SUSPEND') ? 'error' : 'blue'}>
          {type}
        </Tag>
      )
    },
    { title: 'Entity', dataIndex: 'target_entity', key: 'target_entity' },
    { title: 'ID', dataIndex: 'target_id', key: 'target_id' },
    { 
      title: 'Details', 
      dataIndex: 'metadata', 
      key: 'metadata',
      render: (meta: Record<string, unknown>) => (
        <pre style={{ fontSize: '10px', maxHeight: '60px', overflow: 'auto' }}>
          {JSON.stringify(meta, null, 2)}
        </pre>
      )
    },
    { title: 'IP', dataIndex: 'ip_address', key: 'ip_address', render: (ip: string) => <Text code>{ip || 'N/A'}</Text> },
    { 
      title: 'Date', 
      dataIndex: 'created_at', 
      key: 'created_at', 
      render: (d: string) => dayjs(d).format('MMM D, YYYY HH:mm:ss') 
    },
  ];

  return (
    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
      <Form 
        form={form} 
        layout="inline" 
        onFinish={onFilter}
        style={{ background: '#f5f5f5', padding: '16px', borderRadius: '8px' }}
      >
        <Form.Item name="action_type" label="Action">
          <Input placeholder="e.g. APPROVE_DONATION" allowClear />
        </Form.Item>
        <Form.Item name="target_entity" label="Entity">
          <Select 
            placeholder="Select Entity" 
            allowClear 
            style={{ width: 150 }}
            options={[
              { value: 'donations', label: 'Donations' },
              { value: 'withdrawals', label: 'Withdrawals' },
              { value: 'users', label: 'Users' },
              { value: 'campaigns', label: 'Campaigns' },
              { value: 'deliveries', label: 'Deliveries' },
            ]}
          />
        </Form.Item>
        <Form.Item name="date_range" label="Date Range">
          <RangePicker showTime />
        </Form.Item>
        <Form.Item>
          <Button type="primary" htmlType="submit">Filter</Button>
          <Button onClick={() => { form.resetFields(); onFilter({}); }} style={{ marginLeft: 8 }}>Reset</Button>
        </Form.Item>
      </Form>

      <Table 
        columns={columns} 
        dataSource={data?.data || []} 
        rowKey="id" 
        loading={isLoading} 
        size="small"
        pagination={{
          current: page,
          pageSize: pageSize,
          total: data?.meta?.total || 0,
          onChange: (p, s) => { setPage(p); setPageSize(s); }
        }}
      />
    </Space>
  );
};

export default AuditLogsTable;
