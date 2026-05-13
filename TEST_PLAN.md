# Test Plan: DisasterAid V2.1 Integration

## Prerequisites
Ensure Docker is running and ports 3000 and 5432 are available.

## Step 1: Start Services
```bash
docker compose down -v
docker compose up --build -d
```
*Wait ~10 seconds for the database to initialize and the backend to connect.*

## Step 2: Verify Health & DB Connection
```bash
curl http://localhost:3000/api/health
```
**Expected:** `{"status":"healthy","database":"connected",...}`

## Step 3: Verify CORS Preflight (Flutter Web)
```bash
curl -X OPTIONS http://localhost:3000/api/auth/register -H "Origin: http://localhost:5000" -i
```
**Expected:** `HTTP/1.1 204 No Content` with `Access-Control-Allow-Origin: http://localhost:5000`

## Step 4: Verify Mobile API (No Origin)
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"mobile@test.com","password":"password123","name":"Mobile User","role":"VOLUNTEER"}' -i
```
**Expected:** `HTTP/1.1 201 Created` or `200 OK` with JSON user profile and token.

## Step 5: Test Flutter Web Registration
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Origin: http://localhost:5000" \
  -H "Content-Type: application/json" \
  -d '{"email":"web@test.com","password":"password123","name":"Web User","role":"VOLUNTEER"}' -i
```
**Expected:** `HTTP/1.1 201 Created` or `200 OK` with `Access-Control-Allow-Origin: http://localhost:5000`.
