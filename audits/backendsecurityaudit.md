# Backend Security Audit - DisasterAid V2.1 (Post-Remediation)
**Date:** 2026-05-12
**Auditor:** Senior Backend Security Auditor
**Status:** All previous 🔴 Critical issues have been **RESOLVED**. This report identifies remaining second-order risks.

## 🔴 Critical Vulnerabilities
*None identified.* All critical IDOR and state-machine bypass vulnerabilities identified in the previous audit have been successfully patched.

## 🟠 Medium Risks

### 1. Insecure Direct Object Reference (IDOR) in Task & Campaign Updates
**Location:** 
- `backend/src/modules/tasks/tasks.service.ts` (`updateTask`)
- `backend/src/modules/campaigns/campaigns.service.ts` (`update`)

**Issue:** 
The update logic for both tasks and campaigns verifies the user's *role* (via middleware) but fails to verify *ownership* or *jurisdiction* at the service layer. Currently, any user with the `NGO` or `COORDINATOR` role can send a `PATCH` request to update any task or campaign in the database by guessing its ID.

**Exploit Scenario:** 
A legitimate NGO account (NGO_A) can modify the `title`, `description`, or `budget_pkr` of a campaign belonging to NGO_B, potentially sabotaging their relief efforts or misdirecting resources.

**Fix:**
Pass the `req.user.id` to the service and enforce an ownership check:
```typescript
// In campaigns.service.ts
async update(id: number, input: UpdateCampaignInput, requesterId: number, requesterRole: string) {
  const check = await pool.query('SELECT created_by FROM campaigns WHERE id = $1', [id]);
  if (requesterRole !== 'ADMIN' && check.rows[0].created_by !== requesterId) {
     throw createError('Forbidden: You do not own this campaign', 403);
  }
  // ... proceed with update
}
```

### 2. IDOR in Donation Confirmation
**Location:** `backend/src/modules/donations/donations.service.ts` (`confirmDonation`)

**Issue:** 
Similar to delivery verification, any user with the `COORDINATOR` role can trigger the `confirmDonation` endpoint for any donation ID. There is no check to ensure the coordinator belongs to the NGO that owns the target campaign.

**Exploit Scenario:** 
A malicious coordinator could manually "confirm" their own pending donations (without actual payment) for campaigns they don't manage, artificially inflating raised amounts and ledger entries.

**Fix:**
Validate that the coordinator has jurisdiction over the campaign associated with the donation.

## 🟢 Minor Issues

1. **Information Disclosure in 404:** (Persistent) The global 404 handler returns `{"error": "Route not found"}`. 
2. **Unused Cloudinary Configuration:** While the utility file was deleted, the environment variables and Zod schema in `env.ts` still exist. This is minor technical debt but reduces attack surface if cleaned.

## ✅ Secure Practices Observed (Recently Fixed)

*   **FIXED: IDOR in Chat:** REST and Socket.IO layers now strictly verify that only task participants (creator, claimant, coordinator) can access private messages.
*   **FIXED: State Machine Integrity:** The `status` field is no longer editable via the general `PATCH /api/tasks/:id` route, preventing manual bypasses of the verification workflow.
*   **FIXED: Delivery Jurisdiction:** Coordinators are now restricted to verifying deliveries only for tasks they explicitly manage.
*   **FIXED: DoS Hardening:** Unbounded JSON arrays in the task schema now have strict `.max(100)` limits and string length caps.
*   **SQL Injection Defenses:** Parameterized queries remain consistently used across all modules.
*   **Secure Auth Middleware:** Role validation still occurs against the database on every request, successfully preventing privilege escalation via stale tokens.
