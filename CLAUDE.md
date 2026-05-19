# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DisasterAid.pk V2.1 — A humanitarian platform connecting NGOs, Donors, Volunteers, Coordinators, and Beneficiaries for disaster relief in Pakistan. Roles: `ADMIN`, `NGO`, `COORDINATOR`, `VOLUNTEER`, `DONOR`, `BENEFICIARY`.

## Repository Structure

```
disasteraid-v2/
├── backend/          # Node.js + Express + TypeScript API (ESM)
├── flutter_app/      # Flutter 3.22 mobile app (Riverpod + go_router)
├── admin-panel/      # React 19 + Vite + Ant Design web panel
└── database/         # PostgreSQL migration files (run in order 001–010)
```

## Development Commands

### Backend (`cd backend`)
```bash
npm run dev          # nodemon + tsx hot reload on port 3000
npm run build        # tsc compile → dist/
npm test             # Jest with coverage (requires PostgreSQL)
npm run test:race    # Race condition test only
npm run lint         # ESLint on src/
```

### Admin Panel (`cd admin-panel`)
```bash
npm run dev          # Vite dev server (port 5173)
npm run build        # tsc + vite build
npm run lint         # ESLint
```

### Flutter (`cd flutter_app`)
```bash
flutter pub get
flutter run                    # Run on connected device/emulator
flutter test --coverage        # Run all tests
flutter analyze                # Static analysis (must stay at 0 issues)
dart run build_runner build    # Regenerate code (freezed, json_serializable, riverpod_generator)
```

### Docker (full stack)
```bash
docker-compose up -d                    # DB + backend
docker-compose --profile web up -d     # Include Flutter web
```

### Database (manual setup)
```bash
# Apply migrations in order — each file is cumulative
psql -U disasteraid_user -d disasteraid -f database/001_init.sql
# ... through 010_goods_campaigns.sql
```

## Architecture

### Backend
- Entry point: `backend/src/server.ts` — exports `app` and `httpServer`; actual server start is in `src/index.ts`
- Pattern: `modules/<name>/` containing `*.routes.ts`, `*.controller.ts`, `*.schema.ts` (Zod), `*.service.ts`
- All routes are prefixed `/api/<module>` — see `server.ts` for full mount list
- `authenticate` middleware always fetches role from DB (never trusts client-supplied role)
- `authorize(...roles)` middleware enforces RBAC after `authenticate`
- Input validated with Zod via `validate({ body, params, query })` middleware
- Direct `pg.Pool` queries — no ORM; use parameterized `$1, $2` everywhere
- Task claim uses `SELECT ... FOR UPDATE` inside an explicit transaction for race-condition safety
- Cloudinary for media uploads; Stripe for payment intents; Winston for structured logging; opossum for circuit breakers

### Flutter App
- State management: Riverpod 2.5 (providers in `lib/providers/`, generated providers via `riverpod_generator`)
- Navigation: go_router (`lib/core/router/app_router.dart`) — role-based redirect on auth state change
- API client: Dio (`lib/core/api/`) — base URL in `ApiConstants.baseUrl` (currently `localhost:3000/api`; change to `10.0.2.2:3000/api` for Android emulator)
- Auth token in `flutter_secure_storage`; auth state in `authProvider`
- Screen organization: `lib/screens/<role>/` — each role has its own folder
- `DashboardShell` (`lib/core/shell/`) provides the bottom nav bar per role via `ShellRoute`
- Models use `freezed` + `json_serializable`; run `build_runner` after model changes

### Admin Panel
- React 19 + React Query + Ant Design v6 + React Router v7
- API calls via axios in `src/api/`; all endpoint strings in `src/api/endpoints.ts`
- Auth context in `src/auth/AuthContext.tsx`; `ProtectedRoute` wraps all authenticated routes
- Two roles use this panel: `ADMIN` (full access) and `NGO` (own campaigns/tasks/goods)
- NGO routes live under `/ngo/` prefix; admin routes are flat under `/`

### Database
- PostgreSQL 16 + PostGIS 3
- Schema built from sequential migration files `database/001_init.sql` → `010_goods_campaigns.sql`
- Docker mounts all files into `docker-entrypoint-initdb.d/` so they auto-apply on first start
- Finance ledger is manual (BANK_TRANSFER approve/reject flow); no automatic Stripe reconciliation in DB

## Environment Variables

Backend reads from `.env` (root or `backend/`). Required variables validated by Zod in `backend/src/config/env.ts`:

| Variable | Notes |
|---|---|
| `POSTGRES_PASSWORD` | Required, no default |
| `JWT_SECRET` | Min 32 chars |
| `CORS_ORIGINS` | Comma-separated; in dev, all origins allowed |
| `CLOUDINARY_*` | Optional; media uploads disabled if blank |
| `STRIPE_SECRET_KEY` | Optional; Stripe flows disabled if blank |
| `SOCKET_CORS_ORIGIN` | Defaults to `http://localhost:8080` |

## Key Constraints

- **Admin accounts cannot be created via API** — seed them directly in the DB
- **Flutter analyzer must stay at 0 issues** — run `flutter analyze` before committing Flutter changes
- **Backend uses ESM** (`"type": "module"`) — imports must use `.js` extensions even for `.ts` source files
- **Task claim is the only operation using explicit transactions** — do not simplify it
- **Role is always read from DB on each request** — the JWT only contains `userId`
