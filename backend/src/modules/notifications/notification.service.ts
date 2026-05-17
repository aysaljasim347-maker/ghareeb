import { emitToUser } from '../chat/chat.gateway.js';

export interface NotificationPayload {
  type: string;
  taskId: number;
  title: string;
  message: string;
  timestamp: string;
}

/**
 * Service to handle system notifications via Socket.IO.
 */
export class NotificationService {
  /**
   * Notify a beneficiary about a task status update.
   */
  notifyTaskUpdate(beneficiaryId: number, taskId: number, taskTitle: string, status: string) {
    const payload: NotificationPayload = {
      type: 'TASK_STATUS_UPDATE',
      taskId,
      title: 'Task Update',
      message: `Your request "${taskTitle}" is now ${status.toLowerCase().replace('_', ' ')}.`,
      timestamp: new Date().toISOString(),
    };
    emitToUser(beneficiaryId, 'notification', payload);
  }

  /**
   * Notify a beneficiary when their task is claimed by a volunteer.
   */
  notifyTaskClaimed(beneficiaryId: number, taskId: number, taskTitle: string, volunteerName: string) {
    const payload: NotificationPayload = {
      type: 'TASK_CLAIMED',
      taskId,
      title: 'Helper Found',
      message: `${volunteerName} has claimed your request "${taskTitle}".`,
      timestamp: new Date().toISOString(),
    };
    emitToUser(beneficiaryId, 'notification', payload);
  }

  /**
   * Notify a beneficiary when a delivery is submitted.
   */
  notifyDeliverySubmitted(beneficiaryId: number, taskId: number, taskTitle: string) {
    const payload: NotificationPayload = {
      type: 'DELIVERY_SUBMITTED',
      taskId,
      title: 'Aid Delivered',
      message: `Items for "${taskTitle}" have been delivered. Please confirm receipt.`,
      timestamp: new Date().toISOString(),
    };
    emitToUser(beneficiaryId, 'notification', payload);
  }

  /**
   * Notify a coordinator about a critical update in their scope.
   */
  notifyCoordinatorTaskUpdate(coordinatorId: number, taskId: number, taskTitle: string, event: string) {
    const payload: NotificationPayload = {
      type: 'TASK_STATUS_UPDATE',
      taskId,
      title: 'Field Update',
      message: `Task "${taskTitle}" is now ${event.toLowerCase().replace('_', ' ')}.`,
      timestamp: new Date().toISOString(),
    };
    emitToUser(coordinatorId, 'notification', payload);
  }

  /**
   * Notify admin about an emergency escalation.
   */
  notifyAdminEmergency(adminId: number, targetId: number, reason: string) {
    const payload: NotificationPayload = {
      type: 'EMERGENCY_ESCALATION',
      taskId: targetId,
      title: 'EMERGENCY ALERT',
      message: `Critical escalation: ${reason}`,
      timestamp: new Date().toISOString(),
    };
    emitToUser(adminId, 'notification', payload);
  }
}

export const notificationService = new NotificationService();
