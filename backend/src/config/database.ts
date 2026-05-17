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

// Pool-level idle client errors are non-fatal — the pool self-heals.
// Calling process.exit here would crash the server on any transient DB blip.
pool.on('error', (err) => {
  console.error('[DB POOL] Idle client error (pool will self-heal):', err.message);
});

/**
 * Health check for database connectivity.
 */
export async function checkDatabaseHealth(): Promise<boolean> {
  // Acquire a client explicitly so we test a real round-trip, not a cached query.
  // pg returns all numeric literals as strings, so compare with string '1'.
  let client;
  try {
    client = await pool.connect();
    await client.query('SELECT 1');
    return true;
  } catch (err) {
    console.error('[DB HEALTH] Check failed:', err);
    return false;
  } finally {
    client?.release();
  }
}
