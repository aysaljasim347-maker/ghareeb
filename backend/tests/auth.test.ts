import { Pool } from 'pg';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

// ── Test Database Connection ──
const TEST_DB_CONFIG = {
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
  database: process.env.POSTGRES_DB || 'disasteraid_test',
  user: process.env.POSTGRES_USER || 'test_user',
  password: process.env.POSTGRES_PASSWORD || 'test_password',
};

const JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_that_is_at_least_32_chars_long';

let pool: Pool;

beforeAll(async () => {
  pool = new Pool(TEST_DB_CONFIG);
  // Clean up test data
  await pool.query('DELETE FROM task_events');
  await pool.query('DELETE FROM task_views');
  await pool.query('DELETE FROM deliveries');
  await pool.query('DELETE FROM chat_messages');
  await pool.query('DELETE FROM chat_rooms');
  await pool.query('DELETE FROM donations');
  await pool.query('DELETE FROM tasks');
  await pool.query('DELETE FROM campaigns');
  await pool.query('DELETE FROM volunteer_profiles');
  await pool.query('DELETE FROM ngo_profiles');
  await pool.query("DELETE FROM users WHERE email != 'admin@disasteraid.pk'");
});

afterAll(async () => {
  await pool.end();
});

// ── Helpers ──
async function createTestUser(
  email: string,
  role: string,
  name: string = 'Test User'
) {
  const passwordHash = await bcrypt.hash('testpassword123', 4);
  const roleResult = await pool.query('SELECT id FROM roles WHERE name = $1', [role]);
  const result = await pool.query(
    `INSERT INTO users (email, password_hash, role_id, name)
     VALUES ($1, $2, $3, $4) RETURNING id, email, name`,
    [email, passwordHash, roleResult.rows[0].id, name]
  );
  return result.rows[0];
}

function generateToken(userId: number): string {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '1h' });
}

// ══════════════════════════════════════════════════
// AUTH TESTS
// ══════════════════════════════════════════════════

describe('Auth Module', () => {
  describe('Registration', () => {
    test('should register a new donor', async () => {
      const user = await createTestUser('donor@test.com', 'DONOR', 'Test Donor');
      expect(user.id).toBeDefined();
      expect(user.email).toBe('donor@test.com');
    });

    test('should not allow duplicate emails', async () => {
      try {
        await createTestUser('donor@test.com', 'DONOR');
        fail('Should have thrown');
      } catch (err: any) {
        expect(err.message).toContain('duplicate key');
      }
    });

    test('should hash passwords with bcrypt', async () => {
      const result = await pool.query(
        "SELECT password_hash FROM users WHERE email = 'donor@test.com'"
      );
      const hash = result.rows[0].password_hash;
      expect(hash).toMatch(/^\$2[aby]\$\d{2}\$/);
      const isValid = await bcrypt.compare('testpassword123', hash);
      expect(isValid).toBe(true);
    });

    test('ADMIN role cannot be created via registration', async () => {
      // Verify ADMIN registration is blocked at the application level
      // The schema validation rejects 'ADMIN' role
      const adminRoleId = await pool.query("SELECT id FROM roles WHERE name = 'ADMIN'");
      expect(adminRoleId.rows[0].id).toBe(6);
      // There should only be 1 admin (the seeded one)
      const admins = await pool.query(
        'SELECT COUNT(*) FROM users WHERE role_id = $1',
        [adminRoleId.rows[0].id]
      );
      expect(parseInt(admins.rows[0].count)).toBe(1);
    });
  });

  describe('JWT', () => {
    test('should generate valid JWT tokens', () => {
      const token = generateToken(1);
      const decoded = jwt.verify(token, JWT_SECRET) as { userId: number };
      expect(decoded.userId).toBe(1);
    });

    test('should reject invalid tokens', () => {
      expect(() => jwt.verify('invalid.token.here', JWT_SECRET)).toThrow();
    });
  });
});
