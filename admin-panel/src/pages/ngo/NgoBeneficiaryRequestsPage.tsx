import React from 'react';
import { Table, Typography, Card, Space, Button, Divider, Tooltip } from 'antd';
import { RocketOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';

const { Title, Text } = Typography;

interface BeneficiaryRequest {
  id: number;
  title: string;
  description: string;
  latitude: number;
  longitude: number;
  location_text: string;
  beneficiary_id: number;
  category: string;
  items_needed: string;
  family_size: number;
  created_by_name: string;
  created_at: string;
}

const NgoBeneficiaryRequestsPage: React.FC = () => {
  const navigate = useNavigate();

  const { data, isLoading } = useQuery<BeneficiaryRequest[]>({
    queryKey: ['beneficiary-requests'],
    queryFn: async () => {
      // Filtering for tasks from BENEFICIARY_REQUEST source that are still OPEN
      const response = await axiosClient.get('/tasks/available', {
        params: { source: 'BENEFICIARY_REQUEST' }
      });
      return response.data.data;
    }
  });

  const handleConvert = (request: BeneficiaryRequest) => {
    navigate('/ngo/tasks/new', { 
      state: { 
        prefilled: {
          title: `[Converted] ${request.title}`,
          description: request.description,
          latitude: request.latitude,
          longitude: request.longitude,
          location_text: request.location_text,
          beneficiary_id: request.beneficiary_id,
          source_type: 'BENEFICIARY_REQUEST',
          category: request.category,
          items_needed: request.items_needed,
          family_size: request.family_size,
        }
      } 
    });
  };

  const columns = [
    {
      title: 'Title',
      dataIndex: 'title',
      key: 'title',
      render: (text: string) => <Text strong>{text}</Text>,
    },
    {
      title: 'Requested By',
      dataIndex: 'created_by_name',
      key: 'created_by_name',
    },
    {
      title: 'Location',
      key: 'location',
      render: (_: unknown, record: BeneficiaryRequest) => (
        <Tooltip title={`${record.latitude}, ${record.longitude}`}>
          <Space>
            <EnvironmentOutlined />
            <Text style={{ fontSize: '12px' }}>{record.location_text || 'Coordinates only'}</Text>
          </Space>
        </Tooltip>
      )
    },
    {
      title: 'Submitted',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (d: string) => dayjs(d).format('MMM D, YYYY'),
    },
    {
      title: 'Action',
      key: 'action',
      render: (_: unknown, record: BeneficiaryRequest) => (
        <Button 
          type="primary" 
          icon={<RocketOutlined />} 
          onClick={() => handleConvert(record)}
        >
          Convert to Task
        </Button>
      ),
    },
  ];

  return (
    <Card>
      <Title level={3}>Beneficiary Requests Pipeline</Title>
      <Text type="secondary">
        Direct aid requests from beneficiaries. Convert them into managed tasks to coordinate volunteer fulfillment.
      </Text>
      <Divider />

      <Table 
        columns={columns} 
        dataSource={data} 
        rowKey="id" 
        loading={isLoading}
        pagination={{ pageSize: 10 }}
      />
    </Card>
  );
};

export default NgoBeneficiaryRequestsPage;
