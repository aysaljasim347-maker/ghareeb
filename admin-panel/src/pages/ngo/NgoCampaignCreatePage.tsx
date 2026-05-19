import React, { useState } from 'react';
import {
  Typography,
  notification,
  Button,
  Segmented,
  Form,
  Input,
  InputNumber,
  DatePicker,
  Select,
  Card,
  Row,
  Col,
} from 'antd';
import { ArrowLeftOutlined, DollarOutlined, InboxOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import { API_ENDPOINTS } from '../../api/endpoints';
import CampaignForm from './components/CampaignForm';
import dayjs from 'dayjs';

const { Title, Text } = Typography;
const { TextArea } = Input;

const GOODS_CATEGORIES = [
  'Food', 'Water', 'Medicines', 'Clothes', 'Shelter', 'Hygiene',
  'Education', 'Electronics', 'Tools', 'Other',
];

const GoodsCampaignForm: React.FC<{ onFinish: (v: unknown) => void; loading: boolean }> = ({
  onFinish,
  loading,
}) => {
  const [form] = Form.useForm();
  const [category, setCategory] = useState('');

  const handleSubmit = (values: unknown) => {
    const v = values as Record<string, unknown>;
    const payload = {
      ...v,
      deadline: dayjs(v.deadline as string).format('YYYY-MM-DD'),
      target_qty: Number(v.target_qty),
      latitude: v.latitude ? Number(v.latitude) : undefined,
      longitude: v.longitude ? Number(v.longitude) : undefined,
    };
    onFinish(payload);
  };

  return (
    <Card variant="outlined" style={{ maxWidth: 780 }}>
      <Form form={form} layout="vertical" onFinish={handleSubmit}>
        <Form.Item label="Campaign Title" name="title" rules={[{ required: true, min: 3 }]}>
          <Input placeholder="e.g. Winter Blanket Drive — Tharparkar" />
        </Form.Item>

        <Row gutter={16}>
          <Col span={12}>
            <Form.Item label="Item Needed" name="item_needed" rules={[{ required: true }]}>
              <Input placeholder="e.g. Blankets" />
            </Form.Item>
          </Col>
          <Col span={12}>
            <Form.Item label="Category" name="category" rules={[{ required: true }]}>
              <Select
                placeholder="Select category"
                options={GOODS_CATEGORIES.map((c) => ({ value: c, label: c }))}
                onChange={setCategory}
              />
            </Form.Item>
          </Col>
        </Row>

        {category === 'Other' && (
          <Form.Item label="Category (custom)" name="category_other" rules={[{ required: true }]}>
            <Input placeholder="Describe the category" />
          </Form.Item>
        )}

        <Row gutter={16}>
          <Col span={8}>
            <Form.Item label="Target Quantity" name="target_qty" rules={[{ required: true }]}>
              <InputNumber min={1} style={{ width: '100%' }} placeholder="500" />
            </Form.Item>
          </Col>
          <Col span={8}>
            <Form.Item label="Unit" name="unit" rules={[{ required: true }]}>
              <Input placeholder="pcs / kg / boxes" />
            </Form.Item>
          </Col>
          <Col span={8}>
            <Form.Item label="Deadline" name="deadline" rules={[{ required: true }]}>
              <DatePicker style={{ width: '100%' }} disabledDate={(d) => d.isBefore(dayjs())} />
            </Form.Item>
          </Col>
        </Row>

        <Form.Item label="Description" name="description" rules={[{ required: true, min: 10 }]}>
          <TextArea rows={4} placeholder="Describe why these items are needed and who will benefit…" />
        </Form.Item>

        <Form.Item label="Pickup / Drop-off Location" name="location_text" rules={[{ required: true }]}>
          <Input placeholder="e.g. Tharparkar District, Sindh" />
        </Form.Item>

        <Row gutter={16}>
          <Col span={12}>
            <Form.Item label="Latitude (optional)" name="latitude">
              <InputNumber style={{ width: '100%' }} placeholder="24.7136" step={0.0001} />
            </Form.Item>
          </Col>
          <Col span={12}>
            <Form.Item label="Longitude (optional)" name="longitude">
              <InputNumber style={{ width: '100%' }} placeholder="69.5674" step={0.0001} />
            </Form.Item>
          </Col>
        </Row>

        <Form.Item label="Cover Image URL (optional)" name="cover_image_url">
          <Input placeholder="https://…" />
        </Form.Item>

        <Button type="primary" htmlType="submit" loading={loading} size="large">
          Create Goods Campaign
        </Button>
      </Form>
    </Card>
  );
};

const NgoCampaignCreatePage: React.FC = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [campaignType, setCampaignType] = useState<'money' | 'goods'>('money');

  const createMutation = useMutation({
    mutationFn: async (values: unknown) => {
      return axiosClient.post(API_ENDPOINTS.CAMPAIGNS.CREATE, values);
    },
    onSuccess: () => {
      notification.success({
        message: 'Campaign Created',
        description: 'Your campaign has been created as a DRAFT. You can activate it from the list view.',
      });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'campaigns'] });
      navigate('/ngo/campaigns');
    },
    onError: (error: unknown) => {
      const err = error as { response?: { data?: { error?: string } } };
      notification.error({
        message: 'Creation Failed',
        description: err.response?.data?.error || 'Could not create campaign.',
      });
    },
  });

  const createGoodsMutation = useMutation({
    mutationFn: async (values: unknown) => {
      return axiosClient.post(API_ENDPOINTS.GOODS_CAMPAIGNS.CREATE, values);
    },
    onSuccess: () => {
      notification.success({
        message: 'Goods Campaign Created',
        description: 'Your goods campaign has been created as a DRAFT. You can activate it from the list view.',
      });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'goods-campaigns'] });
      navigate('/ngo/campaigns');
    },
    onError: (error: unknown) => {
      const err = error as { response?: { data?: { error?: string } } };
      notification.error({
        message: 'Creation Failed',
        description: err.response?.data?.error || 'Could not create goods campaign.',
      });
    },
  });

  return (
    <div style={{ padding: '0 0 24px 0' }}>
      <Button
        icon={<ArrowLeftOutlined />}
        onClick={() => navigate('/ngo/campaigns')}
        style={{ marginBottom: 16 }}
      >
        Back to Campaigns
      </Button>

      <div style={{ marginBottom: 24 }}>
        <Title level={2}>Launch New Campaign</Title>
        <Text type="secondary">Choose the campaign type and fill in the details below.</Text>
      </div>

      <Segmented
        value={campaignType}
        onChange={(v) => setCampaignType(v as 'money' | 'goods')}
        options={[
          { label: 'Money Campaign', value: 'money', icon: <DollarOutlined /> },
          { label: 'Goods Campaign (In-Kind)', value: 'goods', icon: <InboxOutlined /> },
        ]}
        style={{ marginBottom: 32, fontSize: 15 }}
        size="large"
      />

      {campaignType === 'money' ? (
        <CampaignForm
          onFinish={(v) => createMutation.mutate(v)}
          loading={createMutation.isPending}
          submitText="Create Campaign"
        />
      ) : (
        <GoodsCampaignForm
          onFinish={(v) => createGoodsMutation.mutate(v)}
          loading={createGoodsMutation.isPending}
        />
      )}
    </div>
  );
};

export default NgoCampaignCreatePage;
