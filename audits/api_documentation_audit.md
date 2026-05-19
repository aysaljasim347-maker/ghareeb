# 📡 API Documentation Audit: DisasterAid V2.1
To resume this session: gemini --resume '10b11462-973e-4207-a13d-179a32a72f3e'    
**Auditor:** Senior API Architect & Technical Auditor
**Date:** May 13, 2026
**Status:** 🔴 CRITICAL GAPS IDENTIFIED

---

## 🔴 Critical Documentation Gaps

### 1. Incomplete API Coverage (Outdated `API_CONTRACT.md`)
*   **Problem:** The primary documentation file `API_CONTRACT.md` covers less than 40% of the actual system.
*   **Missing Modules:** Campaigns, Chat, specific Donation management, and Task Event timeline are entirely undocumented.
*   **Impact:** New frontend developers cannot build these features without reading backend source code.
*   **Risk Level:** HIGH. Leads to "tribal knowledge" and slow onboarding.

### 2. Zero Automated Documentation (No Swagger/OpenAPI)
*   **Problem:** There is no interactive documentation (Swagger UI) or machine-readable spec (OpenAPI).
*   **Impact:** No way to auto-generate Flutter models or test endpoints in an isolated sandbox.
*   **Risk Level:** HIGH. Increases the likelihood of contract breakage between Backend and Flutter.

### 3. Documentation-Implementation Mismatch (PostGIS)
*   **Problem:** `API_CONTRACT.md` describes `/api/tasks/available` as taking `lat`, `lng`, and `radius`. The actual code in `tasks.routes.ts` explicitly states it returns *all* tasks without filtering.
*   **Impact:** Flutter app may be sending coordinates that the backend silently ignores, leading to performance issues (over-fetching).
*   **Risk Level:** CRITICAL. Directly impacts the core "nearby aid" feature logic.

---

## 🟠 Medium Documentation Issues

### 1. Vague Schema Definitions
*   **Description:** Docs use terms like `UserProfile` and `Task` without defining the fields.
*   **Actual State:** Backend uses rigorous Zod schemas (e.g., `tasks.schema.ts`), but these "Single Source of Truth" definitions are not exposed to the frontend.

### 2. Missing Error Contract
*   **Description:** The error format (Standard JSON vs Validation Details) is consistent in code (`validate.ts`) but never documented.
*   **Impact:** Frontend developers must guess how to parse error messages for form validation.

### 3. Undocumented Role-Based Access Control (RBAC)
*   **Description:** Many routes have complex `authorize(['NGO', 'COORDINATOR'])` requirements that are not reflected in the `API_CONTRACT.md`.

---

## 🟢 Minor Issues

### 1. Inconsistent Naming
*   **Description:** Some routes use singular (`/donations/:id/confirm`) while others imply collections.
*   **Improvement:** Standardize on RESTful pluralization across all documentation and routes.

---

## ⚠️ High-Risk Undocumented Areas

### 1. Chat Socket.IO Events
*   **Risk:** The real-time layer (`chat.gateway.ts`) is completely undocumented. Events like `join_room`, `send_message`, and `receive_message` are "invisible" to anyone not reading the TypeScript gateway file.

### 2. Donation Payment Lifecycle
*   **Risk:** The transition from `PENDING` to `COMPLETED` and the required `gateway_ref` are not clearly explained, which could lead to inconsistent financial data.

---

## 🧠 Swagger/OpenAPI Status Summary

*   **Current State:** NON-EXISTENT.
*   **Completeness Score:** 0/100.
*   **Alignment with Backend:** POOR (Outdated `API_CONTRACT.md`).

---

## 🛠 Developer Experience Impact

*   **Onboarding:** A new developer will fail to implement Campaigns or Chat without a "guided tour" of the code.
*   **Tooling:** No support for Postman collection generation or automated testing tools.
*   **Stability:** High risk of breaking the frontend with minor backend schema changes because the contract is "implied" rather than "enforced".

---

## 🧪 Recommendations

1.  **Immediate:** Install `swagger-jsdoc` and `swagger-ui-express`.
2.  **Short-term:** Annotate existing Express routes with JSDoc to generate an OpenAPI 3.0 spec.
3.  **Process:** Replace `API_CONTRACT.md` with a live `/api-docs` endpoint that stays in sync with Zod schemas.
