import { Router } from 'express';
import { adminController } from './admin.controller.js';
import { adminSnapshotController } from './admin.snapshot.controller.js';
import { adminSystemController } from './admin.system.controller.js';
import { adminReportController } from './admin.report.controller.js';
import { authenticate } from '../../middleware/auth.js';
import { authorize } from '../../middleware/authorize.js';

const router = Router();

router.use(authenticate);
router.use(authorize('ADMIN'));

router.get('/donations/stats', (req, res, next) => adminController.getDonationStats(req, res, next));
router.get('/donations', (req, res, next) => adminController.listDonations(req, res, next));

router.get('/withdrawals/stats', (req, res, next) => adminController.getWithdrawalStats(req, res, next));
router.get('/withdrawals', (req, res, next) => adminController.listWithdrawals(req, res, next));

router.get('/campaigns/stats', (req, res, next) => adminController.getCampaignStats(req, res, next));
router.get('/campaigns', (req, res, next) => adminController.listCampaigns(req, res, next));

router.get('/users/stats', (req, res, next) => adminController.getUserStats(req, res, next));
router.get('/users', (req, res, next) => adminController.listUsers(req, res, next));

router.get('/audit-logs', (req, res, next) => adminController.getAuditLogs(req, res, next));
router.get('/ledger', (req, res, next) => adminController.getLedger(req, res, next));

router.get('/ngos/:id', (req, res, next) => adminController.getNgoDetail(req, res, next));
router.get('/donations/:id/full', (req, res, next) => adminController.getDonationTrace(req, res, next));

// --- Bulk Operations ---
router.post('/ngos/bulk-verify', (req, res, next) => adminController.bulkVerifyNgo(req, res, next));
router.post('/donations/bulk-action', (req, res, next) => adminController.bulkDonationAction(req, res, next));
router.post('/users/bulk-status', (req, res, next) => adminController.bulkUserStatus(req, res, next));
router.post('/campaigns/bulk-status', (req, res, next) => adminController.bulkCampaignStatus(req, res, next));

// --- NGO Verification ---
router.get('/ngos/pending', (req, res, next) => adminController.listPendingNgos(req, res, next));
router.post('/ngos/:id/verify', (req, res, next) => adminController.verifyNgo(req, res, next));
router.post('/ngos/:id/reject', (req, res, next) => adminController.rejectNgo(req, res, next));

// --- Financial Safety ---
router.post('/donations/:id/flag', (req, res, next) => adminController.flagDonation(req, res, next));
router.post('/withdrawals/:id/flag', (req, res, next) => adminController.flagWithdrawal(req, res, next));

// --- Reports ---
router.get('/reports/donations.csv', (req, res, next) => adminReportController.exportDonations(req, res, next));
router.get('/reports/withdrawals.csv', (req, res, next) => adminReportController.exportWithdrawals(req, res, next));
router.get('/reports/campaigns.csv', (req, res, next) => adminReportController.exportCampaigns(req, res, next));

router.get('/snapshot', (req, res, next) => adminSnapshotController.getSystemSnapshot(req, res, next));
router.get('/operational', (req, res, next) => adminSnapshotController.getOperationalOverview(req, res, next));

router.get('/system/state', (req, res, next) => adminSystemController.getSystemState(req, res, next));
router.post('/system/state', (req, res, next) => adminSystemController.setSystemState(req, res, next));

export default router;
