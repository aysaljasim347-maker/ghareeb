import React from 'react';
import { Form, Input, InputNumber, Button, Select, Card, Alert } from 'antd';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../../api/axiosClient';
import { API_ENDPOINTS } from '../../../api/endpoints';

const { TextArea } = Input;

interface TaskFormProps {
  initialValues?: Record<string, unknown>;
  onFinish: (values: Record<string, unknown>) => void;
  loading?: boolean;
  submitText?: string;
  isConversion?: boolean;
}

const TaskForm: React.FC<TaskFormProps> = ({ 
  initialValues, 
  onFinish, 
  loading, 
  submitText = 'Submit',
  isConversion = false
}) => {
  const [form] = Form.useForm();

  // Fetch campaigns for the dropdown
  const { data: campaigns } = useQuery({
    queryKey: ['ngo', 'campaigns'],
    queryFn: async () => {
      const response = await axiosClient.get(API_ENDPOINTS.NGO.CAMPAIGNS);
      return response.data.data as Array<{ id: number, title: string }>;
    }
  });

  return (
    <Card bordered={false} style={{ maxWidth: 800, margin: '0 auto' }}>
      {isConversion && (
        <Alert 
          message="Beneficiary Request Conversion" 
          description="You are converting a direct request into a structured relief task. The beneficiary will be automatically linked."
          type="info"
          showIcon
          style={{ marginBottom: 24 }}
        />
      )}
      <Form
        form={form}
        layout="vertical"
        initialValues={initialValues}
        onFinish={onFinish}
        scrollToFirstError
      >
        <Form.Item
          name="title"
          label="Task Title"
          rules={[{ required: true, message: 'Please enter a title' }]}
        >
          <Input placeholder="e.g., Deliver Food Packs to District A" maxLength={255} />
        </Form.Item>

        <Form.Item
          name="description"
          label="Description"
          rules={[{ required: true, message: 'Please provide details' }]}
        >
          <TextArea rows={4} placeholder="What needs to be done? List any specific constraints." />
        </Form.Item>

        <Form.Item name="campaign_id" label="Link to Campaign (Optional)">
          <Select 
            placeholder="Select a campaign" 
            allowClear
            options={campaigns?.map((c) => ({ value: c.id, label: c.title }))}
          />
        </Form.Item>

        <div style={{ display: 'flex', gap: 16 }}>
          <Form.Item 
            name="category" 
            label="Category" 
            style={{ flex: 1 }}
            rules={[{ required: true }]}
          >
            <Select placeholder="Select category">
              <Select.Option value="FOOD">Food & Water</Select.Option>
              <Select.Option value="MEDICAL">Medical Supplies</Select.Option>
              <Select.Option value="SHELTER">Shelter</Select.Option>
              <Select.Option value="CLOTHING">Clothing</Select.Option>
              <Select.Option value="OTHER">Other</Select.Option>
            </Select>
          </Form.Item>

          <Form.Item 
            name="urgency" 
            label="Urgency" 
            style={{ flex: 1 }}
            initialValue="MEDIUM"
          >
            <Select>
              <Select.Option value="LOW">Low</Select.Option>
              <Select.Option value="MEDIUM">Medium</Select.Option>
              <Select.Option value="HIGH">High</Select.Option>
              <Select.Option value="CRITICAL">Critical</Select.Option>
            </Select>
          </Form.Item>
        </div>

        <div style={{ display: 'flex', gap: 16 }}>
          <Form.Item name="latitude" label="Latitude" style={{ flex: 1 }} rules={[{ required: true }]}>
            <InputNumber placeholder="24.8607" style={{ width: '100%' }} precision={6} />
          </Form.Item>
          <Form.Item name="longitude" label="Longitude" style={{ flex: 1 }} rules={[{ required: true }]}>
            <InputNumber placeholder="67.0011" style={{ width: '100%' }} precision={6} />
          </Form.Item>
        </div>

        <Form.Item name="location_text" label="Location Details (Optional)">
          <Input placeholder="e.g. Near the blue water tank" />
        </Form.Item>

        <Form.Item name="budget_pkr" label="Budget (PKR) - Optional" initialValue={0}>
          <InputNumber style={{ width: '100%' }} min={0} />
        </Form.Item>

        <Form.Item hidden name="beneficiary_id"><Input /></Form.Item>
        <Form.Item hidden name="source_type" initialValue="NGO_CAMPAIGN"><Input /></Form.Item>

        <Form.Item style={{ marginTop: 24 }}>
          <Button type="primary" htmlType="submit" size="large" block loading={loading}>
            {submitText}
          </Button>
        </Form.Item>
      </Form>
    </Card>
  );
};

export default TaskForm;
