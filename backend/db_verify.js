const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const { Pool } = require('pg');

const ORG_ID = 'ps-tax-consultancy-210bf';

const EXPECTED_TABLES = [
  'organizations',
  'organization_members',
  'customers',
  'invoices',
  'invoice_items',
  'payments',
  'invoice_sequence',
];

async function main() {
  let pool;
  let client;
  let transactionOpen = false;

  try {
    const password = Buffer.from(
      process.env.PGPASSWORD_B64 || '',
      'base64',
    ).toString('utf8');

    const caPath = path.resolve(
      __dirname,
      process.env.PG_CA_FILE || 'ca.pem',
    );

    if (!password || !fs.existsSync(caPath)) {
      throw new Error('Database configuration is incomplete.');
    }

    pool = new Pool({
      host: process.env.PGHOST,
      port: Number(process.env.PGPORT),
      database: process.env.PGDATABASE,
      user: process.env.PGUSER,
      password,
      ssl: {
        ca: fs.readFileSync(caPath, 'utf8'),
        rejectUnauthorized: true,
      },
      max: 1,
      connectionTimeoutMillis: 15000,
    });

    client = await pool.connect();

    const tables = await client.query(
      `SELECT table_name
       FROM information_schema.tables
       WHERE table_schema = 'public'
         AND table_name = ANY($1::text[])
       ORDER BY table_name`,
      [EXPECTED_TABLES],
    );

    if (tables.rowCount !== EXPECTED_TABLES.length) {
      throw new Error('Expected tables verification failed.');
    }

    console.log('Database Tables: 7 / 7 VERIFIED');

    const organization = await client.query(
      'SELECT id FROM organizations WHERE id = $1',
      [ORG_ID],
    );

    if (organization.rowCount !== 1) {
      throw new Error('Organization record is missing.');
    }

    console.log('Organization Record: VERIFIED');

    const sequenceBefore = await client.query(
      'SELECT next_number FROM invoice_sequence WHERE organization_id = $1',
      [ORG_ID],
    );

    if (sequenceBefore.rowCount !== 1) {
      throw new Error('Invoice sequence record is missing.');
    }

    console.log('Invoice Sequence Record: VERIFIED');

    const functionCheck = await client.query(
      `SELECT to_regprocedure(
         'public.allocate_pstc_invoice_number(text)'
       ) IS NOT NULL AS installed`,
    );

    if (!functionCheck.rows[0].installed) {
      throw new Error('Invoice number function is missing.');
    }

    console.log('Invoice Number Function: VERIFIED');

    // Test the function inside a transaction and roll it back.
    await client.query('BEGIN');
    transactionOpen = true;

    const testNumber = await client.query(
      'SELECT public.allocate_pstc_invoice_number($1) AS invoice_number',
      [ORG_ID],
    );

    const invoiceNumber = testNumber.rows[0].invoice_number;

    if (!/^PSTC-INV-\d{4,}$/.test(invoiceNumber)) {
      throw new Error('Invoice number format verification failed.');
    }

    await client.query('ROLLBACK');
    transactionOpen = false;

    const sequenceAfter = await client.query(
      'SELECT next_number FROM invoice_sequence WHERE organization_id = $1',
      [ORG_ID],
    );

    if (
      sequenceBefore.rows[0].next_number !==
      sequenceAfter.rows[0].next_number
    ) {
      throw new Error('Test rollback did not preserve the sequence.');
    }

    console.log('Invoice Number Generation: PASSED');
    console.log('Test transaction: ROLLED BACK');
    console.log('Permanent invoice number: NOT consumed');

    const memberCount = await client.query(
      'SELECT COUNT(*)::int AS total FROM organization_members WHERE organization_id = $1',
      [ORG_ID],
    );

    console.log(
      'Organization Members:',
      memberCount.rows[0].total,
      '(membership setup pending)',
    );

    console.log('\nDATABASE VERIFICATION: PASSED');
  } catch (error) {
    if (transactionOpen && client) {
      await client.query('ROLLBACK').catch(() => {});
    }

    console.error('\nDATABASE VERIFICATION: FAILED');
    console.error('Error code:', error.code || 'UNKNOWN');
    console.error('Error type:', error.name || 'Error');

    process.exitCode = 1;
  } finally {
    if (client) client.release();
    if (pool) await pool.end().catch(() => {});
  }
}

main();