import React from 'react';
import { Typography, notification, Button } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useNavigate, useLocation } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import TaskForm from './components/TaskForm';

const { Title, Text } = Typography;

const NgoTaskCreatePage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();

  // If redirected from conversion, initial values will be in location.state
  const prefilledValues = location.state?.prefilled;

  const createMutation = useMutation({
    mutationFn: async (values: unknown) => {
      return axiosClient.post('/tasks', values);
    },
    onSuccess: () => {
      notification.success({
        message: 'Task Created',
        description: 'New relief task is now OPEN and visible to volunteers.',
      });
      queryClient.invalidateQueries({ queryKey: ['ngo', 'tasks'] });
      navigate('/ngo/tasks');
    },
    onError: (error: unknown) => {
      const err = error as { response?: { data?: { error?: string } } };
      notification.error({
        message: 'Creation Failed',
        description: err.response?.data?.error || 'Could not create task.',
      });
    }
  });

  return (
    <div style={{ padding: '0 0 24px 0' }}>
      <Button 
        icon={<ArrowLeftOutlined />} 
        onClick={() => navigate(-1)} 
        style={{ marginBottom: 16 }}
      >
        Back
      </Button>
      
      <div style={{ marginBottom: 32 }}>
        <Title level={2}>Deploy Relief Task</Title>
        <Text type="secondary">Define a new operational task for volunteers to claim and fulfill.</Text>
      </div>

      <TaskForm 
        initialValues={prefilledValues}
        isConversion={!!prefilledValues?.beneficiary_id}
        onFinish={(v) => createMutation.mutate(v)} 
        loading={createMutation.isPending}
        submitText="Dispatch Task"
      />
    </div>
  );
};

export default NgoTaskCreatePage;
