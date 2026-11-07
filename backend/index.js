// PSTC_IPV6_NETWORK_FIX
const dns = require('node:dns');
const net = require('node:net');

dns.setDefaultResultOrder('ipv6first');
net.setDefaultAutoSelectFamily(false);

const express = require('express');
const fs = require('fs');
const path = require('path');

require('dotenv').config({
  path: path.join(__dirname, '.env'),
});

const {
  initializeApp,
  applicationDefault,
  getApps,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');
const { Pool } = require('pg');
const { createCustomersRouter } = require('./customers_routes');
const { createSyncRouter } = require('./sync_routes');

const app = express();

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';

const PROJECT_ID = 'ps-tax-consultancy-210bf';
const ORGANIZATION_ID = 'ps-tax-consultancy-210bf';

const ALLOWED_ROLES = new Set([
  'owner',
  'admin',
  'employee',
]);

// ------------------------------------------------------------
// DATABASE CONFIGURATION
// ------------------------------------------------------------

const requiredDatabaseSettings = [
  'PGHOST',
  'PGPORT',
  'PGDATABASE',
  'PGUSER',
  'PGPASSWORD_B64',
];

for (const key of requiredDatabaseSettings) {
  if (!process.env[key]) {
    throw new Error(`Missing database configuration: ${key}`);
  }
}

const pgPort = Number(process.env.PGPORT);

if (!Number.isInteger(pgPort) || pgPort < 1 || pgPort > 65535) {
  throw new Error('Invalid PostgreSQL port.');
}

const databasePassword = Buffer.from(
  process.env.PGPASSWORD_B64,
  'base64',
).toString('utf8');

if (!databasePassword) {
  throw new Error('Database password is empty.');
}

const caPath = path.resolve(
  __dirname,
  process.env.PG_CA_FILE || 'ca.pem',
);

if (!fs.existsSync(caPath)) {
  throw new Error('PostgreSQL CA certificate is missing.');
}

const caCertificate = fs.readFileSync(caPath, 'utf8');

const pool = new Pool({
  host: process.env.PGHOST,
  port: pgPort,
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: databasePassword,

  ssl: {
    ca: caCertificate,
    rejectUnauthorized: true,
      servername: process.env.PGHOST,
  },

  max: 5,
  connectionTimeoutMillis: 15000,
  idleTimeoutMillis: 30000,
});

// ------------------------------------------------------------
// FIREBASE ADMIN INITIALIZATION
// ------------------------------------------------------------

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });
}

app.disable('x-powered-by');

app.use(express.json({
  limit: '1mb',
}));

// ------------------------------------------------------------
// HEALTH CHECK
// ------------------------------------------------------------

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');

    return res.status(200).json({
      success: true,
      service: 'PS Tax Consultancy API',
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Database health check failed:', error);
console.error('Database health details:', {
  name: error?.name,
  message: error?.message || String(error),
  code: error?.code,
  severity: error?.severity,
  stack: error?.stack,
});

    return res.status(503).json({
      success: false,
      service: 'PS Tax Consultancy API',
      status: 'database_unavailable',
    });
  }
});

// ------------------------------------------------------------
// FIREBASE AUTHENTICATION
// + ORGANIZATION AUTHORIZATION
// + ACTIVE DATABASE MEMBERSHIP
// ------------------------------------------------------------

async function requireFirebaseAuth(req, res, next) {
  const authorization = req.headers.authorization || '';

  const match = authorization.match(/^Bearer\s+(\S+)$/i);

  if (!match) {
    return res.status(401).json({
      success: false,
      error: 'Missing Firebase ID token.',
    });
  }

  let decodedToken;

  // 1. Verify Firebase ID token.
  try {
    decodedToken = await getAuth().verifyIdToken(
      match[1],
      true,
    );
  } catch (error) {
    console.error(
      'Firebase token verification failed:',
      error.code || 'unknown',
    );

    return res.status(401).json({
      success: false,
      error: 'Invalid, expired, or revoked Firebase ID token.',
    });
  }

  // 2. Verify organization claim.
  if (decodedToken.organizationId !== ORGANIZATION_ID) {
    return res.status(403).json({
      success: false,
      error: 'Access denied for this organization.',
    });
  }

  // 3. Verify active PostgreSQL membership.
  let membership;

  try {
    membership = await pool.query(
      `SELECT role, is_active
       FROM organization_members
       WHERE organization_id = $1
         AND firebase_uid = $2
       LIMIT 1`,
      [
        ORGANIZATION_ID,
        decodedToken.uid,
      ],
    );
  } catch (error) {
    console.error(
      'Membership database check failed:',
      error.code || 'unknown',
    );

    return res.status(503).json({
      success: false,
      error: 'Authorization service temporarily unavailable.',
    });
  }

  if (membership.rowCount !== 1) {
    return res.status(403).json({
      success: false,
      error: 'Organization membership not found.',
    });
  }

  const member = membership.rows[0];

  if (member.is_active !== true) {
    return res.status(403).json({
      success: false,
      error: 'Organization membership is inactive.',
    });
  }

  // 4. Use the database role as the authoritative role.
  if (!ALLOWED_ROLES.has(member.role)) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient organization permissions.',
    });
  }

  req.user = {
    uid: decodedToken.uid,
    email: decodedToken.email || null,
    organizationId: ORGANIZATION_ID,
    organizationRole: member.role,
  };

  return next();
}

// ------------------------------------------------------------
// PROTECTED USER DETAILS
// ------------------------------------------------------------

app.get('/api/me', requireFirebaseAuth, (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Firebase and PostgreSQL authorization verified.',
    user: req.user,
  });
});

// ------------------------------------------------------------
// CUSTOMER API
app.use('/api/customers', createCustomersRouter({ pool, requireFirebaseAuth }));
app.use('/api/sync', createSyncRouter({ pool, requireFirebaseAuth }));

// NOT FOUND
// ------------------------------------------------------------

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'API endpoint not found.',
  });
});

// ------------------------------------------------------------
// SERVER START
// ------------------------------------------------------------

const server = app.listen(PORT, HOST, () => {
  console.log(
    `PS Tax Consultancy API running at http://${HOST}:${PORT}`,
  );

  console.log(
    'PostgreSQL connection pool: READY',
  );

  console.log(
    'Firebase Authentication: ENABLED',
  );

  console.log(
    'Organization Membership Authorization: ENABLED',
  );

  console.log(
    'Allowed database roles: owner, admin, employee',
  );

  console.log(
    `Server host binding: ${HOST}`,
  );
});

// ------------------------------------------------------------
// GRACEFUL SHUTDOWN
// ------------------------------------------------------------

let shuttingDown = false;

async function shutdown() {
  if (shuttingDown) return;

  shuttingDown = true;

  console.log('\nStopping PS Tax Consultancy API...');

  server.close(async () => {
    await pool.end();

    console.log('Database connections closed.');
    process.exit(0);
  });

  setTimeout(() => {
    process.exit(1);
  }, 10000).unref();
}

process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);

