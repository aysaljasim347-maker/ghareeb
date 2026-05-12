# DisasterAid.pk V2.1

> Humanitarian platform connecting **NGOs**, **Donors**, **Volunteers**, and **Beneficiaries** for disaster relief in Pakistan.

---

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────────┐    ┌──────────────────────┐
│ Flutter App  │───▶│  Express API    │───▶│ PostgreSQL 16        │
│ (Riverpod)   │    │  (TypeScript)   │    │ + PostGIS 3          │
│              │    │  + Socket.IO    │    │                      │
└─────────────┘    └─────────────────┘    └──────────────────────┘
                          │
                   ┌──────┴──────┐
                   │ Cloudinary  │
                   │ (uploads)   │
                   └─────────────┘
```

## 📋 Tech Stack

| Layer     | Technology                                  |
|-----------|---------------------------------------------|
| Database  | PostgreSQL 16 + PostGIS 3                   |
| Backend   | Node.js + Express + TypeScript + pg Pool     |
| Frontend  | Flutter 3.22 + Riverpod 2.5 + Dio           |
| Uploads   | Cloudinary                                  |
| Payments  | Stripe + Manual bank transfer               |
| Realtime  | Socket.IO                                   |
| DevOps    | Docker + docker-compose + GitHub Actions     |
| Testing   | Jest + flutter_test, coverage >80%           |

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 20+
- Flutter 3.22+
- PostgreSQL 16 (or use Docker)

### 1. Clone & Configure

```bash
git clone https://github.com/your-org/disasteraid-v2.git
cd disasteraid-v2
cp .env.example .env
# Edit .env with your database credentials, JWT secret, etc.
```

### 2. Start with Docker

```bash
# Start database + backend
docker-compose up -d

# Include Flutter web (optional)
docker-compose --profile web up -d
```

### 3. Manual Setup (Development)

```bash
# Database
psql -U your_user -d disasteraid -f database/001_init.sql

# Backend
cd backend
npm install
npm run dev

# Flutter
cd flutter_app
flutter pub get
flutter run
```

## 📁 Project Structure

```
disasteraid-v2/
├── database/
│   └── 001_init.sql              # Full schema with PostGIS, indexes, triggers
├── backend/
│   ├── src/
│   │   ├── config/               # Database pool, env validation, Cloudinary
│   │   ├── middleware/            # Auth (JWT), authorize, rate-limit, validation
│   │   ├── modules/
│   │   │   ├── auth/             # Register, login, profile
│   │   │   ├── tasks/            # CRUD + claim (FOR UPDATE)
│   │   │   ├── donations/        # Stripe + manual payments
│   │   │   ├── campaigns/        # Campaign management
│   │   │   ├── deliveries/       # Delivery proof + verification
│   │   │   └── chat/             # REST + Socket.IO real-time chat
│   │   └── server.ts             # Express app entry point
│   ├── tests/                    # Jest tests including race condition
│   ├── Dockerfile                # Multi-stage production build
│   └── package.json
├── flutter_app/
│   ├── lib/
│   │   ├── core/                 # API client, router, storage, theme
│   │   └── features/
│   │       ├── auth/             # Login, register, providers
│   │       └── tasks/            # Task list, detail, claim
│   ├── test/                     # Flutter unit tests
│   └── pubspec.yaml
├── docker-compose.yml
├── .env.example
└── .github/workflows/ci.yml
```

## 🔐 Security

| Feature                  | Implementation                               |
|--------------------------|----------------------------------------------|
| Password Hashing         | bcrypt, 12 rounds, async                     |
| Authentication           | JWT with DB role lookup (never trust client) |
| Admin Signup             | **Blocked** — admin only via DB seed         |
| Rate Limiting            | 100 requests / 15 minutes / IP               |
| CORS                     | Whitelist-only origins                       |
| Input Validation         | Zod schemas on all endpoints                 |
| SQL Injection            | Parameterized queries ($1, $2...)            |
| Race Conditions          | `SELECT ... FOR UPDATE` in transactions      |
| Secure Token Storage     | flutter_secure_storage (Keychain/Keystore)   |
| Headers                  | Helmet.js security headers                   |

## 🏃 Task Claim — Race Condition Safety

The critical task claiming operation uses PostgreSQL row-level locking:

```typescript
await client.query('BEGIN');

// Lock row — concurrent claims BLOCK here
const task = await client.query(
  'SELECT id, status FROM tasks WHERE id = $1 FOR UPDATE',
  [taskId]
);

if (task.rows[0].status !== 'OPEN') {
  await client.query('ROLLBACK');
  throw new Error('Task not available');
}

await client.query(
  'UPDATE tasks SET status = \'CLAIMED\', claimed_by = $1 WHERE id = $2',
  [volunteerId, taskId]
);

await client.query('COMMIT');
```

**Test**: 10 concurrent volunteers claim the same task → exactly 1 wins, 9 fail.

## 💳 Payments

### Stripe Integration
- Checkout sessions created via `/api/donations`
- Webhook at `/api/donations/webhook` confirms payment
- Campaign `raised_pkr` updated atomically in transaction

### Manual Bank Transfer
- Donor creates donation with `status: PENDING`
- Uploads bank transfer receipt
- Admin/Coordinator confirms via `/api/donations/:id/confirm`
- Ledger entry created on confirmation

## 🧪 Testing

```bash
# Backend tests (requires PostgreSQL)
cd backend
npm test

# Race condition test only
npm run test:race

# Flutter tests
cd flutter_app
flutter test --coverage
```

## 🔑 API Endpoints

| Method | Endpoint                        | Auth     | Description                   |
|--------|---------------------------------|----------|-------------------------------|
| POST   | `/api/auth/register`            | Public   | Register (no ADMIN role)      |
| POST   | `/api/auth/login`               | Public   | Login with email/phone        |
| GET    | `/api/auth/me`                  | JWT      | Current user profile          |
| GET    | `/api/tasks/available`          | JWT      | **All** open tasks (no filter)|
| POST   | `/api/tasks`                    | JWT+Role | Create task                   |
| GET    | `/api/tasks/:id`                | JWT      | Task details                  |
| POST   | `/api/tasks/:id/claim`          | JWT+VOL  | Claim task (FOR UPDATE)       |
| GET    | `/api/campaigns`                | JWT      | List campaigns                |
| POST   | `/api/campaigns`                | JWT+Role | Create campaign               |
| POST   | `/api/donations`                | JWT      | Create donation               |
| POST   | `/api/donations/:id/confirm`    | JWT+ADM  | Confirm manual payment        |
| POST   | `/api/deliveries`               | JWT+VOL  | Submit delivery proof         |
| POST   | `/api/deliveries/:id/verify`    | JWT+ADM  | Verify delivery               |
| POST   | `/api/chat/rooms`               | JWT      | Create chat room              |
| GET    | `/api/chat/rooms/:id/messages`  | JWT      | Get room messages             |
| GET    | `/api/health`                   | Public   | Health check                  |

## 📄 License

MIT
