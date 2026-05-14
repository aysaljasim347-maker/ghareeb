# 🔍 Observability Audit: DisasterAid V2.1

**Auditor:** Senior DevOps & Observability Engineer
**Date:** May 13, 2026
**Scope:** Logging, Monitoring, Alerts, and Crash Tracking

---

## 🔴 Critical Observability Gaps

### 1. Unstructured & Localized Logging (Backend)
**Problem:** The backend relies on `console.log` and `console.error` for all logging. Logs are plain text and exist only within the container's stdout.
**Why it is dangerous:** In a production failure, searching through thousands of lines of unstructured text is nearly impossible. There is no easy way to filter by user ID, request type, or error code across multiple instances.
**Impact:** Slow incident response; developers spend hours "grepping" logs instead of fixing the root cause.
**Fix:** Implement a structured logging library (e.g., **Pino** or **Winston**) to output logs in JSON format. Ship these logs to a centralized log management system (e.g., Datadog, ELK, or BetterStack).

### 2. Absence of Frontend Crash Tracking
**Problem:** There is no crash reporting tool (like **Sentry** or **Firebase Crashlytics**) integrated into the Flutter application.
**Why it is dangerous:** If the app crashes on a user's device in a disaster zone, the engineering team will have **zero visibility** into the failure. "Silent" UI exceptions go unreported.
**Impact:** High user churn; critical features (like task claiming) may be broken on specific devices without any notification to the team.
**Fix:** Integrate **Sentry** or **Firebase Crashlytics** immediately. Wrap `runApp` with a global error handler to capture both Flutter-level and platform-level exceptions.

---

## 🟠 Medium Observability Issues

### 1. No Correlation IDs (Trace IDs)
**Description:** There is no mechanism to link a Flutter API request to its corresponding backend processing and database queries.
**Impact:** Debugging "why did this specific donation fail?" is a manual task of matching timestamps between frontend and backend logs.
**Suggested improvement:** Use a middleware to generate a unique `X-Request-ID` in Flutter and propagate it through the backend service layer and into every log message.

### 2. Lack of Health & Performance Metrics
**Description:** The system does not track basic SLIs (Service Level Indicators) like API latency, 5xx error rates, or database query durations.
**Impact:** The team only knows the system is slow or broken when users complain (Reactive vs. Proactive).
**Suggested improvement:** Implement a Prometheus metrics exporter in the backend to track request throughput and latency.

---

## 🟢 Minor Improvements

### 1. HTTP Request Logging
**Description:** Successful requests are not logged.
**Refinement:** Implement a lightweight request logger (e.g., `morgan` or a custom Pino middleware) to track API usage patterns.

### 2. User Context in Logs
**Description:** Errors are logged with a stack trace but often lack the context of which user was performing the action.
**Refinement:** Automatically include `userId` in log metadata for all authenticated requests.

---

## ⚠️ High-Risk Blind Spots

### 1. Database Connection Leaks
**Pattern:** The `errorHandler.ts` logs errors but does not monitor the health of the connection pool.
**Risk:** If connections are leaking (e.g., in a complex transaction branch), the system will fail silently until it can no longer accept any new requests.
**Recommendation:** Add a metric for "Active DB Connections" and alert when it exceeds 80% of the pool size.

### 2. Silent API Failures in Flutter
**Pattern:** `ApiClient` catches errors and logs them to `debugPrint`, which is invisible in production.
**Risk:** Network timeouts or 500 errors appear to the user as "loading forever" without any report sent to the dev team.
**Recommendation:** Every caught exception in `ApiClient` should be sent to a centralized error tracker (Sentry).

---

## 🛠 Recommended Observability Stack Design

### 1. Logging System
*   **Library:** Pino (High-performance JSON logger).
*   **Structure:** `{ level, msg, requestId, userId, path, duration, err? }`.
*   **Destination:** Stream to CloudWatch Logs or ELK.

### 2. Monitoring & Alerts
*   **Metrics:** Prometheus (collecting data from `/api/metrics`).
*   **Visualization:** Grafana (Dashboards for RPS, Latency, Error Rates).
*   **Alerting:** Alertmanager (Slack/PagerDuty notifications for 5xx spikes or high latency).

### 3. Crash Tracking (Frontend)
*   **Tool:** Sentry (Native Flutter support).
*   **Capturing:** Global `FlutterError.onError` and `PlatformDispatcher.instance.onError`.

### 4. Distributed Tracing
*   **Context Propagation:** Pass `x-request-id` header from Flutter.
*   **Backend Trace:** Use `cls-hooked` or `AsyncLocalStorage` in Node.js to persist the Request ID throughout the async execution flow.
