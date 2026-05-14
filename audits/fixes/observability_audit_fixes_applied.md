# 🔍 Observability Applied Fixes: DisasterAid V2.1

**Engineer:** Principal Observability Engineer
**Status:** Implementation of Phase 6C Observability Audit
**Date:** May 13, 2026

---

## 🔴 Critical Observability Fixes

### 1. Transition to Structured JSON Logging
**Problem:** Backend uses `console.log`, which is unstructured and hard to query in production.
**Why it is dangerous:** During an incident, finding specific user errors in a sea of text logs is nearly impossible.
**Safe Fix:** Implement a structured logger (Pino) that outputs JSON with standard metadata.

**Implementation (`src/utils/logger.ts`):**
```typescript
import pino from 'pino';
import { env } from '../config/env.js';

export const logger = pino({
  level: env.LOG_LEVEL || 'info',
  base: { service: 'disasteraid-api' },
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
```

### 2. End-to-End Request Correlation
**Problem:** No link exists between a Flutter request and the corresponding backend logs.
**Why it is dangerous:** Impossible to trace a single transaction's path through the system.
**Safe Fix:** Introduce a `requestId` middleware that attaches a unique ID to every request.

**Middleware Implementation:**
```typescript
import { v4 as uuidv4 } from 'uuid';

export const requestIdMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const requestId = req.headers['x-request-id'] || uuidv4();
  req.id = requestId;
  res.setHeader('X-Request-ID', requestId);
  next();
};
```

### 3. Flutter Global Error Boundary
**Problem:** Unhandled exceptions in Flutter crash the app silently without reporting.
**Why it is dangerous:** Critical field failures are invisible to developers.
**Safe Fix:** Wrap `runApp` with a Sentry error handler and configure `FlutterError.onError`.

**Implementation (`main.dart`):**
```dart
void main() async {
  await SentryFlutter.init(
    (options) => options.dsn = 'https://your-dsn@sentry.io/project',
    appRunner: () => runApp(const DisasterAidApp()),
  );
}
```

---

## 🟠 Medium Observability Fixes

### 1. Centralized Error Tracking (Sentry Backend)
**Description:** Errors in `errorHandler.ts` are only logged locally.
**Safe Improvement:** Add Sentry's Node.js SDK to the global error handler to capture and group all production exceptions automatically.

### 2. API Metrics Exporter
**Description:** No visibility into RPS (Requests Per Second) or latency.
**Safe Improvement:** Add `express-prom-bundle` to expose a `/metrics` endpoint for Prometheus to scrape, enabling latency dashboards.

---

## 🟢 Minor Improvements

### 1. Contextual Log Enrichment
**Description:** Logs lack user context.
**Refinement:** Update the `authenticate` middleware to inject `userId` into the logger's context for all subsequent logs in that request.

### 2. Slow Query Logging
**Description:** Large PostGIS queries can slow down the DB without being noticed.
**Refinement:** Log any query that takes longer than 200ms using the `pg` pool's 'query' event.

---

## ⚠️ Deferred Observability Fixes

### 1. Full OpenTelemetry Tracing
**Why Deferred:** Requires a dedicated tracing backend (Jaeger/Tempo) and significant instrumentation overhead. Deferred until multi-service scaling.

### 2. Real User Monitoring (RUM)
**Why Deferred:** Requires complex frontend instrumentation to track user sessions and page load times. Deferred.

---

## 🛠 Step-by-Step Observability Improvement Plan

1.  **Step 1: Backend Logging.** Swap `console` for the new `logger` utility. Start with non-critical paths to verify log ingestion.
2.  **Step 2: Correlation IDs.** Deploy the `requestIdMiddleware`. Update the Flutter `ApiClient` to send a UUID in the `X-Request-ID` header.
3.  **Step 3: Crash Reporting.** Integrate Sentry into Flutter and verify that a "Test Crash" is correctly reported in the dashboard.
4.  **Step 4: Error Standardization.** Update `errorHandler.ts` to use structured logs and notify Sentry of 5xx errors.
5.  **Step 5: Metrics.** Enable the Prometheus exporter and build a basic Grafana dashboard for API health.
