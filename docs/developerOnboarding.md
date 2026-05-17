---

DisasterAid V2.1 — Full Developer Onboarding

---

1. Architecture Understanding

System Overview

Flutter App ──HTTP/REST──► Express API (Node 20 + TypeScript) ──SQL──► PostgreSQL 16 + PostGIS
│ │
└──Socket.IO (real-time)───────┘

This is a humanitarian relief platform with six user roles: DONOR, BENEFICIARY, VOLUNTEER, NGO, COORDINATOR, ADMIN.

---

How Flutter Communicates with the Backend

Client stack: Dio HTTP client wrapped in ApiClient (flutter_app/lib/core/api/api_client.dart)

Request pipeline (in order):

Request
→ RetryInterceptor — exponential backoff on network errors (GET only, max 3 retries)
→ AuthInterceptor — attaches "Authorization: Bearer <token>" from flutter_secure_storage
→ LogInterceptor — scrubs passwords from debug logs
→ Backend
← 401 response — clears token, redirects to /login

Base URL is compiled in at build time via --dart-define:
// flutter_app/lib/config/env.dart
static const String apiUrl = String.fromEnvironment(
'API_URL',
defaultValue: 'https://api.disasteraid.pk/api', // ← prod default, NOT localhost
);

▎ Critical for local dev: You must pass --dart-define=API_URL=http://10.0.2.2:3000/api (Android emulator) or
▎ http://localhost:3000/api (web/iOS sim) when running locally. The default will hit prod.

Real-time: socket_io_client connects to the same host, authenticated via JWT query param.

---

How Backend Communicates with PostgreSQL

- Driver: pg (node-postgres) with a connection pool (backend/src/config/database.ts)
- Pool: max 20 connections, 30 s idle timeout
- All queries are parameterized ($1, $2, …) — no raw string interpolation
- Transactions used for: donation confirmation, task claiming (row-level lock)
- PostGIS Geography(Point, 4326) columns used for geo-queries on tasks, campaigns, volunteers

---

API Structure

backend/src/
├── index.ts ← binds httpServer to port
├── server.ts ← Express + Socket.IO wiring, all middleware, all routes mounted
├── config/
│ ├── env.ts ← Zod-validated env (crashes on startup if invalid)
│ ├── database.ts ← pg Pool singleton
│ └── circuitBreaker.ts ← opossum factory for external calls (Stripe, Cloudinary)
├── middleware/
│ ├── auth.ts ← verifies JWT, fetches role from DB (never trusts client claim)
│ ├── authorize.ts ← RBAC guard factory: authorize('NGO','ADMIN')
│ ├── validate.ts ← Zod schema validator factory
│ ├── rateLimiter.ts ← 100 req / 15 min / IP
│ └── errorHandler.ts ← global Express error handler
└── modules/
├── auth/ ← register, login, /me
├── tasks/ ← CRUD + claim (race-safe) + event log
├── campaigns/ ← NGO relief campaigns
├── donations/ ← Stripe + manual bank transfer
├── deliveries/ ← volunteer proof upload + coordinator verify
└── chat/ ← REST rooms/messages + Socket.IO gateway

Each module follows the pattern: routes.ts → controller.ts → service.ts. Controllers only handle HTTP concerns;
services own all business logic and DB access.

---

Database Schema

14 tables. Key relationships:

roles ──< users ──< ngo_profiles
──< volunteer_profiles
──< tasks (as beneficiary / creator / claimer / coordinator)
──< donations
──< chat_rooms / chat_messages

campaigns ──< tasks ──< task_events
──< task_views
──< deliveries
──< chat_rooms

donations ──> campaigns (raises raised_pkr atomically)
ledger_entries (polymorphic audit trail for all money movement)
app_config (single-row global settings: disaster_mode flag)

---

2. Dependency Mapping

Backend (backend/package.json)

┌────────────────────┬────────────────┬──────────────────────────────┐
│ Package │ Version │ Purpose │
├────────────────────┼────────────────┼──────────────────────────────┤
│ express │ 4.21.0 │ HTTP framework │
├────────────────────┼────────────────┼──────────────────────────────┤
│ typescript + tsx │ 5.6.0 / 4.21.0 │ Type system / dev runner │
├────────────────────┼────────────────┼──────────────────────────────┤
│ pg │ 8.13.0 │ PostgreSQL client │
├────────────────────┼────────────────┼──────────────────────────────┤
│ socket.io │ 4.8.0 │ Real-time WebSocket │
├────────────────────┼────────────────┼──────────────────────────────┤
│ jsonwebtoken │ 9.0.2 │ JWT auth │
├────────────────────┼────────────────┼──────────────────────────────┤
│ bcrypt │ 5.1.1 │ Password hashing (12 rounds) │
├────────────────────┼────────────────┼──────────────────────────────┤
│ zod │ 3.23.8 │ Schema validation │
├────────────────────┼────────────────┼──────────────────────────────┤
│ multer │ 1.4.5-lts.1 │ File upload (multipart) │
├────────────────────┼────────────────┼──────────────────────────────┤
│ stripe │ 17.3.0 │ Payment processing │
├────────────────────┼────────────────┼──────────────────────────────┤
│ cloudinary │ 2.5.1 │ Image CDN │
├────────────────────┼────────────────┼──────────────────────────────┤
│ helmet │ 8.0.0 │ Security headers │
├────────────────────┼────────────────┼──────────────────────────────┤
│ express-rate-limit │ 7.4.1 │ Rate limiting │
├────────────────────┼────────────────┼──────────────────────────────┤
│ opossum │ 9.0.0 │ Circuit breaker │
├────────────────────┼────────────────┼──────────────────────────────┤
│ dotenv │ 16.4.5 │ Env loading │
├────────────────────┼────────────────┼──────────────────────────────┤
│ uuid │ 10.0.0 │ UUID generation │
├────────────────────┼────────────────┼──────────────────────────────┤
│ cors │ 2.8.5 │ CORS middleware │
├────────────────────┼────────────────┼──────────────────────────────┤
│ nodemon + ts-node │ dev only │ Dev reload │
└────────────────────┴────────────────┴──────────────────────────────┘

Frontend (flutter_app/pubspec.yaml)

┌────────────────────────┬─────────┬─────────────────────────────────┐
│ Package │ Version │ Purpose │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ flutter_riverpod │ 2.5.1 │ State management │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ dio │ 5.7.0 │ HTTP client │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ flutter_secure_storage │ 9.2.2 │ Keychain/Keystore token storage │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ go_router │ 14.3.0 │ Declarative routing │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ flutter_map │ 7.0.2 │ Map display │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ flutter_stripe │ 10.2.0 │ Stripe payment UI │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ socket_io_client │ 2.0.3+1 │ Real-time chat │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ image_picker │ 1.1.2 │ Camera / gallery │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ geolocator │ 13.0.1 │ GPS │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ flutter_form_builder │ 10.0.1 │ Form handling │
├────────────────────────┼─────────┼─────────────────────────────────┤
│ intl │ 0.20.2 │ i18n / date formatting │
└────────────────────────┴─────────┴─────────────────────────────────┘

External Services

┌───────────────────────────┬────────────────┬───────────────────────────────────┐
│ Service │ Required │ Notes │
├───────────────────────────┼────────────────┼───────────────────────────────────┤
│ PostgreSQL 16 + PostGIS 3 │ Required │ Core data store │
├───────────────────────────┼────────────────┼───────────────────────────────────┤
│ Cloudinary │ Optional (dev) │ Photo uploads for delivery proofs │
├───────────────────────────┼────────────────┼───────────────────────────────────┤
│ Stripe │ Optional (dev) │ Donation payments │
└───────────────────────────┴────────────────┴───────────────────────────────────┘

Required Environment Variables

Only these two are hard required at startup (the Zod schema will process.exit(1) if missing):

POSTGRES_PASSWORD (min 1 char)
JWT_SECRET (min 32 chars)

All others have defaults. Full list in .env.example.

---

3. Development Setup

Prerequisites

Node.js 20+
npm 10+
Docker Desktop (recommended) OR local PostgreSQL 16 + PostGIS
Flutter SDK 3.24+ (stable channel)

---

Option A — Docker (Recommended, runs Postgres + Backend together)

Step 1: Clone and create your .env
git clone <repo-url>
cd disasteraid-v2
cp .env.example .env

Step 2: Edit .env — change these two values at minimum:
POSTGRES_PASSWORD=any_local_password_here
JWT_SECRET=any_random_string_at_least_32_characters_long

For local dev, change POSTGRES_HOST to match Docker networking:
POSTGRES_HOST=postgres # stays as "postgres" when backend runs inside Docker

Step 3: Start Postgres + Backend
docker compose up --build

This will:

- Pull postgis/postgis:16-3.4
- Run database/001_init.sql automatically (creates all tables, seeds roles + admin)
- Build and start the backend on port 3000
- Wait for Postgres health check before starting backend

Step 4: Verify
curl http://localhost:3000/api/health

# Expected: {"status":"healthy","timestamp":"...","version":"2.1.0","database":"connected"}

To include the Flutter web build:
docker compose --profile web up --build

# Flutter web served at http://localhost:8080

---

Option B — Manual Setup (Backend without Docker)

Step 1: Start PostgreSQL locally

With Docker (Postgres only):
docker run -d \
 --name disasteraid-db \
 -e POSTGRES_DB=disasteraid \
 -e POSTGRES_USER=disasteraid_user \
 -e POSTGRES_PASSWORD=localpassword \
 -p 5432:5432 \
 postgis/postgis:16-3.4

Or if you have PostgreSQL installed locally:
-- in psql as superuser:
CREATE USER disasteraid_user WITH PASSWORD 'localpassword';
CREATE DATABASE disasteraid OWNER disasteraid_user;
\c disasteraid
CREATE EXTENSION IF NOT EXISTS postgis;

Step 2: Apply schema + seed data
psql -h localhost -U disasteraid_user -d disasteraid -f database/001_init.sql

Default seeded admin credentials:
email: admin@disasteraid.pk
password: (bcrypt hash in SQL — check 001_init.sql for the plaintext or reset it)

Step 3: Install backend dependencies
cd backend
npm install

Step 4: Create backend .env
cp ../.env.example .env

Edit backend/.env (or use the root .env, the backend reads from wherever dotenv.config() finds it — the entry point
index.ts is in src/, so dotenv looks at backend/.env or you pass dotenv.config({ path: '../.env' })):

▎ Note: The root .env.example is at the repo root. The backend's dotenv.config() runs from src/index.ts → finds .env
▎ relative to process.cwd(). When you run npm run dev from backend/, process.cwd() is backend/, so place your .env
▎ inside backend/.

POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=disasteraid
POSTGRES_USER=disasteraid_user
POSTGRES_PASSWORD=localpassword
PORT=3000
NODE_ENV=development
JWT_SECRET=dev_secret_key_at_least_32_chars_long
JWT_EXPIRES_IN=1h
CORS_ORIGINS=http://localhost:8080,http://localhost:3000
SOCKET_CORS_ORIGIN=http://localhost:8080
CLOUDINARY_CLOUD_NAME=dummy
CLOUDINARY_API_KEY=dummy
CLOUDINARY_API_SECRET=dummy
STRIPE_SECRET_KEY=sk_test_dummy

Step 5: Run dev server
cd backend
npm run dev

# uses: nodemon --exec "tsx src/index.ts"

# auto-reloads on .ts file changes

---

Frontend (Flutter)

Step 1: Get dependencies
cd flutter_app
flutter pub get

Step 2: Run on Android Emulator
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api

Step 3: Run on iOS Simulator
flutter run --dart-define=API_URL=http://localhost:3000/api

Step 4: Run as Flutter Web
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api

▎ If you skip --dart-define=API_URL, the app defaults to https://api.disasteraid.pk/api (production URL) and nothing
▎ will work locally.

For Socket.IO, the Flutter app connects to the same base URL. Make sure SOCKET_CORS_ORIGIN in your backend .env
includes whatever origin your Flutter web app runs on (e.g., http://localhost:8080).

---

4. Docker Analysis

What docker-compose.yml covers:

┌─────────────┬─────────────┬──────────────────────────────────────────────────────┐
│ Service │ Included │ Notes │
├─────────────┼─────────────┼──────────────────────────────────────────────────────┤
│ postgres │ Yes, always │ PostGIS 16-3.4, auto-runs init SQL, healthcheck │
├─────────────┼─────────────┼──────────────────────────────────────────────────────┤
│ backend │ Yes, always │ Builds from backend/Dockerfile, waits for Postgres │
├─────────────┼─────────────┼──────────────────────────────────────────────────────┤
│ flutter-web │ Yes, opt-in │ --profile web only, needs flutter_app/Dockerfile.web │
└─────────────┴─────────────┴──────────────────────────────────────────────────────┘

Can it replace manual setup? Yes for Postgres + Backend. Run docker compose up --build and the full server stack is
ready in ~2 minutes with zero manual DB setup.

Issues to be aware of:

1. Backend Dockerfile is a production multi-stage build. It runs node dist/index.js (compiled output), not nodemon.
   Hot reload does NOT work inside Docker even though ./backend/src is volume-mounted — the volume mount only helps if
   the CMD were tsx src/index.ts. If you want hot reload, run the backend with npm run dev outside Docker.
2. flutter_app/Dockerfile.web — this file was referenced but was not confirmed to exist. If it's missing, docker
   compose --profile web up will fail with a build context error.
3. Backend's env_file: .env reads the root .env. Make sure it exists before running docker compose up (you copied it
   from .env.example in step 1).
4. POSTGRES_HOST must be postgres (the service name) when backend runs inside Docker, not localhost.

---

5. Issues & Risks

P0 — Security

┌─────┬─────────────────────────────────────────┬─────────────────┬───────────────────────────────────────────────┐
│ # │ Issue │ Location │ Fix │
├─────┼─────────────────────────────────────────┼─────────────────┼───────────────────────────────────────────────┤
│ 1 │ .env committed to Git │ root .env │ Add /.env and backend/.env to .gitignore; │
│ │ │ │ rotate all secrets │
├─────┼─────────────────────────────────────────┼─────────────────┼───────────────────────────────────────────────┤
│ 2 │ JWT*SECRET in .env.example is a │ .env.example:14 │ Replace with CHANGE_ME*... placeholder │
│ │ real-looking string │ │ │
└─────┴─────────────────────────────────────────┴─────────────────┴───────────────────────────────────────────────┘

P1 — Functional Bugs

┌─────┬────────────────────────────────────────────────────────────────────────┬───────────────────────────────────┐
│ # │ Issue │ Location │
├─────┼────────────────────────────────────────────────────────────────────────┼───────────────────────────────────┤
│ 3 │ checkDatabaseHealth() in database.ts likely returns hardcoded true │ backend/src/config/database.ts │
├─────┼────────────────────────────────────────────────────────────────────────┼───────────────────────────────────┤
│ 4 │ Flutter default API_URL points to production — crashes local dev │ flutter_app/lib/config/env.dart:4 │
│ │ silently │ │
├─────┼────────────────────────────────────────────────────────────────────────┼───────────────────────────────────┤
│ 5 │ flutter_app/Dockerfile.web referenced in docker-compose.yml but may │ docker-compose.yml:43 │
│ │ not exist │ │
└─────┴────────────────────────────────────────────────────────────────────────┴───────────────────────────────────┘

P2 — Configuration / Dev Experience

┌─────┬─────────────────────────────────────────────────────────────────────┬─────────────────────────────────────┐
│ # │ Issue │ Location │
├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────┤
│ 6 │ backend/.env location ambiguity — dotenv resolves relative to cwd, │ backend/src/config/env.ts:4 │
│ │ but docs don't clarify │ │
├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────┤
│ 7 │ Backend Dockerfile CMD is node dist/index.js but volume mounts src/ │ docker-compose.yml:36 + │
│ │ — hot reload doesn't actually work in Docker │ backend/Dockerfile │
├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────┤
│ 8 │ eslint.config.js uses ESLint v9 flat config but package.json lint │ backend/package.json:12 │
│ │ script uses --ext .ts (v8 flag — broken) │ │
├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────┤
│ 9 │ BCRYPT_ROUNDS in env.ts has a default but is NOT in .env.example │ backend/src/config/env.ts:22 │
└─────┴─────────────────────────────────────────────────────────────────────┴─────────────────────────────────────┘

P3 — Code Quality

┌─────┬─────────────────────────────────────────────────────────────────┬──────────────────────────────────────────┐
│ # │ Issue │ Location │
├─────┼─────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 10 │ any types bypassing Zod validation exist in schema files │ various \*.schema.ts │
├─────┼─────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 11 │ Socket.IO errors in chat.gateway.ts not propagated to global │ backend/src/modules/chat/chat.gateway.ts │
│ │ error handler │ │
├─────┼─────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 12 │ console.log statements in production code paths │ server.ts:32, others │
├─────┼─────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 13 │ Cloudinary utility configured but delivery proof upload may not │ backend/src/modules/deliveries/ │
│ │ be wired end-to-end │ │
├─────┼─────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 14 │ Inline comment "Ye line hata de abhi" (Urdu: "remove this line │ diagnostic code left in │
│ │ now") left in code │ │
└─────┴─────────────────────────────────────────────────────────────────┴──────────────────────────────────────────┘

---

6. Improvements

Fix the .env situation first

# Add to .gitignore

echo ".env" >> .gitignore
echo "backend/.env" >> .gitignore
git rm --cached .env # stop tracking the root .env
git rm --cached backend/.env # if exists
git commit -m "stop tracking .env files"

Then rotate: POSTGRES_PASSWORD, JWT_SECRET, and any real Cloudinary/Stripe keys that were committed.

---

Add a dev-only docker-compose override

Create docker-compose.dev.yml to override the backend service for hot reload:

# docker-compose.dev.yml

services:
backend:
command: npm run dev
environment:
NODE_ENV: development

Run dev stack with:
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

This keeps the base file clean for CI/production.

---

Add a startup script

Create scripts/dev.sh:
#!/usr/bin/env bash
set -e
[ ! -f .env ] && cp .env.example .env && echo "Created .env from example — edit it before re-running"
docker compose up --build postgres &
echo "Waiting for Postgres..."
until docker compose exec postgres pg_isready -U disasteraid_user; do sleep 1; done
cd backend && npm install && npm run dev

---

Fix the Flutter local URL problem

Change the default in flutter_app/lib/config/env.dart to localhost so developers don't accidentally hit prod:

// flutter_app/lib/config/env.dart
static const String apiUrl = String.fromEnvironment(
'API_URL',
defaultValue: 'http://localhost:3000/api', // ← change to localhost for dev builds
);

Or add a --dart-define to a launch.json in VS Code so it's automatic.

---

Fix the health check

// backend/src/config/database.ts
export async function checkDatabaseHealth(): Promise<boolean> {
try {
const client = await pool.connect();
await client.query('SELECT 1');
client.release();
return true;
} catch {
return false;
}
}

---

Fix the ESLint script

// backend/package.json
"lint": "eslint src/"
Remove --ext .ts — ESLint v9 flat config doesn't use that flag.

---

Summary of "do these first" actions for a new developer

1. cp .env.example .env → set POSTGRES_PASSWORD and JWT_SECRET
2. docker compose up --build → starts DB + API (no installs needed)
3. curl localhost:3000/api/health → verify backend is up
4. cd flutter_app && flutter pub get
5. flutter run --dart-define=API_URL=http://10.0.2.2:3000/api

Everything else (Stripe, Cloudinary) works with dummy values in dev — those features will 4xx gracefully rather than
crash the server.

✻ Crunched for 3m 45s
