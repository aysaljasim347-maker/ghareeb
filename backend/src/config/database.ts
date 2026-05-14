import { Pool, PoolConfig } from 'pg';
import { env } from './env.js';

const poolConfig: PoolConfig = {
  host: env.POSTGRES_HOST,
  port: env.POSTGRES_PORT,
  database: env.POSTGRES_DB,
  user: env.POSTGRES_USER,
  password: env.POSTGRES_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  statement_timeout: 30000, // 30 second limit on all queries
};

export const pool = new Pool(poolConfig);

// Graceful pool error handling
pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL pool error:', err);
  process.exit(-1);
});

/**
 * Health check for database connectivity.
 */
export async function checkDatabaseHealth(): Promise<boolean> {
  try {
    const result = await pool.query('SELECT 1 AS ok');
    return result.rows[0]?.ok === 1;
  } catch (err) {
    console.error('Database health check failed:', err);
    return false;
  }
}
