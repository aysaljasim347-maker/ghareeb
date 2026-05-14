import request from 'supertest';
import { app } from '../src/server.js';
import { pool } from '../src/config/database.js';

describe('API Integration Tests', () => {
  beforeAll(async () => {
    try {
      await pool.query('SELECT 1');
    } catch {
      console.warn('Database not reachable, integration tests will skip DB-dependent cases');
    }
  });

  afterAll(async () => {
    await pool.end();
  });

  describe('Authentication Module', () => {
    test('POST /api/auth/register - should fail on weak password (Zod Validation)', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'weak@test.com',
          password: '123',
          name: 'Weak User',
          role: 'DONOR'
        });

      expect(res.status).toBe(400);
      expect(res.body.error).toBe('Validation failed');
    });

    test('GET /api/auth/me - should block unauthorized access (Middleware)', async () => {
      const res = await request(app).get('/api/auth/me');
      expect(res.status).toBe(401);
    });
  });

  describe('Chat Authorization (Regression)', () => {
    test('GET /api/chat/rooms/:id/messages - should block anonymous users', async () => {
      const res = await request(app)
        .get('/api/chat/rooms/99999/messages');
      
      expect(res.status).toBe(401);
    });
  });
});
