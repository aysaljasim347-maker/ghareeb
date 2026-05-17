---

DisasterAid V2 — Full-Stack Feature Audit

---

1. Executive Summary

The codebase has a sound architectural foundation: clean Controller→Service→DB layering, properly parameterized SQL, a JWT
middleware that always reads roles from the database, and transaction-safe task claiming. However, five end-to-end flows are
completely non-functional in their current state, not due to missing files but due to wiring breaks between the layers. The
Volunteer flow collapses after the claim step, Chat is broken at room creation, Stripe is wired to nothing, proof upload sends
the wrong body format, and task navigation throws a GoRouter error before any API call is even made. The system is not
production-ready and would fail basic QA on its three core flows.

---

2. Feature Matrix

Feature: Register / Login
Status: ✅ COMPLETE
Evidence: auth.service.ts, auth_repository.dart, GoRouter redirect
Problem: Full round-trip. Role read from DB, bcrypt 12 rounds, JWT issued.
────────────────────────────────────────
Feature: JWT / RBAC middleware
Status: ✅ COMPLETE
Evidence: auth.ts, authorize.ts
Problem: Always DB-reads role; never trusts client claim.
────────────────────────────────────────
Feature: Token auto-attach (interceptor)
Status: ✅ COMPLETE
Evidence: api_interceptor.dart
Problem: Attaches Bearer on every request; deletes on 401.
────────────────────────────────────────
Feature: App-startup auth restore
Status: ✅ COMPLETE
Evidence: AuthNotifier.\_checkAuth()
Problem: Reads token, calls /auth/me, falls back to unauthenticated.
────────────────────────────────────────
Feature: Campaign list (Donor)
Status: ✅ COMPLETE
Evidence: campaignsProvider → GET /campaigns?status=ACTIVE → DB
Problem: Full round-trip. PostGIS coords extracted.
────────────────────────────────────────
Feature: Campaign detail / progress
Status: ✅ COMPLETE
Evidence: PaymentScreen + campaignDetailProvider
Problem: Correct data mapping.
────────────────────────────────────────
Feature: Campaign images
Status: ❌ MISSING
Evidence: CampaignModel.imageUrl reads json['image_url']; DB has no such column
Problem: Always null. Placeholder shown.
────────────────────────────────────────
Feature: Campaign creation (NGO)
Status: ⚠️ PARTIAL
Evidence: POST /campaigns backend works
Problem: No Flutter UI for NGO to create campaigns. NGO falls to generic shell.
────────────────────────────────────────
Feature: Campaign status approval flow
Status: ❌ MISSING
Evidence: New campaigns default to DRAFT; Flutter only fetches ACTIVE
Problem: No approval endpoint or UI. NGOs cannot activate their own campaigns without direct DB access or abusing PATCH
/campaigns/:id.
────────────────────────────────────────
Feature: Task list (Volunteer)
Status: ⚠️ PARTIAL
Evidence: GET /tasks/available → DB returns OPEN tasks with coords
Problem: Data is correct but navigation from list is broken (see Bug #1).
────────────────────────────────────────
Feature: Task detail (Volunteer)
Status: ⚠️ PARTIAL
Evidence: VolunteerTaskDetailScreen exists and is correct
Problem: Route /tasks/:id is not registered in GoRouter. Navigation crashes.
────────────────────────────────────────
Feature: Create task (Beneficiary)
Status: ✅ COMPLETE
Evidence: CreateTaskScreen → POST /tasks → DB with PostGIS
Problem: Full round-trip including map picker and Zod validation.
────────────────────────────────────────
Feature: Claim task (Volunteer)
Status: ⚠️ PARTIAL
Evidence: POST /tasks/:id/claim uses FOR UPDATE transaction
Problem: Backend correct and race-safe. Unreachable from UI due to broken task-detail route.
────────────────────────────────────────
Feature: Start task (CLAIMED→IN_PROGRESS)
Status: 💀 FAKE
Evidence: \_ActionBar "Start Task" button: onPressed: () {}
Problem: No-op. No backend endpoint for /tasks/:id/start. Volunteer stuck at CLAIMED forever.
────────────────────────────────────────
Feature: Unclaim task
Status: 💀 FAKE
Evidence: \_ActionBar "Unclaim" button: onPressed: () {}
Problem: No-op. ApiConstants.unclaimTask defined but backend route does not exist.
────────────────────────────────────────
Feature: Beneficiary "My Requests" list
Status: ⚠️ PARTIAL
Evidence: Calls /tasks/available then filters createdBy == userId client-side
Problem: Only OPEN tasks returned. Task vanishes from list the moment a volunteer claims it. Filters on created_by not
beneficiary_id.
────────────────────────────────────────
Feature: Proof / delivery upload
Status: 💀 FAKE
Evidence: ProofUploadScreen sends multipart/form-data with binary photos
Problem: Backend schema expects { photo_urls: string[] } (Cloudinary URLs). No Cloudinary step exists anywhere. Zod rejects the

    request immediately. UI also unreachable (requires IN_PROGRESS status, which is unachievable).

────────────────────────────────────────
Feature: Delivery verification (Coordinator)
Status: ⚠️ PARTIAL
Evidence: POST /deliveries/:id/verify + transaction logic is correct
Problem: Jurisdiction check queries tasks WHERE coordinator_id = $verifier. No API exists to set coordinator_id on a task.
Every
COORDINATOR verify attempt returns 403.
────────────────────────────────────────
Feature: Donation creation
Status: ⚠️ PARTIAL
Evidence: POST /donations creates PENDING record in transaction
Problem: Campaign status validated. Amount recorded. But no Stripe PaymentIntent created and no payment actually occurs.
────────────────────────────────────────
Feature: Stripe payment flow
Status: 💀 FAKE
Evidence: paymentIntentClientSecret declared then never assigned
Problem: Always null. Passed as '' to Stripe SDK → SDK error if key set. If key not set, block is skipped entirely. Donation
recorded as PENDING with no payment.
────────────────────────────────────────
Feature: Stripe webhook
Status: ❌ MISSING
Evidence: No POST /webhook/stripe route in server.ts
Problem: Cannot confirm donations automatically.
────────────────────────────────────────
Feature: Donation confirmation
Status: ⚠️ PARTIAL
Evidence: POST /donations/:id/confirm exists and runs transaction
Problem: Requires ADMIN or COORDINATOR auth. No webhook path. Manually called only. Donations stay PENDING indefinitely in
practice.
────────────────────────────────────────
Feature: Donation history (Donor)
Status: ✅ COMPLETE
Evidence: myDonationsProvider → GET /donations/mine → DB
Problem: Full round-trip. History displays correctly. raised_pkr never updates but history itself works.
────────────────────────────────────────
Feature: Chat room creation
Status: 💀 FAKE
Evidence: ChatController reads const { taskId } = req.body
Problem: Flutter sends task_id (snake_case). taskId is undefined. task_events insert fails NOT NULL constraint. Every room
create returns 500.
────────────────────────────────────────
Feature: Chat messaging (REST)
Status: ⚠️ PARTIAL
Evidence: POST /chat/rooms/:roomId/messages works if room exists
Problem: Room never exists (creation always fails).
────────────────────────────────────────
Feature: Chat real-time (Socket.IO)
Status: ⚠️ PARTIAL
Evidence: Gateway JWT auth, join_room access check, broadcast all correct
Problem: Access check queries task_id which is NULL on all rooms → join always denied.
────────────────────────────────────────
Feature: Chat nav from dashboard shell
Status: 💀 FAKE
Evidence: \_beneficiaryNav / \_volunteerNav: context.go('/chat/0')
Problem: Hardcoded taskId = 0. FK constraint on chat_rooms.task_id would reject 0. Chat is never accessible from the nav bar.
────────────────────────────────────────
Feature: Task events / audit trail
Status: ✅ COMPLETE
Evidence: Written on create, claim, submit, verify
Problem: Correct data. Unused in UI but DB integrity is sound.
────────────────────────────────────────
Feature: Task view tracking
Status: ✅ COMPLETE
Evidence: recordView uses ON CONFLICT DO UPDATE
Problem: Correct upsert.
────────────────────────────────────────
Feature: NGO dashboard (Flutter)
Status: ❌ MISSING
Evidence: Role falls to default in DashboardShell.\_buildNavBar
Problem: Generic TasksScreen shown. No campaign management, no volunteer oversight.
────────────────────────────────────────
Feature: Coordinator dashboard (Flutter)
Status: ❌ MISSING
Evidence: Same as NGO
Problem: No delivery queue, no verification UI.
────────────────────────────────────────
Feature: Admin tools (Flutter)
Status: ❌ MISSING
Evidence: No admin routes or screens
Problem: Only manual API calls possible.
────────────────────────────────────────
Feature: campaigns.spent_pkr tracking
Status: ❌ MISSING
Evidence: Column in DB, never written
Problem: Stays 0 forever. Not updated on task payment or delivery.
────────────────────────────────────────
Feature: ngo_profiles.wallet_balance
Status: ❌ MISSING
Evidence: Column in DB, never read or written
Problem: Dead field.
────────────────────────────────────────
Feature: FCM push notifications
Status: ❌ MISSING
Evidence: fcm_token column in users table, never populated
Problem: No push route, no notification logic.
────────────────────────────────────────
Feature: PDF receipt download
Status: 💀 FAKE
Evidence: DonationHistoryScreen: SnackBar('PDF download coming soon.')
Problem: Literal stub.

---

3. Broken Flows — Step-by-Step Failure Points

A. Donor Flow

Register → Login → Browse Campaigns → Donate → Payment → Confirmation

┌──────────────────┬────────┬──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Step │ Status │ Failure Point │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Register │ ✅ │ Works │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Login │ ✅ │ Works │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Browse campaigns │ ✅ │ GET /campaigns?status=ACTIVE returns data │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tap campaign → │ ✅ │ GoRouter /donor/payment/:id is registered │
│ payment screen │ │ │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Select amount │ ✅ │ UI works │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tap "Pay │ │ paymentIntentClientSecret is null (line 53 payment_screen.dart). If STRIPE_PK is set, Stripe │
│ Securely" │ 💀 │ sheet initialized with empty clientSecret → SDK immediately throws. If STRIPE_PK not set, │
│ │ │ Stripe block is skipped. Either way, donate() is called with gatewayRef: null. │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Donation │ ⚠️ │ POST /donations succeeds. Status = PENDING. raised_pkr on campaign unchanged. │
│ recorded │ │ │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Confirmation │ ✅ │ Success view is shown (falsely, since no payment occurred) │
│ screen │ │ │
├──────────────────┼────────┼──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Donation │ │ │
│ actually │ 💀 │ Never happens. No webhook. Manual admin call required. │
│ confirmed │ │ │
└──────────────────┴────────┴──────────────────────────────────────────────────────────────────────────────────────────────┘

Root break: No backend endpoint to create a Stripe PaymentIntent. paymentIntentClientSecret is never populated.

---

B. Volunteer Flow

Login → See tasks → Claim → Start → Upload Proof → Verification → Paid

┌────────────────────────┬────────┬────────────────────────────────────────────────────────────────────────────────────────┐
│ Step │ Status │ Failure Point │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ Login │ ✅ │ Works │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ See task list at │ ✅ │ GET /tasks/available returns correct data │
│ /volunteer/tasks │ │ │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ Tap task card │ 💀 │ context.push('/tasks/${task.id}') — no GoRouter route for /tasks/:id registered. │
│ │ │ GoRouter throws. │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ View task detail │ 💀 │ Unreachable due to broken route above │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ Claim task │ 💀 │ Unreachable from UI. Backend POST /tasks/:id/claim is sound. │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ "Start Task" button │ 💀 │ onPressed: () {} — explicit no-op. Backend endpoint does not exist. │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ Status reaches │ ❌ │ Never happens. │
│ IN_PROGRESS │ │ │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ "Upload Proof" button │ ❌ │ if (isInProgress && isClaimedByMe) — condition never true. │
│ visible │ │ │
├────────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────┤
│ │ │ Even if reached directly via URL: Flutter sends multipart/form-data binary files; │
│ Submit proof │ 💀 │ backend schema requires { photo_urls: string[] } (Cloudinary URLs). Zod rejects with │
│ │ │ 400. │
└────────────────────────┴────────┴────────────────────────────────────────────────────────────────────────────────────────┘

Root breaks: (1) Wrong route path in TasksScreen tap handler. (2) No /tasks/:id/start backend endpoint + button is a no-op. (3)
Cloudinary upload step entirely absent.

---

C. NGO Flow

Create Campaign → Create Tasks → Track Donations → Manage Volunteers

┌────────────────────┬────────┬────────────────────────────────────────────────────────────────────────────────────────────┐
│ Step │ Status │ Failure Point │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Login as NGO │ ✅ │ Works │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ NGO dashboard │ ❌ │ Falls to default case in shell. Sees generic task list. No campaign UI. │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create campaign │ ⚠️ │ Backend POST /campaigns works correctly. No Flutter screen exists. │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ New campaign │ ❌ │ Default status is DRAFT. Flutter filters for ACTIVE only. Campaign invisible until status │
│ visible │ │ changed. │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Approve campaign │ ❌ │ No approval endpoint or UI. NGO could PATCH their own campaign to ACTIVE (update endpoint │
│ to ACTIVE │ │ has no ownership check), but this bypasses intended workflow. │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create tasks for │ ⚠️ │ Beneficiary create task screen works but is BENEFICIARY-role-specific. NGO task creation │
│ campaign │ │ has no UI. │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Track donations to │ ❌ │ GET /donations/campaign/:id exists on backend. No NGO Flutter screen to call it. │
│ campaign │ │ │
├────────────────────┼────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Manage volunteers │ ❌ │ No endpoint. No UI. │
└────────────────────┴────────┴────────────────────────────────────────────────────────────────────────────────────────────┘

---

D. Chat Flow

Open chat → Create/join room → Send message → Real-time sync → Persistence

┌─────────────────────────────────────┬────────┬───────────────────────────────────────────────────────────────────────────┐
│ Step │ Status │ Failure Point │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ Navigate to chat from task detail │ ⚠️ │ Task detail itself unreachable for volunteers. Beneficiary/volunteer nav │
│ │ │ bar sends /chat/0. │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ ChatScreen._ensureRoom() called │ 💀 │ repo.ensureRoom(taskId) posts { 'task_id': taskId } │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ Server receives room create │ 💀 │ const { taskId } = req.body — destructures taskId (camelCase). Flutter │
│ │ │ sends task_id (snake_case). taskId = undefined. │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ chatService.createRoom(undefined, │ │ INSERT into chat_rooms with task_id = NULL succeeds (nullable). INSERT │
│ userId) │ 💀 │ into task_events with task_id = NULL fails NOT NULL constraint. Service │
│ │ │ throws. Controller returns 500. │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ \_roomId is set │ 💀 │ catch (_) sets \_initializingRoom = false but \_roomId stays null. Screen │
│ │ │ shows "Could not open chat room." │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ Socket join_room │ ❌ │ Never reached. │
├─────────────────────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────┤
│ Message send │ ❌ │ Never reached. │
└─────────────────────────────────────┴────────┴───────────────────────────────────────────────────────────────────────────┘

Root break: task_id vs taskId key mismatch in chat.controller.ts line 9. Single character difference, complete system failure.

---

4. Critical Bugs (P0 / P1)

P0 — Complete Feature Failure

Bug 1: Volunteer task navigation crashes

- File: flutter_app/lib/features/tasks/presentation/tasks_screen.dart:100
- Code: context.push('/tasks/${task.id}')
- Fact: GoRouter has no route for /tasks/:id. Routes are /volunteer/task/:id, /dashboard, /tasks (list only). GoRouter throws
  an unhandled exception.
- Fix: Change to context.push('/volunteer/task/${task.id}').

Bug 2: Chat room creation always returns 500

- File: backend/src/modules/chat/chat.controller.ts:9
- Code: const { taskId } = req.body;
- Fact: Flutter sends task_id. Destructure gets undefined. task_events insert violates NOT NULL on task_id. 500 on every call.
- Fix: Change to const taskId = req.body.task_id ?? req.body.taskId;.

Bug 3: Stripe payment is non-functional

- File: flutter_app/lib/screens/donor/payment_screen.dart:53
- Code: String? paymentIntentClientSecret; — declared, never assigned.
- Fact: No backend endpoint creates a PaymentIntent. All donations stay PENDING. raised_pkr never updates.
- Fix: Add POST /api/stripe/create-payment-intent backend endpoint; assign the returned clientSecret before initializing Stripe
  sheet.

Bug 4: Proof upload body format completely wrong

- File: flutter_app/lib/screens/volunteer/proof_upload_screen.dart:118–145
- Code: Sends FormData with binary MultipartFile objects under key photos.
- Fact: Backend schema (deliveries.schema.ts:4) expects photo_urls: z.array(z.string().url()) in a JSON body. Zod rejects
  with 422. No Cloudinary upload step exists anywhere in the codebase.
- Fix: Upload photos to Cloudinary first, collect returned URLs, then POST { task_id, photo_urls, latitude, longitude, notes }
  as JSON.

---

P1 — Critical Flow Break

Bug 5: "Start Task" and "Unclaim" buttons are no-ops

- File: flutter_app/lib/screens/volunteer/task_detail_screen.dart:441, 447
- Code: Both buttons: onPressed: () {}
- Fact: ApiConstants.startTask and ApiConstants.unclaimTask are defined but no backend routes exist for them. Volunteer cannot
  progress past CLAIMED status. "Upload Proof" button is permanently hidden.
- Fix: Add POST /tasks/:id/start and POST /tasks/:id/unclaim backend endpoints; wire buttons.

Bug 6: Beneficiary task list loses tasks after claiming

- File: flutter_app/lib/providers/beneficiary_task_provider.dart:13–19
- Code: Calls GET /tasks/available (OPEN only), then tasks.where((t) => t.createdBy == userId)
- Fact: Backend returns only status = 'OPEN'. Once a volunteer claims the task, it disappears from the beneficiary's view
  permanently. Also, createdBy is the form creator, not necessarily beneficiary_id.
- Fix: Add GET /api/tasks/my endpoint that returns all tasks where beneficiary_id = req.user.id regardless of status.

Bug 7: Coordinator can never verify a delivery

- File: backend/src/modules/deliveries/deliveries.service.ts:103–108
- Code: SELECT 1 FROM tasks WHERE id = $1 AND coordinator_id = $2
- Fact: No API endpoint exists to set coordinator_id on a task. The field is set only at task creation and the createTaskSchema
  doesn't expose it to the caller. COORDINATOR role gets 403 on every verify attempt.
- Fix: Add coordinator_id to updateTaskSchema (restricted to NGO/ADMIN), allowing assignment before delivery begins.

Bug 8: Chat dashboard nav sends taskId = 0

- File: flutter_app/lib/core/shell/dashboard_shell.dart:151, 162
- Code: context.go('/chat/0') in both beneficiary and volunteer nav handlers.
- Fact: ensureRoom(0) → FK constraint violation on chat_rooms.task_id → 500. Chat is unreachable from the dashboard nav
  entirely.
- Fix: The chat nav button should only be enabled in context of a specific task. Alternatively, route to a room-list screen
  (GET /chat/rooms), then enter a specific room.

Bug 9: Task update has no ownership check

- File: backend/src/modules/tasks/tasks.routes.ts:48–54, backend/src/modules/tasks/tasks.service.ts:133
- Code: authorize('NGO', 'COORDINATOR', 'ADMIN') but no WHERE created_by = $userId check in update query.
- Fact: Any authenticated NGO can call PATCH /api/tasks/:id with any task ID and modify it, including changing title,
  description, budget_pkr, urgency, and GPS coordinates. Cross-tenant data mutation.
- Fix: Add AND created_by = $userId (or join through ngo_profiles) to the UPDATE WHERE clause for NGO role.

---

5. Missing Work (Not Stubbed — Simply Absent)

┌──────────────────────────────┬─────────┬─────────────────────────────────────────────────────────────────────────────────┐
│ Item │ Layer │ What's Needed │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Stripe PaymentIntent │ Backend │ POST /api/stripe/create-payment-intent → stripe.paymentIntents.create() → │
│ creation │ │ return client_secret │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Stripe webhook handler │ Backend │ POST /api/webhook/stripe → verify signature → call confirmDonation() │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ POST /tasks/:id/start │ Backend │ Transition CLAIMED → IN_PROGRESS; validate claimed_by == req.user.id │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ POST /tasks/:id/unclaim │ Backend │ Transition CLAIMED → OPEN; clear claimed_by; reset volunteer status │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ GET /api/tasks/my │ Backend │ Return all tasks where beneficiary_id = req.user.id, all statuses │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Cloudinary upload service │ Backend │ Endpoint or middleware to receive photo files, upload to Cloudinary, return │
│ │ │ URLs │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Campaign approval endpoint │ Backend │ POST /campaigns/:id/approve (ADMIN/COORDINATOR only) → set status ACTIVE │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ coordinator_id assignment │ Backend │ Add to updateTaskSchema; restrict to NGO/ADMIN role │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ NGO dashboard screens │ Flutter │ Campaign creation form, task management, donation tracking │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Coordinator dashboard │ Flutter │ Delivery queue, verify/reject UI │
│ screens │ │ │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Admin panel │ Flutter │ Donation confirmation, user management │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ campaigns.spent_pkr update │ Backend │ Add to verifyDelivery transaction when budget_pkr is credited │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ ngo_profiles.wallet_balance │ Backend │ Update when campaign receives donation (optional, but field is dead) │
├──────────────────────────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────┤
│ Chat validation middleware │ Backend │ Chat routes have no Zod validation; createRoom accepts any body │
└──────────────────────────────┴─────────┴─────────────────────────────────────────────────────────────────────────────────┘

---

6. Recommended Fix Order

Ordered strictly by: blocking other features → data correctness → completeness.

┌──────────┬──────────────────────────────────────────────────────────────┬────────────────────────────────────────────────┐
│ Priority │ Fix │ Why First │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 1 │ Fix context.push('/tasks/${task.id}') → /volunteer/task/ │ Unblocks all volunteer interactions. One-line │
│ │ │ change. │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 2 │ Fix chat taskId → task_id in chat.controller.ts │ Unblocks all chat. One-line change. │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 3 │ Fix chat nav from /chat/0 → room list or task-scoped entry │ Makes chat actually reachable │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 4 │ Add POST /tasks/:id/start + wire "Start Task" button │ Unblocks proof upload, delivery, verification │
│ │ │ entire chain │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 5 │ Add POST /tasks/:id/unclaim + wire "Unclaim" button │ Allows recovery from bad claims │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 6 │ Add Cloudinary upload step to proof upload │ Fix body format mismatch; change photo_urls to │
│ │ │ actual upload │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 7 │ Add GET /api/tasks/my + update │ Fixes beneficiary visibility across all │
│ │ beneficiary_task_provider.dart │ statuses │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 8 │ Add ownership check to PATCH /tasks/:id │ Security: prevents cross-NGO task mutation │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 9 │ Add coordinator_id to updateTaskSchema │ Unblocks coordinator verification flow │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 10 │ Add POST /stripe/create-payment-intent + assign clientSecret │ Fixes the payment flow; donations move from │
│ │ in Flutter │ fake to real │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 11 │ Add POST /webhook/stripe to auto-confirm donations │ Removes manual admin dependency for every │
│ │ │ payment │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 12 │ Add campaign approval flow │ NGOs can actually go live without DB access │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 13 │ Build NGO dashboard (campaign creation, task management) │ Closes the NGO role entirely │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 14 │ Build coordinator dashboard (delivery queue, verify UI) │ Closes the coordinator role │
├──────────┼──────────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ 15 │ Update campaigns.spent_pkr in verifyDelivery transaction │ Data integrity │
└──────────┴──────────────────────────────────────────────────────────────┴────────────────────────────────────────────────┘
