const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { Pool } = require('pg');

async function main() {
  let pool;
  let client;

  try {
    const required = ['PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD_B64'];
    for (const key of required) {
      if (!process.env[key]) throw new Error(`Missing configuration: ${key}`);
    }

    const port = Number(process.env.PGPORT);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('Invalid PostgreSQL port');
    }

    const caPath = path.resolve(__dirname, process.env.PG_CA_FILE || 'ca.pem');
    if (!fs.existsSync(caPath)) throw new Error('CA certificate not found');

    const password = Buffer.from(process.env.PGPASSWORD_B64, 'base64').toString('utf8');
    if (!password) throw new Error('Database password is empty');

    const schemaPath = path.join(__dirname, 'ps_tax_consultancy_schema.sql');
    if (!fs.existsSync(schemaPath)) throw new Error('Schema SQL file not found');
    const schemaSql = fs.readFileSync(schemaPath, 'utf8').replace(/^\uFEFF/, '');

    pool = new Pool({
      host: process.env.PGHOST,
      port,
      database: process.env.PGDATABASE,
      user: process.env.PGUSER,
      password,
      ssl: { ca: fs.readFileSync(caPath, 'utf8'), rejectUnauthorized: true },
      max: 1,
      connectionTimeoutMillis: 15000,
    });

    client = await pool.connect();
    await client.query('BEGIN');
    try {
      await client.query(schemaSql);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      throw error;
    }

    const check = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = ANY($1::text[])
      ORDER BY table_name
    `, [['organizations', 'organization_members', 'customers', 'invoices', 'invoice_items', 'payments', 'invoice_sequence']]);

    const expected = 7;
    if (check.rowCount !== expected) {
      throw new Error('Schema verification did not find all expected tables');
    }

    console.log('\nPostgreSQL schema setup: PASSED');
    console.log('Expected tables verified: 7');
    console.log('Invoice sequence function: installed');
    console.log('Existing SQLite data: NOT modified');
    console.log('Cloud database: schema only; no customer records imported');
  } catch (error) {
    console.error('\nSchema setup: FAILED');
    console.error('Error code:', error.code || 'UNKNOWN');
    console.error('Error type:', error.name || 'Error');
    console.error('The error message is hidden to avoid exposing connection details.');
    process.exitCode = 1;
  } finally {
    if (client) client.release();
    if (pool) await pool.end().catch(() => {});
  }
}

main();
