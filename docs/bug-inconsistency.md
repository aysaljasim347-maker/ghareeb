DisasterAid V2.1 — Bug & Inconsistency Report

---

CONFIRMED ISSUES

---

ISSUE 1 — Wrong Column Name in Admin Campaign Stats Query (Runtime Crash)

File: backend/src/modules/admin/admin.service.ts:36

SUM(target_pkr) as total_target // ← this column does not exist

The campaigns table column is goal_pkr, not target_pkr (confirmed in database/001_init.sql:118). PostgreSQL will throw
ERROR: column "target_pkr" does not exist every time GET /api/admin/campaigns/stats is called.

The AdminController.getCampaignStats() passes the error through next(err). In production mode the client receives {
"error": "Internal server error" }. In development mode the full stack trace is exposed.

Impact: The admin dashboard campaign statistics section is always broken. The endpoint 500s on every call.

---

ISSUE 2 — Beneficiary "My Tasks" Screen Always Crashes (Wrong Response Key)

File: flutter_app/lib/providers/beneficiary_task_provider.dart:16

final data = response.data as Map<String, dynamic>;
return (data['tasks'] as List<dynamic>) // ← 'tasks' key does not exist
.map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
.toList();

The backend GET /api/tasks/my returns mapTaskList() which produces { "data": [...], "meta": { "total": N } }. The
actual key is data, not tasks.

data['tasks'] resolves to null. The as List<dynamic> cast on null throws a Dart TypeError at runtime. The
FutureProvider catches this and transitions to an error state, showing the error widget on the MyTasksScreen.
Beneficiaries can never view their tasks.

---

ISSUE 3 — Donation History Always Empty (Silent Parsing Failure)

File: flutter_app/lib/providers/donation_provider.dart:12-23

final data = response.data;
if (data is List) { ... } // false — response is a Map
final list = (data as Map<String, dynamic>)['donations'] as List? ?? [];
// ^^^^^^^^^^ does not exist

Backend GET /donations/mine returns mapDonationList() → { "data": [...], "meta": {} }. The Flutter code tries key
donations, gets null, and silently falls back to ?? []. No error is thrown — the myDonationsProvider resolves to an
empty list regardless of the donor's actual data.

Impact: The donor's donation history screen permanently shows "No donations" even when records exist.

---

ISSUE 4 — Chat Room List Always Empty (Silent Parsing Failure)

File: flutter_app/lib/providers/chat_provider.dart:106-117

final list = (data as Map<String, dynamic>)['rooms'] as List? ?? [];

Backend GET /api/chat/rooms returns mapChatRoomList() → { "data": [...], "meta": {} }. The key rooms does not exist in
the response. Falls back to [] silently.

---

ISSUE 5 — Chat Message History Always Empty (Silent Parsing Failure)

File: flutter_app/lib/providers/chat_provider.dart:86-96

final list = (data as Map<String, dynamic>)['messages'] as List? ?? [];

Backend GET /api/chat/rooms/:roomId/messages returns mapChatMessageList() → { "data": [...], "meta": {} }. Key
messages does not exist. Message history silently returns empty.

Note on impact: New messages sent during a live session ARE visible because they arrive via Socket.IO's new_message
event (chat_provider.dart:216). Only the message history loaded via HTTP (on room open) fails. First-time room open
always shows blank history.

---

ISSUE 6 — Suspended Users Can Keep Using Existing JWT Tokens

File: backend/src/middleware/auth.ts:44-50

const result = await pool.query(
`SELECT u.id, u.email, u.phone, u.name, u.role_id, r.name AS role
     FROM users u JOIN roles r ON r.id = u.role_id
     WHERE u.id = $1`, // ← NO status filter
[decoded.userId]
);

The authenticate middleware never checks u.status. If an admin suspends a user via PATCH /api/users/:id/suspend, that
user's existing JWT remains fully valid for up to 7 days (the expiry configured in JWT_EXPIRES_IN).

Login correctly rejects suspended users (auth.service.ts:111). But there is no mechanism to immediately revoke an
active session. The suspension only takes effect for new logins, not existing tokens.

Proof from seed data: User id=304 (bad@volunteer.pk) has status = 'SUSPENDED'. Task id=7 in the seed has claimed_by = 304. If that volunteer has a valid token, they can still call POST /api/tasks/7/start or POST /api/deliveries.

---

ISSUE 7 — Campaign Status Update Route Has No Body Validation

File: backend/src/modules/campaigns/campaigns.routes.ts:45-51

router.patch(
'/:id/status',
authenticate,
authorize('NGO', 'COORDINATOR', 'ADMIN'),
validate({ params: campaignIdParam }), // ← only params validated, NO body
(req, res, next) => campaignsController.updateStatus(req, res, next)
);

The controller extracts req.body.status directly without schema validation. Any string passes through to
campaignsService.update(), which builds a raw SET status = $N SQL clause. PostgreSQL then rejects invalid enum values
with an unhandled internal error. In production this surfaces as a generic 500.

The regular PATCH /api/campaigns/:id route correctly uses validate({ params: campaignIdParam, body:
updateCampaignSchema }) — the inconsistency is only on the /:id/status sub-route.

---

ISSUE 8 — PAUSED and CLOSED Campaign Statuses Unreachable via API

File: backend/src/modules/campaigns/campaigns.schema.ts:15

status: z.enum(['DRAFT', 'PENDING_APPROVAL', 'ACTIVE', 'COMPLETED', 'REJECTED']).optional(),

The DB campaign_status ENUM (from 001_init.sql:49) defines 7 values: DRAFT, PENDING_APPROVAL, ACTIVE, PAUSED, CLOSED,
REJECTED, COMPLETED.

PAUSED and CLOSED are absent from the Zod schema. Any PATCH request to PATCH /api/campaigns/:id with { "status":
"PAUSED" } will be rejected by Zod validation with a 400 Validation failed error, even though PAUSED is a valid
database value.

Proof: The seed data (005_comprehensive_seed.sql:91) includes campaign id=3 with status = 'PAUSED'. It was inserted
directly via SQL. There is no API path to reach this state from ACTIVE.

---

ISSUE 9 — Partial Lat/Lng Update Causes 500 (Non-Existent Column)

File: backend/src/modules/tasks/tasks.service.ts:200-218

if (input.latitude !== undefined && input.longitude !== undefined) {
// handles geography column, deletes lat/lng from fields
delete fields.latitude;
delete fields.longitude;
}
// Loop over remaining fields...
for (const [key, value] of Object.entries(fields)) {
setClauses.push(`${key} = $${paramIndex}`);

If a PATCH request provides latitude alone (without longitude), or longitude alone, the && condition is false. Neither
field is deleted from fields. The loop then generates SET latitude = $N or SET longitude = $N — but neither latitude
nor longitude are columns in the tasks table (the column is location geography). PostgreSQL throws column "latitude"
does not exist, which surfaces as a 500.

The updateTaskSchema does not enforce that lat and lng must appear together — each is individually optional — making
this a reachable error path from any valid client.

---

ISSUE 10 — Three Admin Users Exist After Full Seed Run

Source: database/001_init.sql:243 + database/005_comprehensive_seed.sql:17-18

001_init.sql inserts one admin via auto-increment:
INSERT INTO users (email, password_hash, role_id, name)
VALUES ('admin@disasteraid.pk', '$2b$10$...', 6, 'System Admin');
-- Gets id = 1 (auto-increment)

005_comprehensive_seed.sql then inserts two more admins with explicit IDs:
(100, 'Super Admin', 'super@disasteraid.pk', ..., 6, 'ACTIVE'),
(101, 'Finance Admin', 'finance@disasteraid.pk', ..., 6, 'ACTIVE'),

After both migrations run, 3 users have role_id = 6 (ADMIN): id=1, id=100, id=101. All three can log into the React
admin panel. The 001 admin (admin@disasteraid.pk) is never mentioned in the 005 seed's cleanup section.

---

ISSUE 11 — React Admin Panel: Wrong Donation Approval Endpoint in Constants

File: admin-panel/src/api/endpoints.ts:9

DONATIONS: {
CONFIRM: (id: number) => `/donations/${id}/confirm`, // ← wrong path
}

The backend route is POST /api/donations/:id/approve, not /confirm. There is no /confirm endpoint anywhere in the
backend. The DonationsPage.tsx hardcodes the correct path directly (axiosClient.post(/donations/${id}/approve)) and
does not use API_ENDPOINTS.DONATIONS.CONFIRM, but this constant is a dangling wrong reference that would break any
future code that uses it.

---

ISSUE 12 — React Admin Panel: Ledger Endpoint Constants Point to Non-Existent Routes

File: admin-panel/src/api/endpoints.ts:30-33

LEDGER: {
SUMMARY: '/ledger/summary',
TRANSACTIONS: '/ledger/transactions',
},

The backend has no routes at /api/ledger/_. The ledger endpoint is at GET /api/admin/ledger (handled by
adminController.getLedger). The correct constant already exists at API_ENDPOINTS.ADMIN.LEDGER = '/admin/ledger'. Any
code that uses API_ENDPOINTS.LEDGER._ will receive a 404.

---

SUSPECTED ISSUES

---

SUSPECT 1 — Flutter Env.apiUrl Defaults to Production in Dev Builds

File: flutter_app/lib/config/env.dart:2-5

static const String apiUrl = String.fromEnvironment(
'API_URL',
defaultValue: 'https://api.disasteraid.pk/api', // production
);

String.fromEnvironment requires --dart-define=API_URL=... at build time. Without it, all builds (including local
flutter run) hit https://api.disasteraid.pk/api. If that domain is not live, all API calls fail at the network level
without a clear error.

Meanwhile ApiConstants.baseUrl = 'http://localhost:3000/api' (api_constants.dart:11) is a documented but dead constant
— it is never read by ApiClient. The Dio BaseOptions.baseUrl is set to Env.apiUrl, not ApiConstants.baseUrl. The
comment // static const String baseUrl = 'http://10.0.2.2:3000/api' suggests this was once the active URL and was
accidentally retired during a refactor.

---

SUSPECT 2 — updateCampaignSchema Missing status in Update Route Used for Full Updates

File: backend/src/modules/campaigns/campaigns.routes.ts:54-62 and campaigns.schema.ts:11-18

The PATCH /api/campaigns/:id route uses updateCampaignSchema which includes status. But that schema is also what
validates PATCH /api/campaigns/:id/status — except the status sub-route bypasses body validation entirely (see
Confirmed Issue 7). The two update paths are inconsistent in their validation approach.

---

SUSPECT 3 — Delivery Verification Uses pool.query Inside a client Transaction

File: backend/src/modules/deliveries/deliveries.service.ts:99

const verifierResult = await pool.query( // ← pool, not client
'SELECT name FROM roles WHERE id = (SELECT role_id FROM users WHERE id = $1)',
[verifiedBy]
);

This query runs on a separate connection outside the active BEGIN transaction held by client. If the DB is under heavy
load and the pool is exhausted (all 20 connections busy), this pool.query will block waiting for a connection while
client is already holding one inside a transaction — a potential deadlock scenario. It won't deadlock with just one
request, but could under concurrent verification load.

---

SUSPECT 4 — Duplicate TaskItem Class Across Two Model Files

Files:

- flutter_app/lib/features/tasks/domain/task_model.dart:51-65 — defines TaskItem with String quantity
- flutter_app/lib/models/task_models.dart:4-23 — also defines TaskItem with dynamic quantity

Two parallel TaskItem classes exist. The domain/task_model.dart version is used by task providers and screens.
models/task_models.dart (Task class) is a separate older model apparently not connected to current providers. If both
are imported in the same file, Dart would require import prefixes or disambiguation. Confusion between Task (old) and
TaskModel (current) could cause incorrect deserialization if a screen imports the wrong one.

---

DATA INCONSISTENCIES

---

DATA ISSUE 1 — Seeded Withdrawal Exceeds NGO Wallet Balance

Source: database/005_comprehensive_seed.sql:127

(2, 201, 2000000.00, 'PK0987654321', 'PENDING', NULL, NULL),
-- Edhi Foundation: wallet_balance = 1,250,000.50

Withdrawal id=2 for user_id=201 (Edhi Foundation) requests 2,000,000 PKR but the NGO's wallet balance is only
1,250,000.50 PKR (from ngo_profiles seed, line 73).

The seed bypasses the service-level balance check by inserting directly into SQL. This record exists in a legally
impossible state — a PENDING withdrawal that can never be approved (the approveWithdrawal service will correctly block
it with "Insufficient wallet balance at approval time"). The record is noted as an explicit edge-case test in the
seed comments.

---

DATA ISSUE 2 — Task id=7 Claimed by Suspended Volunteer, Status FLAGGED

Source: 005_comprehensive_seed.sql:109

(7, 5, 402, 200, 304, 601, 'NGO_CAMPAIGN', 'Task with Suspended Volunteer', 'FLAGGED', ...)

Task id=7 has claimed_by = 304. User id=304 has status = 'SUSPENDED'. The task lifecycle left the volunteer's
volunteer_profiles.status as BUSY (set when they claimed it) even after suspension. If the task is un-flagged and the
volunteer somehow regains access, the system has no mechanism to handle this state.

---

DATA ISSUE 3 — spent_pkr Column Is Never Written By Any Service

Source: database/001_init.sql:120 (column exists) vs all service files (no writer exists)

The campaigns.spent_pkr column exists in the schema and is read by adminService.getLedger():
SELECT id, title, goal_pkr, raised_pkr, spent_pkr, (raised_pkr - spent_pkr) as remaining_balance

But no service in the codebase writes to spent_pkr. Delivery verification (deliveries.service.ts) updates
volunteer_profiles.total_earned and creates a ledger entry but does NOT update campaigns.spent_pkr. The
remaining_balance computed column in the ledger query (raised_pkr - spent_pkr) will always equal raised_pkr because
spent_pkr is always 0.

Impact: The admin ledger's "remaining balance" figure for all campaigns is wrong — it shows the full raised amount as
unspent, even for campaigns where volunteers have been paid.

---

DATA ISSUE 4 — task_events Seed References FLAGGED Event Type Not in ENUM

Source: database/005_comprehensive_seed.sql:168

INSERT INTO task_events (task_id, user_id, event_type) VALUES
(7, 304, 'FLAGGED');

The task_event_type ENUM in 001_init.sql:35-47 does NOT include 'FLAGGED'. The valid values are CREATED, SEEN,
ASSIGNED, CLAIMED, STARTED, SUBMITTED, VERIFIED, PAID, FLAGGED, CHAT_STARTED, UPDATED, CANCELLED.

Wait — actually FLAGGED IS in the enum (line 44). Let me re-examine... FLAGGED is in fact in the enum. This is not an
inconsistency.

---

DATA ISSUE 5 — Sequence Synchronization Depends on Docker Init Order

Source: docker-compose.yml:15-19

All 5 .sql files are mounted into docker-entrypoint-initdb.d/:
volumes: - ./database/001_init.sql:/docker-entrypoint-initdb.d/001_init.sql - ./database/002_finance_system.sql:/... - ./database/003_chat_task_scope.sql:/... - ./database/004_audit_system.sql:/... - ./database/005_comprehensive_seed.sql:/...

Docker runs these in filename alphabetical order. This order is critical — 003 assumes chat_rooms have duplicate rows
to clean up (from earlier seed data), and 005 assumes all tables from 002 and 004 exist. If someone adds a new
migration file whose name sorts before 005 but depends on tables created in 004, it will fail. There's no explicit
ordering mechanism beyond filename prefix.

Additionally, 005_comprehensive_seed.sql has a TRUNCATE block commented out at line 9. If run on an existing populated
DB (not a fresh container), the ON CONFLICT DO NOTHING guards will silently skip data that conflicts, leaving the DB
in a hybrid state mixing old and new seed data.

---

AUTH / ROLE FAILURES

---

AUTH FAILURE 1 — status Column Missing from authenticate DB Query

As detailed in Confirmed Issue 6. The authenticate middleware does not select u.status and does not reject suspended
users. The query:

SELECT u.id, u.email, u.phone, u.name, u.role_id, r.name AS role
FROM users u JOIN roles r ON r.id = u.role_id
WHERE u.id = $1

Would need AND u.status = 'ACTIVE' to immediately enforce suspensions.

---

AUTH FAILURE 2 — No ADMIN Registration Block at Schema Level

File: backend/src/modules/auth/auth.schema.ts:7

role: z.enum(['DONOR', 'BENEFICIARY', 'VOLUNTEER', 'NGO', 'COORDINATOR']),

The Zod schema correctly blocks ADMIN at the validation layer — ADMIN is not in the enum. The service also has a
runtime check (auth.service.ts:14). This is double protection. No bug here, but noting it is working correctly.

---

AUTH FAILURE 3 — React Admin Panel localStorage Token Vulnerable to XSS

File: admin-panel/src/auth/authService.ts:9-10

localStorage.setItem('admin_token', response.data.token);
localStorage.setItem('admin_user', JSON.stringify(user));

Admin JWT is stored in localStorage, which is accessible to any JavaScript running on the same origin. An XSS
vulnerability in any page of the admin panel (even in a third-party dependency) could extract the admin token. The
Flutter app correctly uses flutter_secure_storage (OS-level keychain/keystore). The admin panel uses the less secure
browser storage.

This is a design choice with a known trade-off, not a code bug — but in an admin panel context it is a meaningful
security observation.

---

SEED PROBLEMS

---

SEED PROBLEM 1 — Admin from 001_init.sql Never Updated by 005_comprehensive_seed.sql

User id=1 (admin@disasteraid.pk) is inserted by 001_init.sql. The 005 seed inserts admins with IDs 100 and 101 using
ON CONFLICT (id) DO UPDATE. Since id=1 is not in the explicit 005 INSERT, it is never touched by 005. Both seeds use
the same password hash ($2b$10$3euPcmQFCiblsZeEu5s7p.9wWHJPaYbmo9gq3g5l6h8d5k8j5 = password123). So id=1 is also a
valid admin but is not part of any documented test plan.

---

SEED PROBLEM 2 — ngo_profiles Seed for User id=204 Has status = 'PENDING'

Source: 005_comprehensive_seed.sql:77

(5, 204, 'Shadow NGO', 10.00, 'PENDING')

User id=204 (shadow@ngo.pk) has users.status = 'SUSPENDED' but ngo_profiles.status = 'PENDING'. These are two separate
status columns on two separate tables with no synchronized enforcement. A SUSPENDED NGO user can still have an ACTIVE
ngo_profiles record, which means their campaigns and financial data remain queryable through JOINs even though they
cannot log in with new tokens.

---

SUMMARY TABLE

┌─────┬──────────┬─────────┬──────────────────────────────────────────────────────────────────────────────────┐
│ # │ Severity │ Layer │ Issue │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 1 │ Critical │ Backend │ target_pkr column crash on admin campaign stats │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 2 │ Critical │ Flutter │ Beneficiary My Tasks throws NPE (wrong response key tasks vs data) │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 3 │ High │ Flutter │ Donation history silently always empty (donations vs data) │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 4 │ High │ Flutter │ Chat room list silently empty (rooms vs data) │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 5 │ High │ Flutter │ Chat message history silently empty (messages vs data) │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 6 │ High │ Backend │ Suspended users keep full API access until token expires │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 7 │ Medium │ Backend │ Campaign /:id/status has no body validation; invalid status leaks DB errors │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 8 │ Medium │ Backend │ PAUSED and CLOSED statuses blocked by Zod; unreachable via API │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 9 │ Medium │ Backend │ Partial lat/lng PATCH crashes with column "latitude" does not exist │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 10 │ Low │ Data │ 3 admin users exist after full seed; id=1 from 001 is undocumented │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 11 │ Low │ React │ API_ENDPOINTS.DONATIONS.CONFIRM uses /confirm — backend route is /approve │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 12 │ Low │ React │ API_ENDPOINTS.LEDGER.\* routes do not exist in backend │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 13 │ Low │ Data │ spent_pkr never written; ledger remaining_balance is always wrong │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 14 │ Low │ Flutter │ Env.apiUrl defaults to production; ApiConstants.baseUrl is dead code │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 15 │ Low │ Data │ Withdrawal id=2 seeded with amount > wallet balance (intentional test edge case) │
├─────┼──────────┼─────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 16 │ Low │ Flutter │ Duplicate TaskItem and Task/TaskModel parallel models │
└─────┴──────────┴─────────┴──────────────────────────────────────────────────────────────────────────────────┘
