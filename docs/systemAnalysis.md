---
  DisasterAid V2.1 — Full System Analysis

  ---
  1. SYSTEM OVERVIEW

  Business Purpose

  DisasterAid V2.1 is a disaster-relief coordination platform built for Pakistan. It connects six types of actors:
  Admins who govern the platform, NGOs who fund and create relief campaigns, Coordinators who supervise field tasks,
  Volunteers who execute deliveries on the ground, Beneficiaries who submit aid requests, and Donors who contribute
  money. The system manages the entire lifecycle from posting a relief task, claiming it, delivering aid, uploading
  proof, and finally paying out to the volunteer — along with a parallel financial ledger that tracks every donation and
   NGO withdrawal.

  Main Components

  ┌─────────────────────────────────────────────────────────┐
  │  Flutter Mobile App (Dart + Riverpod + Dio)             │
  │  ─ 6 role-specific UIs, GoRouter, secure storage        │
  ├─────────────────────────────────────────────────────────┤
  │  React Admin Panel (Vite + Ant Design + Axios)          │
  │  ─ ADMIN-only, localStorage, role guard on every route  │
  ├─────────────────────────────────────────────────────────┤
  │  Backend API (Node.js + Express + TypeScript)           │
  │  ─ 9 route modules, JWT auth, raw SQL via pg.Pool       │
  ├─────────────────────────────────────────────────────────┤
  │  PostgreSQL 16 + PostGIS 3 (Docker)                     │
  │  ─ 5 migration files, geography columns, ENUM types     │
  └─────────────────────────────────────────────────────────┘

  The backend also runs a Socket.IO server (on the same HTTP server instance) for real-time chat between volunteers,
  coordinators, and NGO staff.

  Architecture Style

  The backend is a layered monolith split into feature modules. Each module (auth, tasks, campaigns, donations,
  deliveries, chat, withdrawals, admin, users) owns its own routes → controller → service stack. There is no shared ORM
  — every module talks to Postgres directly via parameterized pg.Pool queries. Shared concerns (auth middleware, error
  handler, mapper functions) live outside modules in middleware/ and common/.

  ---
  2. BACKEND DEEP DIVE

  Folder Structure

  backend/src/
  ├── index.ts               — Entry point: boots server, exports app
  ├── server.ts              — Express setup, all middleware, route mounting, Socket.IO
  ├── config/
  │   ├── env.ts             — Zod-validated env vars (crashes on missing secrets)
  │   ├── database.ts        — pg.Pool creation, health check
  │   └── circuitBreaker.ts  — (present, not analyzed)
  ├── middleware/
  │   ├── auth.ts            — JWT verification + DB role re-fetch (authenticate)
  │   ├── authorize.ts       — Role whitelist check (authorize factory)
  │   ├── validate.ts        — Zod schema validation for body/query/params
  │   ├── errorHandler.ts    — Global error handler + createError helper
  │   └── rateLimiter.ts     — express-rate-limit (100 req / 15 min per IP)
  ├── common/
  │   └── mappers/           — Pure functions that sanitize DB rows before sending to clients
  │       ├── user.mapper.ts
  │       ├── task.mapper.ts
  │       ├── donation.mapper.ts
  │       └── ... (one per entity)
  └── modules/
      ├── auth/              — register, login, /me
      ├── tasks/             — CRUD + claim/start/unclaim lifecycle
      ├── campaigns/         — CRUD + status transitions
      ├── donations/         — create, approve, reject
      ├── deliveries/        — photo upload + GPS proof
      ├── chat/              — REST rooms/messages + Socket.IO gateway
      ├── withdrawals/       — NGO withdrawal requests + admin approval
      ├── admin/             — aggregated stats and audit views (ADMIN only)
      └── users/             — user listing for admin

  Each module follows the pattern: *.routes.ts → *.controller.ts → *.service.ts, optionally with *.schema.ts (Zod
  validation shapes).

  ---
  Authentication System

  Registration (POST /api/auth/register):

  1. Request body is validated by Zod (registerSchema). Allowed roles: DONOR, BENEFICIARY, VOLUNTEER, NGO, COORDINATOR.
  ADMIN is explicitly blocked in AuthService.register() at the business logic level — it throws 403 if attempted.
  2. Duplicate email or phone is checked with separate SELECT queries.
  3. The role name is resolved to a role_id via SELECT id FROM roles WHERE name = $1.
  4. Password is hashed with bcrypt at 12 rounds (configurable via BCRYPT_ROUNDS env var).
  5. A row is inserted into users. Supplementary profiles are also auto-created: volunteer_profiles for VOLUNTEER,
  ngo_profiles for NGO.
  6. A JWT is generated containing only { userId } and returned alongside the user object (mapped through mapUser).

  Login (POST /api/auth/login):

  1. Accepts email or phone plus password.
  2. Fetches the user + role name from DB in a single JOIN query.
  3. Checks user.status !== 'SUSPENDED' — suspended accounts receive 403.
  4. Password is compared with bcrypt.compare.
  5. A new JWT is generated and returned.

  JWT Structure — the token payload contains exactly one field:

  { "userId": 42 }

  There is no role in the token. Expiry is set via the JWT_EXPIRES_IN env var (default 7d). The signing algorithm is
  HS256 (jsonwebtoken default).

  ---
  Authorization System

  Role definitions — roles are stored as rows in the roles table using the user_role ENUM:

  id | name
  ---+-------------
  1  | DONOR
  2  | BENEFICIARY
  3  | VOLUNTEER
  4  | NGO
  5  | COORDINATOR
  6  | ADMIN

  Role assignment — at registration, the role_id FK on users is set by looking up the role name in the roles table.
  There is no runtime role-change mechanism exposed through any route.

  Middleware flow for every protected request:

  Request → authenticate() → authorize(...roles) → Controller

  authenticate (middleware/auth.ts:23):
  1. Reads Authorization: Bearer <token> header.
  2. Calls jwt.verify(token, JWT_SECRET) to get { userId }.
  3. Performs a DB query to fetch id, email, phone, name, role_id, and the role name via JOIN: SELECT u.*, r.name AS
  role FROM users u JOIN roles r ON r.id = u.role_id WHERE u.id = $1.
  4. Attaches the full AuthUser object to req.user. The comment in the code explicitly states: "NEVER trusts
  client-supplied role — always reads from DB."

  authorize (middleware/authorize.ts:8) — a factory function:
  authorize('NGO', 'COORDINATOR', 'ADMIN')
  It reads req.user.role (the string fetched from DB) and checks if it is in the allowed list. Returns 403 with {
  required, current } if not.

  Route-level role examples:
  - POST /api/tasks/:id/claim — VOLUNTEER only
  - PATCH /api/tasks/:id — NGO, COORDINATOR, ADMIN
  - POST /api/donations/:id/approve — ADMIN only
  - POST /api/withdrawals — NGO only
  - GET /api/admin/* — ADMIN only (applied at router level: router.use(authenticate); router.use(authorize('ADMIN')))

  Ownership enforcement within services — authorize only checks role. Fine-grained ownership is enforced inside the
  service layer. Example in tasksService.updateTask: if role is NGO, a AND created_by = $userId clause is appended to
  the UPDATE WHERE condition, preventing NGOs from editing other NGOs' tasks.

  ---
  Database Interaction

  There is no ORM. The backend uses pg.Pool directly with parameterized queries ($1, $2, ...). The pool is configured
  with:
  - max: 20 connections
  - idleTimeoutMillis: 30000
  - statement_timeout: 30000 (kills queries running > 30 s)

  For operations requiring atomicity (claim task, approve donation, approve withdrawal), the services manually check out
   a client from the pool and use BEGIN / COMMIT / ROLLBACK. The task claim uses SELECT ... FOR UPDATE to prevent race
  conditions when multiple volunteers try to claim the same task simultaneously.

  PostGIS geography columns are used for task locations. Points are stored as GEOGRAPHY(Point, 4326) and inserted via
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography. Coordinates are extracted in SELECT queries via
  ST_X(location::geometry) AS longitude, ST_Y(location::geometry) AS latitude.

  ---
  Seed System

  Seeding is done via 5 SQL migration files mounted into Docker's docker-entrypoint-initdb.d/ directory. Docker runs all
   *.sql files in alphabetical order on first container creation, inside the postgres container.

  ┌────────────────────────────┬─────────────────────────────────────────────────────────────────────────────────────┐
  │            File            │                                       Purpose                                       │
  ├────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ 001_init.sql               │ Schema (all tables, ENUMs, indexes, triggers) + minimal seed: 6 roles + 1 admin     │
  │                            │ user                                                                                │
  ├────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ 002_finance_system.sql     │ Alters donations table, creates withdrawals table                                   │
  ├────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ 003_chat_task_scope.sql    │ Enforces unique chat room per task (dedup + unique index)                           │
  ├────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ 004_audit_system.sql       │ Creates audit_logs table                                                            │
  ├────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ 005_comprehensive_seed.sql │ Full QA dataset: 30+ users, campaigns, tasks, donations, withdrawals, chat          │
  │                            │ messages, ledger entries, audit logs                                                │
  └────────────────────────────┴─────────────────────────────────────────────────────────────────────────────────────┘

  Duplication prevention — 005 uses ON CONFLICT (id) DO UPDATE SET ... for users and campaigns (idempotent upsert), and
  ON CONFLICT (id) DO NOTHING for donations/withdrawals/chat (skip if already inserted). It also calls setval() at the
  end to synchronize all SERIAL sequences to their actual max values, preventing PK collisions after manual ID inserts.

  Note: The TRUNCATE block at the top of 005 is commented out. If run against an existing DB, upserts will update
  records rather than start clean.

  ---
  3. DATABASE DEEP DIVE

  Core Tables and Their Relationships

  roles (1) ─────────────────── (M) users
                                        │
                ┌───────────────────────┼──────────────────────────┐
                │                       │                          │
      volunteer_profiles          ngo_profiles                  (direct)
           (1:1 user)               (1:1 user)
                                        │
                                 campaigns (M)
                                        │
                                tasks ──┘
                               /  |  \
                       task_events  task_views  deliveries
                               │
                          chat_rooms ── chat_messages

  Table Details

  roles — 6 rows, seeded on init. Referenced by users.role_id.

  users — Core identity table.
  - Either email or phone must be present (CHECK constraint).
  - password_hash — bcrypt.
  - role_id FK → roles.id.
  - status ENUM: ACTIVE or SUSPENDED.
  - fcm_token TEXT — for push notifications (nullable).
  - Indexes on email and phone.

  ngo_profiles — 1:1 extension of users for NGO role.
  - wallet_balance NUMERIC(12,2) — manually maintained ledger; updated by donation approval service.
  - status VARCHAR(20) — ACTIVE or PENDING (separate from users.status).
  - location GEOGRAPHY(Point, 4326) — nullable.

  volunteer_profiles — 1:1 extension of users for VOLUNTEER role.
  - ngo_id INT FK → ngo_profiles.id — nullable, allows volunteer affiliation to NGO.
  - rating, completed_tasks, total_earned — maintained by task lifecycle events.
  - status VARCHAR(20) — ACTIVE or BUSY.

  campaigns — Created by NGOs/Coordinators/Admin.
  - ngo_id FK → ngo_profiles.id (SET NULL on delete).
  - status campaign_status ENUM: DRAFT → PENDING_APPROVAL → ACTIVE → PAUSED/CLOSED/REJECTED/COMPLETED.
  - raised_pkr — incremented by donation approval.
  - spent_pkr — not updated by any current service code (field exists, no service writes to it).

  tasks — Central entity.
  - source_type ENUM: BENEFICIARY_REQUEST, NGO_CAMPAIGN, PLATFORM_CAMPAIGN, ADMIN_CREATED.
  - status ENUM: OPEN → CLAIMED → IN_PROGRESS → SUBMITTED → COORDINATOR_VERIFIED → PAID (or FLAGGED/CANCELLED).
  - location GEOGRAPHY(Point, 4326) NOT NULL.
  - Spatial index on location using GIST.
  - Partial index on status for OPEN/ASSIGNED states.
  - Multiple FK references to users: beneficiary_id, created_by, claimed_by, coordinator_id.

  task_events — Append-only audit trail for task state changes. One row per event with optional metadata JSONB.

  task_views — Composite PK (task_id, user_id). Tracks per-user view counts with upsert.

  deliveries — Proof submission by volunteers.
  - photo_urls TEXT[] — array of image URLs.
  - gps_location GEOGRAPHY(Point, 4326) NOT NULL.
  - verified_by FK → users.id — set when coordinator verifies.

  donations — Manual bank transfer model (no payment gateway active).
  - status VARCHAR(20) — PENDING, CONFIRMED, REJECTED.
  - payment_method — always BANK_TRANSFER in current code.
  - approved_by, rejected_by — FK → users.id, set by admin actions.
  - gateway_ref VARCHAR(255) UNIQUE — used as bank reference number; unique constraint prevents duplicate submissions.

  withdrawals — NGO requests to withdraw from their wallet balance.
  - ngo_user_id FK → users.id (not ngo_profiles.id — references user directly).
  - amount NUMERIC(12,2) CHECK (amount > 0).
  - status VARCHAR(20) — PENDING, APPROVED, REJECTED.
  - Note: There is no enforcement that amount <= ngo_profiles.wallet_balance at the DB constraint level. Withdrawal with
   ID 2 in the seed data has amount = 2,000,000 against a wallet balance of 1,250,000.50 — this is an explicit edge-case
   test in the seed.

  chat_rooms — One per task (enforced by unique index added in 003). Created automatically when a volunteer claims a
  task.

  chat_messages — Chat messages tied to a room. No updated_at, no soft delete.

  ledger_entries — Flat append-only financial log. type, amount_pkr, from_user_id, to_user_id, ref_table, ref_id. No FK
  enforcement on ref_id.

  audit_logs — Admin action log. admin_id FK, action_type, target_entity, target_id, metadata JSONB.

  app_config — Single-row config table (id = 1). Contains disaster_mode BOOLEAN.

  Actual Seeded Data State

  After 005_comprehensive_seed.sql runs:
  - Users: 2 Admins (id 100/101), 5 NGOs (200–204, one SUSPENDED), 10 Volunteers (300–309, one SUSPENDED), 5
  Beneficiaries (400–404), 10 Donors (500–509), 2 Coordinators (600/601), plus the initial admin from 001
  (auto-increment id, email admin@disasteraid.pk). All passwords are password123 (same bcrypt hash).
  - Campaigns: 5 (1 ACTIVE, 1 ACTIVE over-funded, 1 PAUSED, 1 DRAFT, 1 COMPLETED).
  - Tasks: 8, spanning all status values including FLAGGED and PAID.
  - Donations: 7 (mix of CONFIRMED, PENDING, REJECTED).
  - Withdrawals: 4 (APPROVED, PENDING, REJECTED, second PENDING for same NGO).

  ---
  4. REACT ADMIN PANEL

  Authentication Flow

  1. User submits email + password on LoginPage.
  2. authService.login() posts to /api/auth/login.
  3. On success, two items are written to localStorage: admin_token (the JWT string) and admin_user (the user object as
  JSON).
  4. AuthContext.login() checks data.user.role !== 'ADMIN' — if not ADMIN, it calls authService.logout() (clears
  storage) and shows an error. The token is never stored for non-admins.
  5. On app startup, useEffect in AuthProvider calls verifySession() which reads admin_token from localStorage, calls
  GET /api/auth/me, and checks userData.role !== 'ADMIN'. This means even if someone injects a non-admin token into
  localStorage, the backend re-check will resolve the real role.

  Token Storage

  JWT is stored in localStorage under the key admin_token. This is accessible to JavaScript running on the same origin
  (unlike HttpOnly cookies). A second key admin_user stores the cached user object as a JSON string.

  Route Protection

  ProtectedRoute (router/ProtectedRoute.tsx:6) wraps all admin routes:
  if (isLoading) → show Spinner
  if (!isAuthenticated || user?.role !== 'ADMIN') → redirect to /login
  else → render Outlet

  The isAuthenticated flag is true only when both user !== null AND token !== null in AuthContext state. The role is
  double-checked here against the in-memory state — but the source of truth for that in-memory state is the /api/auth/me
   call at startup, which always fetches from DB.

  Axios Client

  axiosClient.ts creates an Axios instance with baseURL from VITE_API_URL or http://localhost:3000/api. A request
  interceptor reads admin_token from localStorage and injects Authorization: Bearer <token> into every request. A
  response interceptor watches for 401 status — on 401 it clears both localStorage keys and redirects to /login.

  Admin Panel Pages

  All pages are behind ProtectedRoute. Available routes:
  - /dashboard — DashboardPage
  - /donations — DonationsPage (list + approve/reject)
  - /withdrawals — WithdrawalsPage
  - /campaigns — CampaignsPage
  - /users — UsersPage
  - /ledger — LedgerPage

  All data fetching goes through axiosClient to /api/admin/* endpoints, which have router-level authenticate +
  authorize('ADMIN') middleware.

  ---
  5. FLUTTER APPS

  Authentication Flow

  1. AuthNotifier is initialized by Riverpod on app boot. Its constructor calls _checkAuth().
  2. _checkAuth() reads the token from SecureStorageService (which wraps flutter_secure_storage). If a token exists, it
  calls AuthRepository.getProfile() → GET /api/auth/me. If that succeeds, state becomes authenticated. If it fails
  (expired/invalid token), clearAll() wipes storage and state becomes unauthenticated.
  3. On explicit login, AuthNotifier.login() calls AuthRepository.login(), saves token + role + userId to secure
  storage, then sets state to authenticated.

  Token Storage

  The Flutter app uses flutter_secure_storage — this is platform-native encrypted storage (Android:
  EncryptedSharedPreferences, iOS: Keychain). Three keys are stored:
  - auth_token — the JWT string
  - user_role — the role string (e.g. "VOLUNTEER")
  - user_id — the user ID as a string

  Role Usage

  The UserModel maps the string role from the server to a UserRole enum via UserRole.fromString(). The appRouterProvider
   watches authState.user?.role and the redirect callback in GoRouter calls _roleHome(role) to send authenticated users
  to their role-specific home screen:

  BENEFICIARY  → /beneficiary/tasks
  DONOR        → /donor/campaigns
  VOLUNTEER    → /volunteer/tasks
  NGO          → /ngo/dashboard
  COORDINATOR  → /coordinator/tasks
  (other)      → /dashboard

  The router itself does not enforce that a DONOR cannot navigate to /volunteer/tasks by typing the URL — there are no
  per-route role guards beyond the initial redirect. The backend enforces authorization for all actual data operations.

  API Communication

  ApiClient wraps Dio with:
  - baseUrl from Env.apiUrl (configured in lib/config/env.dart)
  - connectTimeout, receiveTimeout, sendTimeout each set to 15 seconds
  - RetryInterceptor — retries failed requests (implementation not read)
  - AuthInterceptor — reads token from secure storage before each request and sets Authorization: Bearer <token>. On 401
   response, deletes the stored token (navigation is left to state management, not the interceptor)
  - LogInterceptor — active only in debug mode; scrubs passwords from logs with regex

  ApiConstants contains all endpoint paths as static constants and static methods (e.g. ApiConstants.claimTask(id)
  returns '/tasks/$id/claim').

  ---
  6. END-TO-END FLOW

  Scenario: A VOLUNTEER logs in and claims an OPEN task.

  Step 1 — Login (Flutter → Backend)

  Flutter LoginScreen calls authProvider.login(email: 'ahmed@volunteer.pk', password: 'password123').

  AuthNotifier.login() sets state to loading, then calls AuthRepository.login(), which calls:
  POST /api/auth/login
  Body: { "email": "ahmed@volunteer.pk", "password": "password123" }

  AuthInterceptor.onRequest runs first — reads token from secure storage, finds nothing (user is logging in fresh), so
  no header is added. Request is sent.

  Step 2 — Backend Processes Login

  Express receives request. rateLimiter runs first, then cors, then json() body parser.

  POST /api/auth/login matches authRoutes. The validate({ body: loginSchema }) middleware runs Zod parse — passes.
  authController.login() is called.

  authService.login() executes:
  SELECT u.id, u.email, u.phone, u.name, u.password_hash, u.role_id, u.status, r.name AS role
  FROM users u JOIN roles r ON r.id = u.role_id
  WHERE u.email = 'ahmed@volunteer.pk'
  Returns user with role = 'VOLUNTEER', status = 'ACTIVE'.

  bcrypt.compare('password123', storedHash) → true.

  generateToken(user.id):
  jwt.sign({ userId: 300 }, JWT_SECRET, { expiresIn: '7d' })
  // Produces a HS256 JWT with payload { userId: 300, iat: ..., exp: ... }

  Response:
  {
    "token": "eyJ...",
    "user": { "id": 300, "name": "Ahmed Khan", "email": "ahmed@volunteer.pk", "role": "VOLUNTEER", ... }
  }

  Step 3 — Token Stored (Flutter)

  AuthRepository.login() returns ({ user: UserModel, token: String }).

  AuthNotifier.login() calls:
  await _storage.saveToken(result.token);        // writes to flutter_secure_storage key 'auth_token'
  await _storage.saveUserRole(result.user.role); // writes 'VOLUNTEER' to key 'user_role'
  await _storage.saveUserId(result.user.id.toString()); // writes '300' to key 'user_id'

  State becomes AuthState(status: authenticated, user: UserModel(id:300, role: VOLUNTEER)).

  Step 4 — Router Redirects

  appRouterProvider watches authState. The redirect callback sees isAuthenticated = true and user.role =
  UserRole.volunteer, returns /volunteer/tasks. GoRouter navigates there.

  Step 5 — Fetch Available Tasks (Flutter → Backend)

  TasksScreen (mounted at /volunteer/tasks) calls the tasks provider which calls:
  GET /api/tasks/available
  Authorization: Bearer eyJ...

  AuthInterceptor.onRequest reads token from secure storage, attaches header.

  Step 6 — Backend Validates Request

  GET /api/tasks/available hits the authenticate middleware.

  1. Header parsed: token = "eyJ...".
  2. jwt.verify(token, JWT_SECRET) → { userId: 300 }.
  3. DB query:
  SELECT u.id, u.email, u.phone, u.name, u.role_id, r.name AS role
  FROM users u JOIN roles r ON r.id = u.role_id
  WHERE u.id = 300
  Returns { id: 300, name: 'Ahmed Khan', role: 'VOLUNTEER', role_id: 3, ... }.
  4. req.user is set.

  No authorize() middleware on this route — any authenticated user can see available tasks.

  tasksController.getAvailable() → tasksService.getAvailableTasks():
  SELECT t.*, ST_X(t.location::geometry) AS longitude, ST_Y(t.location::geometry) AS latitude, u.name AS created_by_name
  FROM tasks t LEFT JOIN users u ON u.id = t.created_by
  WHERE t.status = 'OPEN'
  ORDER BY CASE t.urgency WHEN 'CRITICAL' THEN 1 ... END, t.created_at DESC
  Returns tasks ordered by urgency then age.

  Response is array of task objects including lat/lng extracted from PostGIS geography.

  Step 7 — Volunteer Claims a Task

  Volunteer taps a task, app calls:
  POST /api/tasks/3/claim
  Authorization: Bearer eyJ...

  Backend runs authenticate → re-fetches user from DB (role confirmed VOLUNTEER).

  authorize('VOLUNTEER') checks req.user.role === 'VOLUNTEER' → passes.

  tasksController.claim() → tasksService.claimTask(taskId: 3, volunteerId: 300):

  const client = await pool.connect();
  await client.query('BEGIN');
  // Row-level lock — concurrent claims for same task will BLOCK here:
  const lockResult = await client.query(
    'SELECT id, status, claimed_by FROM tasks WHERE id = 3 FOR UPDATE'
  );
  // Checks: status === 'OPEN', claimed_by === null
  await client.query(
    "UPDATE tasks SET status = 'CLAIMED', claimed_by = 300, claimed_at = NOW() WHERE id = 3"
  );
  await client.query(
    "INSERT INTO task_events (task_id, user_id, event_type, metadata) VALUES (3, 300, 'CLAIMED', ...)"
  );
  await client.query(
    "UPDATE volunteer_profiles SET status = 'BUSY' WHERE user_id = 300"
  );
  await client.query('COMMIT');

  After commit, chatService.createRoom(3, 300) auto-creates a chat room (with unique index guard from 003).

  Step 8 — Response Back to Flutter

  Backend returns the updated task row with status: 'CLAIMED'.

  Flutter state is updated; the task card now shows as claimed. The volunteer can navigate to the task detail screen and
   enter the chat room for this task.

  ---
  Summary of Key Design Decisions (Observations Only)

  ┌─────────────────────────┬────────────────────────────────────────────────────────────────────────────────────┐
  │         Concern         │                                  How It's Handled                                  │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Role in JWT             │ Not stored in token — always re-fetched from DB per request                        │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Race conditions         │ SELECT ... FOR UPDATE inside explicit DB transactions                              │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Admin self-registration │ Blocked in AuthService.register() at code level                                    │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Suspended accounts      │ Checked in login() service, not at middleware level                                │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Schema validation       │ Zod on every request that has a body/params                                        │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Token storage (admin)   │ localStorage (JavaScript-accessible)                                               │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Token storage (mobile)  │ flutter_secure_storage (OS-native encryption)                                      │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Chat access control     │ Socket.IO middleware verifies JWT; join_room event checks DB for task membership   │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ Financial atomicity     │ DB transactions for donation approve, withdrawal approve                           │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ spent_pkr on campaigns  │ Column exists in schema; no current service code writes to it                      │
  ├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────┤
  │ NGO wallet overdraft    │ No DB-level CHECK constraint; relies on service-level logic in withdrawals service │
  └─────────────────────────┴────────────────────────────────────────────────────────────────────────────────────┘
