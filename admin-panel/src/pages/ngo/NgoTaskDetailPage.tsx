import React from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Row, Col, Typography, Tag, Timeline, Divider, Spin, Alert, Button, Space, Descriptions, List, Avatar } from 'antd';
import { 
  ArrowLeftOutlined, 
  EnvironmentOutlined, 
  UserOutlined, 
  HistoryOutlined
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import axiosClient from '../../api/axiosClient';
import dayjs from 'dayjs';
import { safeFormatCurrency } from '../../utils/apiNormalizer';

const { Title, Text, Paragraph } = Typography;

const NgoTaskDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const { data: task, isLoading, error } = useQuery({
    queryKey: ['ngo', 'task', id],
    queryFn: async () => {
      const response = await axiosClient.get(`/api/tasks/${id}`);
      return response.data;
    }
  });

  const { data: events } = useQuery({
    queryKey: ['ngo', 'task', id, 'events'],
    queryFn: async () => {
      const response = await axiosClient.get(`/api/tasks/${id}/events`);
      return response.data.data;
    }
  });

  const { data: deliveries } = useQuery({
    queryKey: ['ngo', 'task', id, 'deliveries'],
    queryFn: async () => {
      const response = await axiosClient.get(`/api/deliveries/task/${id}`);
      return response.data.data;
    }
  });

  if (isLoading) return <div style={{ textAlign: 'center', padding: '100px' }}><Spin size="large" /></div>;
  if (error) return <Alert message="Error" description="Could not load task details." type="error" showIcon />;

  const getStatusColor = (s: string) => {
    const colors: any = { OPEN: 'blue', CLAIMED: 'cyan', IN_PROGRESS: 'orange', SUBMITTED: 'purple', VERIFIED: 'green', PAID: 'green', CANCELLED: 'red' };
    return colors[s] || 'default';
  };

  return (
    <div style={{ padding: '0 0 24px 0' }}>
      <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)} style={{ marginBottom: 16 }}>
        Back
      </Button>

      <Row gutter={24}>
        <Col span={16}>
          <Card 
            title={
              <Space>
                <Title level={4} style={{ margin: 0 }}>{task.title}</Title>
                <Tag color={getStatusColor(task.status)}>{task.status}</Tag>
              </Space>
            }
          >
            <Paragraph style={{ fontSize: '16px' }}>{task.description}</Paragraph>
            
            <Divider orientation={"left" as any}>Operational Info</Divider>
            <Descriptions column={2} bordered size="small">
              <Descriptions.Item label="Urgency">
                <Tag color={task.urgency === 'CRITICAL' ? 'red' : 'gold'}>{task.urgency}</Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Category">{task.category}</Descriptions.Item>
              <Descriptions.Item label="Family Size">{task.family_size}</Descriptions.Item>
              <Descriptions.Item label="Budget">{safeFormatCurrency(task.budget_pkr)}</Descriptions.Item>
              <Descriptions.Item label="Location" span={2}>
                <EnvironmentOutlined /> {task.location_text || 'GPS Coordinates Provided'}
                <br/>
                <Text type="secondary" style={{ fontSize: '11px' }}>({task.latitude}, {task.longitude})</Text>
              </Descriptions.Item>
            </Descriptions>

            <Divider orientation={"left" as any}>Required Items</Divider>
            <List
              size="small"
              dataSource={task.items_needed}
              renderItem={(item: any) => (
                <List.Item>
                  <Text strong>{item.item}</Text> — {item.quantity}
                </List.Item>
              )}
            />
          </Card>

          {deliveries && deliveries.length > 0 && (
            <Card title="Execution Proof (Delivery)" style={{ marginTop: 24 }}>
              {deliveries.map((d: any) => (
                <div key={d.id}>
                  <Space direction="vertical" style={{ width: '100%' }}>
                    <div style={{ display: 'flex', gap: 12, overflowX: 'auto', padding: '8px 0' }}>
                      {d.photo_urls.map((url: string, i: number) => (
                        <img key={i} src={url} alt="Proof" style={{ height: 120, borderRadius: 8 }} />
                      ))}
                    </div>
                    <Paragraph><strong>Notes:</strong> {d.notes || 'No notes provided'}</Paragraph>
                    <Space split={<Divider type="vertical" />}>
                      <Text type="secondary">Submitted by: {d.volunteer_name}</Text>
                      <Text type="secondary">At: {dayjs(d.submitted_at).format('MMM D, HH:mm')}</Text>
                    </Space>
                  </Space>
                  <Divider />
                </div>
              ))}
            </Card>
          )}
        </Col>

        <Col span={8}>
          <Card title={<span><UserOutlined /> Stakeholders</span>}>
            <Space direction="vertical" style={{ width: '100%' }}>
              <div>
                <Text type="secondary">Beneficiary</Text><br/>
                <Text strong>{task.beneficiary_id ? `User #${task.beneficiary_id}` : 'Anonymous Request'}</Text>
              </div>
              <Divider style={{ margin: '8px 0' }} />
              <div>
                <Text type="secondary">Volunteer</Text><br/>
                {task.claimed_by_name ? (
                  <Space>
                    <Avatar size="small" icon={<UserOutlined />} />
                    <Text strong>{task.claimed_by_name}</Text>
                  </Space>
                ) : <Text type="secondary">Awaiting claim...</Text>}
              </div>
              <Divider style={{ margin: '8px 0' }} />
              <div>
                <Text type="secondary">Linked Campaign</Text><br/>
                <Text strong>{task.campaign_id ? `Campaign #${task.campaign_id}` : 'None'}</Text>
              </div>
            </Space>
          </Card>

          <Card title={<span><HistoryOutlined /> Task Timeline</span>} style={{ marginTop: 24 }}>
            <Timeline
              items={events?.map((e: any) => ({
                children: (
                  <Space direction="vertical" size={0}>
                    <Text strong style={{ fontSize: '12px' }}>{e.event_type}</Text>
                    <Text type="secondary" style={{ fontSize: '11px' }}>{dayjs(e.created_at).format('MMM D, HH:mm')}</Text>
                  </Space>
                ),
                color: e.event_type === 'VERIFIED' ? 'green' : 'blue',
              }))}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default NgoTaskDetailPage;
