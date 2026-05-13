# Backend Testing Audit - DisasterAid V2.1
**Date:** 2026-05-12
**Auditor:** Senior QA Engineer & Test Architect
**Scope:** Node.js (Express), TypeScript, PostgreSQL/PostGIS

## 🔴 Critical Test Gaps

### 1. Lack of Application-Layer Integration Tests (Supertest)
**Issue:** Current tests in `backend/tests/` bypass the Express routes and Services entirely. They replicate SQL logic inside the test files to verify database behavior.
**Why it matters:** This means the code in `controllers`, `middleware`, and `services` (the actual production code) is **untested**. A bug in the Zod validation or a typo in a Service method would not be caught by the current suite.
**Suggested Test Case:**
```typescript
import request from 'supertest';
import { app } from '../src/server';

describe('POST /api/auth/register', () => {
  it('should return 201 and user data on valid input', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'newuser@test.com',
        password: 'securePassword123',
        name: 'John Doe',
        role: 'VOLUNTEER'
      });
    expect(res.status).toBe(201);
    expect(res.body.token).toBeDefined();
  });
});
```

### 2. Missing PostGIS Spatial Query Validation
**Issue:** The `getAvailableTasks` and `createTask` methods use `ST_MakePoint` and `geography` types, but there are no tests verifying distance-based filtering or coordinate accuracy at the API level.
**Why it matters:** Spatial logic is prone to error (lat/lng swap, SRID mismatches). Without tests, the "Nearby Tasks" feature in the app might show incorrect data.
**Suggested Test Case:**
*   Create a task at Point A.
*   Query for tasks within 5km of Point B (where distance > 5km).
*   Expect task to NOT be returned.
*   Query within 10km of Point B (where distance < 10km).
*   Expect task TO be returned.

### 3. Middleware & Authorization Bypass Testing
**Issue:** There are no tests verifying that `authenticate` and `authorize` middleware actually block requests.
**Why it matters:** If a developer accidentally removes `authenticate` from a route, the current test suite won't fail.
**Suggested Test Case:**
```typescript
it('should return 401 if Authorization header is missing', async () => {
  const res = await request(app).get('/api/auth/me');
  expect(res.status).toBe(401);
});

it('should return 403 if role is insufficient', async () => {
  const volunteerToken = '...';
  const res = await request(app)
    .post('/api/campaigns') // NGO only
    .set('Authorization', `Bearer ${volunteerToken}`);
  expect(res.status).toBe(403);
});
```

---

## 🟠 Medium Test Gaps

### 1. Error Handling & Edge Cases
**Issue:** No tests for invalid Zod payloads, duplicate emails (as an API response), or non-existent IDs.
**Suggested Improvement:** Add a `describe('Failure Scenarios')` block to every module test suite.

### 2. Database Transaction Consistency
**Issue:** The race condition test is excellent, but it doesn't verify if partial failures in a transaction cause a full rollback (e.g., if a task event fails to record, is the task still claimed?).
**Suggested Improvement:** Simulate a failure mid-transaction and verify the DB state remains unchanged.

---

## 🟢 Minor Improvements

1. **Test Environment Orchestration:** Use a `docker-compose.test.yml` to spin up a dedicated test database automatically before running Jest.
2. **Logging in Tests:** Disable console logs during tests to keep the output clean, or use a specific logger that redirects to a file.

---

## ⚠️ Testing Risks

*   **Financial Integrity:** The `confirmDonation` logic is critical. If the logic for updating `campaign.raised_pkr` fails, the platform loses financial credibility.
*   **Real-time Leaks:** Since the Chat IDOR was a critical security finding, it needs permanent regression tests to ensure authorization is never accidentally removed from the `join_room` or `sendMessage` flows.

---

## 🛠 Suggested Test Cases

### 1. Validation Logic (Zod)
```typescript
test('should reject registration with password < 8 chars', async () => {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ email: 'a@b.com', password: '123', name: 'Test', role: 'DONOR' });
  expect(res.status).toBe(400);
  expect(res.body.error).toBe('Validation failed');
});
```

### 2. Spatial Query (PostGIS)
```typescript
test('should only return tasks within specified radius', async () => {
  // Task in Karachi
  await createTestTask({ lat: 24.8, lng: 67.0 }); 
  
  // Search from Lahore (1000km away) with 10km radius
  const res = await request(app)
    .get('/api/tasks/available?lat=31.5&lng=74.3&radius=10');
  
  expect(res.body.tasks.length).toBe(0);
});
```
