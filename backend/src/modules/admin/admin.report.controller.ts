import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth.js';
import { adminService } from './admin.service.js';

export class AdminReportController {
  private convertToCSV(data: any[]) {
    if (data.length === 0) return '';
    const headers = Object.keys(data[0]).join(',');
    const rows = data.map(row => 
      Object.values(row).map(val => {
        if (typeof val === 'string') return `"${val.replace(/"/g, '""')}"`;
        return val;
      }).join(',')
    );
    return [headers, ...rows].join('\n');
  }

  async exportDonations(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { items } = await adminService.getAllDonations('ALL', { limit: 10000 });
      const csv = this.convertToCSV(items);
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=donations_report.csv');
      res.status(200).send(csv);
    } catch (err) {
      next(err);
    }
  }

  async exportWithdrawals(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { items } = await adminService.getAllWithdrawals('ALL', { limit: 10000 });
      const csv = this.convertToCSV(items);
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=withdrawals_report.csv');
      res.status(200).send(csv);
    } catch (err) {
      next(err);
    }
  }

  async exportCampaigns(_req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { items } = await adminService.getAllCampaigns({ limit: 10000 });
      const csv = this.convertToCSV(items);
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=campaigns_report.csv');
      res.status(200).send(csv);
    } catch (err) {
      next(err);
    }
  }
}

export const adminReportController = new AdminReportController();
