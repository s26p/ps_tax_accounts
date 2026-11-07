require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const caPath = path.resolve(__dirname, process.env.PG_CA_FILE || 'ca.pem');

const pool = new Pool({
  host: process.env.PGHOST,
  port: Number(process.env.PGPORT || 5432),
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: Buffer.from(process.env.PGPASSWORD_B64, 'base64').toString('utf8'),
  ssl: {
    ca: fs.readFileSync(caPath, 'utf8'),
    rejectUnauthorized: true,
  },
});

const required = {
  customers: ['id', 'organization_id', 'name', 'mobile', 'deleted_at', 'deleted_by', 'updated_at', 'version'],
  invoices: ['id', 'organization_id', 'customer_id', 'deleted_at', 'deleted_by', 'updated_at', 'version'],
  invoice_items: ['id', 'organization_id', 'invoice_id', 'deleted_at', 'deleted_by', 'updated_at', 'version'],
  payments: ['id', 'organization_id', 'customer_id', 'invoice_id', 'deleted_at', 'deleted_by', 'updated_at', 'version'],
};

(async () => {
  try {
    const result = await pool.query(
      `SELECT table_name, column_name
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = ANY($1::text[])
       ORDER BY table_name, ordinal_position`,
      [Object.keys(required)]
    );

    const actual = {};
    for (const row of result.rows) {
      if (!actual[row.table_name]) actual[row.table_name] = [];
      actual[row.table_name].push(row.column_name);
    }

    let allPassed = true;

    console.log('\nCUSTOMER API DATABASE SCHEMA CHECK\n');

    for (const [table, columns] of Object.entries(required)) {
      const present = actual[table] || [];
      const missing = columns.filter(column => !present.includes(column));

      console.log(`${table}: ${missing.length === 0 ? 'PASSED' : 'MISSING COLUMNS'}`);

      if (missing.length > 0) {
        allPassed = false;
        console.log(`  Missing: ${missing.join(', ')}`);
      }
    }

    console.log(
      allPassed
        ? '\nSCHEMA CHECK: PASSED'
        : '\nSCHEMA CHECK: NEEDS CORRECTION'
    );
  } catch (error) {
    console.log('Schema check failed.');
    console.log(`Error type: ${error.constructor.name}`);
  } finally {
    await pool.end();
  }
})();