require('dotenv').config();
const fs = require('fs');
const path = require('path');
const readline = require('node:readline/promises');

const { stdin, stdout } = require('node:process');
const {
  initializeApp,
  applicationDefault,
  getApps,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');
const { Pool } = require('pg');

const ORG_ID = 'ps-tax-consultancy-210bf';

async function main() {
  let pool;
  let client;
  let rl;
  let transactionOpen = false;
  let stage = 'Configuration';

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
      throw Object.assign(
        new Error('Configuration missing'),
        { code: 'CONFIGURATION_INCOMPLETE' },
      );
    }

    if (getApps().length === 0) {
      initializeApp({
        credential: applicationDefault(),
        projectId: ORG_ID,
      });
    }

    stage = 'Firebase Owner Verification';

    rl = readline.createInterface({ input: stdin, output: stdout });

    const email = (await rl.question(
      'Firebase Owner account email: ',
    )).trim();

    if (!email || !email.includes('@')) {
      throw Object.assign(
        new Error('Invalid email'),
        { code: 'INVALID_EMAIL' },
      );
    }

    const user = await getAuth().getUserByEmail(email);
    const claims = user.customClaims || {};

    if (
      claims.organizationId !== ORG_ID ||
      claims.organizationRole !== 'owner'
    ) {
      throw Object.assign(
        new Error('Owner authorization claims do not match'),
        { code: 'OWNER_CLAIMS_MISMATCH' },
      );
    }

    stage = 'PostgreSQL Connection';

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

    stage = 'Organization Membership';

    await client.query('BEGIN');
    transactionOpen = true;

    const organization = await client.query(
      'SELECT id FROM organizations WHERE id = $1',
      [ORG_ID],
    );

    if (organization.rowCount !== 1) {
      throw Object.assign(
        new Error('Organization not found'),
        { code: 'ORGANIZATION_NOT_FOUND' },
      );
    }

    await client.query(
      `INSERT INTO organization_members
       (organization_id, firebase_uid, email, role, is_active)
       VALUES ($1, $2, $3, 'owner', TRUE)
       ON CONFLICT (organization_id, firebase_uid)
       DO UPDATE SET
         email = EXCLUDED.email,
         role = 'owner',
         is_active = TRUE,
         updated_at = NOW()`,
      [ORG_ID, user.uid, user.email || email],
    );

    const verification = await client.query(
      `SELECT role, is_active
       FROM organization_members
       WHERE organization_id = $1
         AND firebase_uid = $2`,
      [ORG_ID, user.uid],
    );

    if (
      verification.rowCount !== 1 ||
      verification.rows[0].role !== 'owner' ||
      verification.rows[0].is_active !== true
    ) {
      throw Object.assign(
        new Error('Membership verification failed'),
        { code: 'MEMBERSHIP_VERIFICATION_FAILED' },
      );
    }

    await client.query('COMMIT');
    transactionOpen = false;

    console.log('\nFirebase Owner Claims: VERIFIED');
    console.log('PostgreSQL Owner Membership: CREATED');
    console.log('Active Owner Membership: VERIFIED');
    console.log('User UID and credentials: NOT DISPLAYED');
    console.log('\nOWNER MEMBERSHIP SETUP: PASSED');

  } catch (error) {
    if (transactionOpen && client) {
      await client.query('ROLLBACK').catch(() => {});
    }

    console.error('\nOWNER MEMBERSHIP SETUP: FAILED');
    console.error('Stage:', stage);
    console.error('Error code:', error.code || 'UNKNOWN');
  } finally {
    if (client) client.release();
    if (pool) await pool.end().catch(() => {});
    if (rl) rl.close();
  }
}

main();