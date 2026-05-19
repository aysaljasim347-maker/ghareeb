import React from 'react';
import { Form, Input, InputNumber, Button, Space, Typography, Card } from 'antd';
import type { Campaign } from '../../../types/campaign';

const { TextArea } = Input;

interface CampaignFormProps {
  initialValues?: Partial<Campaign>;
  onFinish: (values: Partial<Campaign>) => void;
  loading?: boolean;
  submitText?: string;
}

const CampaignForm: React.FC<CampaignFormProps> = ({ 
  initialValues, 
  onFinish, 
  loading, 
  submitText = 'Submit' 
}) => {
  const [form] = Form.useForm();

  return (
    <Card bordered={false} style={{ maxWidth: 800, margin: '0 auto' }}>
      <Form
        form={form}
        layout="vertical"
        initialValues={initialValues}
        onFinish={onFinish}
        scrollToFirstError
      >
        <Form.Item
          name="title"
          label="Campaign Title"
          rules={[{ required: true, message: 'Please enter a campaign title' }]}
        >
          <Input placeholder="e.g., Flood Relief 2026 - Sindh" maxLength={255} />
        </Form.Item>

        <Form.Item
          name="description"
          label="Description"
          rules={[{ required: true, message: 'Please provide a detailed description' }]}
        >
          <TextArea rows={6} placeholder="Describe the mission, targets, and how the funds will be used..." />
        </Form.Item>

        <Form.Item
          name="goal_pkr"
          label="Funding Goal (PKR)"
          rules={[
            { required: true, message: 'Please enter a goal amount' },
            { type: 'number', min: 1000, message: 'Goal must be at least 1,000 PKR' }
          ]}
        >
          <InputNumber
            style={{ width: '100%' }}
            formatter={value => `PKR ${value}`.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}
            parser={value => value!.replace(/PKR\s?|,/g, '')}
            placeholder="e.g., 500000"
          />
        </Form.Item>

        <Typography.Title level={5}>Location (Optional)</Typography.Title>
        <Space direction="horizontal" style={{ width: '100%' }}>
          <Form.Item name="latitude" label="Latitude" style={{ flex: 1 }}>
            <InputNumber placeholder="e.g., 24.8607" style={{ width: '100%' }} precision={6} />
          </Form.Item>
          <Form.Item name="longitude" label="Longitude" style={{ flex: 1 }}>
            <InputNumber placeholder="e.g., 67.0011" style={{ width: '100%' }} precision={6} />
          </Form.Item>
        </Space>

        <Form.Item style={{ marginTop: 24 }}>
          <Button type="primary" htmlType="submit" size="large" block loading={loading}>
            {submitText}
          </Button>
        </Form.Item>
      </Form>
    </Card>
  );
};

export default CampaignForm;
