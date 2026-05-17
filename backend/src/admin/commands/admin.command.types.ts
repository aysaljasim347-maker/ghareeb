import { SystemState } from '../../system/state/system.state.js';

export type BaseCommand = {
  actorAdminId: number;
  targetId: number;
  ipAddress?: string;
};

export type ApproveDonationCommand = BaseCommand & {
  type: 'APPROVE_DONATION';
};

export type RejectDonationCommand = BaseCommand & {
  type: 'REJECT_DONATION';
};

export type ApproveWithdrawalCommand = BaseCommand & {
  type: 'APPROVE_WITHDRAWAL';
};

export type RejectWithdrawalCommand = BaseCommand & {
  type: 'REJECT_WITHDRAWAL';
};

export type SuspendUserCommand = BaseCommand & {
  type: 'SUSPEND_USER';
  metadata?: { reason?: string };
};

export type ReactivateUserCommand = BaseCommand & {
  type: 'REACTIVATE_USER';
};

export type UpdateCampaignStatusCommand = BaseCommand & {
  type: 'UPDATE_CAMPAIGN_STATUS';
  metadata: { status: string };
};

export type UpdateTaskCommand = BaseCommand & {
  type: 'UPDATE_TASK';
  metadata: Record<string, unknown>;
};

export type VerifyDeliveryCommand = BaseCommand & {
  type: 'VERIFY_DELIVERY';
  metadata: { 
    verified: boolean; 
    outcome?: 'VERIFY' | 'FLAG' | 'REJECT';
    notes?: string 
  };
};

export type SetSystemStateCommand = BaseCommand & {
  type: 'SET_SYSTEM_STATE';
  targetId: 0;
  metadata: { state: SystemState; reason?: string };
};

export type AdminCommand =
  | ApproveDonationCommand
  | RejectDonationCommand
  | ApproveWithdrawalCommand
  | RejectWithdrawalCommand
  | SuspendUserCommand
  | ReactivateUserCommand
  | UpdateCampaignStatusCommand
  | UpdateTaskCommand
  | VerifyDeliveryCommand
  | SetSystemStateCommand;
