// PSTC_IPV6_NETWORK_FIX
const dns = require('node:dns');
const net = require('node:net');

dns.setDefaultResultOrder('ipv6first');
net.setDefaultAutoSelectFamily(false);

const fs = require('fs');
const path = require('path');
require('dotenv').config({
  path: path.join(__dirname, '.env'),
});

const { Pool } = require('pg');

async function testDatabaseConnection() {
  let pool;

  try {
    const required = [
      'PGHOST',
      'PGPORT',
      'PGDATABASE',
      'PGUSER',
      'PGPASSWORD_B64',
    ];

    for (const key of required) {
      if (!process.env[key]) {
        throw new Error('Missing database configuration.');
      }
    }

    const port = Number(process.env.PGPORT);

    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('Invalid database port.');
    }

    const password = Buffer.from(
      process.env.PGPASSWORD_B64,
      'base64',
    ).toString('utf8');

    if (!password) {
      throw new Error('Database password is empty.');
    }

    const caPath = path.resolve(
      __dirname,
      process.env.PG_CA_FILE || 'ca.pem',
    );

    if (!fs.existsSync(caPath)) {
      throw new Error('CA certificate file not found.');
    }

    const caCertificate = fs.readFileSync(caPath, 'utf8');

    pool = new Pool({
      host: process.env.PGHOST,
      port,
      database: process.env.PGDATABASE,
      user: process.env.PGUSER,
      password,
      ssl: {
        ca: caCertificate,
        rejectUnauthorized: true,
      servername: process.env.PGHOST,
      },
      max: 2,
      connectionTimeoutMillis: 15000,
      idleTimeoutMillis: 5000,
    });

    const result = await pool.query(
      'SELECT 1 AS connection_test',
    );

    if (result.rows[0].connection_test !== 1) {
      throw new Error('Unexpected database test result.');
    }

    console.log('\nAiven PostgreSQL Connection: PASSED');
    console.log('SSL Certificate Verification: PASSED');
    console.log('Database Query Test: PASSED');
    console.log('Connection test completed successfully.');
  } catch (error) {
    console.error('\nPostgreSQL Connection: FAILED');
    console.error('Error code:', error.code || 'UNKNOWN');
    console.error('Error type:', error.name || 'Error');
    console.error('Check the local database configuration.');
    process.exitCode = 1;
  } finally {
    if (pool) {
      await pool.end().catch(() => {});
    }
  }
}

testDatabaseConnection();

