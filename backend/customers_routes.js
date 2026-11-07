const express = require('express');

function createCustomersRouter({ pool, requireFirebaseAuth }) {
  if (!pool || typeof requireFirebaseAuth !== 'function') {
    throw new Error('Customer router configuration is incomplete.');
  }

  const router = express.Router();

  router.use(requireFirebaseAuth);

  const fields = [
    ['name', 200, true],
    ['business_name', 250, false],
    ['mobile', 40, true],
    ['email', 254, false],
    ['address', 2000, false],
    ['gstin', 15, false],
    ['pan', 10, false],
  ];

  function validateField(body, field, maxLength, required) {
    const value = body[field];

    if (required && typeof value !== 'string') {
      throw new Error(`${field} is required.`);
    }

    if (value === undefined || value === null) {
      return required ? '' : null;
    }

    if (typeof value !== 'string') {
      throw new Error(`${field} must be text.`);
    }

    const cleaned = value.trim();

    if (required && !cleaned) {
      throw new Error(`${field} cannot be empty.`);
    }

    if (cleaned.length > maxLength) {
      throw new Error(`${field} exceeds the allowed length.`);
    }

    if (field === 'pan' || field === 'gstin') {
      return cleaned ? cleaned.toUpperCase() : null;
    }

    return cleaned || null;
  }

  function validId(id) {
    return typeof id === 'string' && /^[1-9]\d*$/.test(id);
  }

  function canWrite(req, res, next) {
    if (!['owner', 'admin'].includes(req.user.organizationRole)) {
      return res.status(403).json({
        success: false,
        error: 'Read-only access. Admin permission is required.',
      });
    }

    return next();
  }

  // GET CUSTOMER LIST
  router.get('/', async (req, res) => {
    try {
      const search = req.query.search ?? null;

      if (search !== null &&
          (typeof search !== 'string' || search.length > 100)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid search value.',
        });
      }

      const requestedLimit = Number(req.query.limit);
      const requestedOffset = Number(req.query.offset);

      const limit = Number.isInteger(requestedLimit) &&
          requestedLimit > 0
        ? Math.min(requestedLimit, 100)
        : 50;

      const offset = Number.isInteger(requestedOffset) &&
          requestedOffset >= 0
        ? requestedOffset
        : 0;

      const result = await pool.query(
        `SELECT id, name, business_name, mobile, email,
                address, gstin, pan, version,
                created_at, updated_at
         FROM customers
         WHERE organization_id = $1
           AND deleted_at IS NULL
           AND (
             $2::text IS NULL
             OR name ILIKE $2
             OR COALESCE(business_name, '') ILIKE $2
             OR mobile ILIKE $2
             OR COALESCE(email, '') ILIKE $2
           )
         ORDER BY id DESC
         LIMIT $3 OFFSET $4`,
        [
          req.user.organizationId,
          search ? `%${search}%` : null,
          limit,
          offset,
        ],
      );

      return res.json({
        success: true,
        customers: result.rows,
        pagination: {
          limit,
          offset,
          returned: result.rowCount,
        },
      });
    } catch (error) {
      console.error('Customer list failed:', error.code || 'unknown');

      return res.status(500).json({
        success: false,
        error: 'Unable to retrieve customers.',
      });
    }
  });

  // GET CUSTOMER BY ID
  router.get('/:id', async (req, res) => {
    try {
      if (!validId(req.params.id)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid customer ID.',
        });
      }

      const result = await pool.query(
        `SELECT id, name, business_name, mobile, email,
                address, gstin, pan, version,
                created_at, updated_at
         FROM customers
         WHERE organization_id = $1
           AND id = $2
           AND deleted_at IS NULL`,
        [req.user.organizationId, req.params.id],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({
          success: false,
          error: 'Customer not found.',
        });
      }

      return res.json({
        success: true,
        customer: result.rows[0],
      });
    } catch (error) {
      console.error('Customer lookup failed:', error.code || 'unknown');

      return res.status(500).json({
        success: false,
        error: 'Unable to retrieve customer.',
      });
    }
  });

  // ADD CUSTOMER
  router.post('/', canWrite, async (req, res) => {
    try {
      if (!req.body || typeof req.body !== 'object' ||
          Array.isArray(req.body)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid customer data.',
        });
      }

      const values = fields.map(([field, max, required]) =>
        validateField(req.body, field, max, required),
      );

      const result = await pool.query(
        `INSERT INTO customers (
           organization_id,
           name,
           business_name,
           mobile,
           email,
           address,
           gstin,
           pan
         )
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         RETURNING id, name, business_name, mobile, email,
                   address, gstin, pan, version, created_at`,
        [req.user.organizationId, ...values],
      );

      return res.status(201).json({
        success: true,
        message: 'Customer created successfully.',
        customer: result.rows[0],
      });
    } catch (error) {
      if (error.code === undefined) {
        return res.status(400).json({
          success: false,
          error: error.message,
        });
      }

      console.error('Customer creation failed:', error.code || 'unknown');

      return res.status(500).json({
        success: false,
        error: 'Unable to create customer.',
      });
    }
  });

  // UPDATE CUSTOMER
  router.put('/:id', canWrite, async (req, res) => {
    try {
      if (!validId(req.params.id)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid customer ID.',
        });
      }

      if (!req.body || typeof req.body !== 'object' ||
          Array.isArray(req.body)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid customer data.',
        });
      }

      const assignments = [];
      const values = [
        req.user.organizationId,
        req.params.id,
      ];

      for (const [field, max, required] of fields) {
        if (!Object.prototype.hasOwnProperty.call(req.body, field)) {
          continue;
        }

        const value = validateField(req.body, field, max, required);

        values.push(value);
        assignments.push(`${field} = $${values.length}`);
      }

      if (assignments.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'No customer fields supplied for update.',
        });
      }

      assignments.push('updated_at = NOW()');
      assignments.push('version = version + 1');

      const result = await pool.query(
        `UPDATE customers
         SET ${assignments.join(', ')}
         WHERE organization_id = $1
           AND id = $2
           AND deleted_at IS NULL
         RETURNING id, name, business_name, mobile, email,
                   address, gstin, pan, version, updated_at`,
        values,
      );

      if (result.rowCount === 0) {
        return res.status(404).json({
          success: false,
          error: 'Customer not found.',
        });
      }

      return res.json({
        success: true,
        message: 'Customer updated successfully.',
        customer: result.rows[0],
      });
    } catch (error) {
      if (error.code === undefined) {
        return res.status(400).json({
          success: false,
          error: error.message,
        });
      }

      console.error('Customer update failed:', error.code || 'unknown');

      return res.status(500).json({
        success: false,
        error: 'Unable to update customer.',
      });
    }
  });

  // ARCHIVE CUSTOMER
  // Related invoices, invoice items and payments are NOT modified.
  router.delete('/:id', canWrite, async (req, res) => {
    let client;
    let transactionStarted = false;

    try {
      if (!validId(req.params.id)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid customer ID.',
        });
      }

      client = await pool.connect();

      await client.query('BEGIN');
      transactionStarted = true;

      const result = await client.query(
        `UPDATE customers
         SET deleted_at = NOW(),
             deleted_by = $3,
             updated_at = NOW(),
             version = version + 1
         WHERE organization_id = $1
           AND id = $2
           AND deleted_at IS NULL
         RETURNING id`,
        [
          req.user.organizationId,
          req.params.id,
          req.user.uid,
        ],
      );

      if (result.rowCount === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;

        return res.status(404).json({
          success: false,
          error: 'Customer not found.',
        });
      }

      await client.query('COMMIT');
      transactionStarted = false;

      return res.json({
        success: true,
        message: 'Customer archived successfully. Related financial records were preserved.',
        archived: true,
        customerId: result.rows[0].id,
      });
    } catch (error) {
      if (client && transactionStarted) {
        await client.query('ROLLBACK').catch(() => {});
        transactionStarted = false;
      }

      console.error('Customer archive failed:', error.code || 'unknown');

      return res.status(500).json({
        success: false,
        error: 'Unable to archive customer.',
      });
    } finally {
      if (client) {
        client.release();
      }
    }
  });

  return router;
}

module.exports = { createCustomersRouter };