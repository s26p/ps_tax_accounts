const express = require('express');

function createSyncRouter({ pool, requireFirebaseAuth }) {
  if (!pool || typeof requireFirebaseAuth !== 'function') {
    throw new Error('Cloud sync router configuration is incomplete.');
  }

  const router = express.Router();
  router.use(requireFirebaseAuth);

  const TABLES = new Set([
    'customers',
    'invoices',
    'invoice_items',
    'payments',
  ]);

  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

  class SyncRequestError extends Error {
    constructor(status, message) {
      super(message);
      this.status = status;
    }
  }

  function requireWriter(req, res, next) {
    if (!['owner', 'admin'].includes(req.user.organizationRole)) {
      return res.status(403).json({
        success: false,
        error: 'Read-only access. Admin permission is required.',
      });
    }
    return next();
  }

  function positiveInteger(value, field) {
    const number = Number(value);
    if (!Number.isSafeInteger(number) || number < 1) {
      throw new SyncRequestError(400, `Invalid ${field}.`);
    }
    return number;
  }

  function readText(value, field, maxLength, required = false, emptyAsNull = true) {
    if (value === undefined || value === null) {
      if (required) throw new SyncRequestError(400, `${field} is required.`);
      return null;
    }
    if (typeof value !== 'string') {
      throw new SyncRequestError(400, `${field} must be text.`);
    }
    const cleaned = value.trim();
    if (required && !cleaned) {
      throw new SyncRequestError(400, `${field} cannot be empty.`);
    }
    if (cleaned.length > maxLength) {
      throw new SyncRequestError(400, `${field} exceeds the allowed length.`);
    }
    return emptyAsNull && cleaned === '' ? null : cleaned;
  }

  function readNumber(value, field, fallback = 0) {
    if (value === undefined || value === null || value === '') return fallback;
    const number = Number(value);
    if (!Number.isFinite(number)) {
      throw new SyncRequestError(400, `${field} must be a valid number.`);
    }
    return number;
  }

  function readDate(value, field, fallback = new Date()) {
    if (value === undefined || value === null || value === '') return fallback;
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      throw new SyncRequestError(400, `Invalid ${field}.`);
    }
    return parsed;
  }

  function readGstType(value) {
    const gstType = String(value || 'LOCAL').trim().toUpperCase();
    if (!['LOCAL', 'INTERSTATE', 'WITHOUT_GST'].includes(gstType)) {
      throw new SyncRequestError(400, 'Invalid GST type.');
    }
    return gstType;
  }

  async function findIdBySyncId(client, table, organizationId, syncId) {
    if (!TABLES.has(table)) throw new Error('Internal table selection error.');
    const result = await client.query(
      `SELECT id FROM ${table} WHERE organization_id = $1 AND sync_id = $2 LIMIT 1`,
      [organizationId, syncId],
    );
    return result.rowCount ? result.rows[0].id : null;
  }

  async function findCustomerId(client, organizationId, customerSyncId) {
    if (typeof customerSyncId !== 'string' || !UUID_RE.test(customerSyncId)) {
      throw new SyncRequestError(409, 'Invoice or payment is missing a valid customer sync_id.');
    }
    const id = await findIdBySyncId(client, 'customers', organizationId, customerSyncId);
    if (id === null) {
      throw new SyncRequestError(409, 'Customer must sync before its invoice or payment. Retry sync.');
    }
    return id;
  }

  async function findInvoice(client, organizationId, invoiceSyncId) {
    if (typeof invoiceSyncId !== 'string' || !UUID_RE.test(invoiceSyncId)) {
      throw new SyncRequestError(409, 'Invoice item is missing a valid invoice sync_id.');
    }
    const result = await client.query(
      `SELECT id, customer_id FROM invoices
       WHERE organization_id = $1 AND sync_id = $2 LIMIT 1`,
      [organizationId, invoiceSyncId],
    );
    if (!result.rowCount) {
      throw new SyncRequestError(409, 'Invoice must sync before its items or linked payments. Retry sync.');
    }
    return result.rows[0];
  }

  async function upsertRecord(client, organizationId, entityType, syncId, data) {
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      throw new SyncRequestError(400, 'Upsert record data is invalid.');
    }

    const createdAt = readDate(data.created_at, 'created_at');
    const updatedAt = readDate(data.updated_at, 'updated_at');
    const sourceVersion = positiveInteger(data.version ?? 1, 'version');
    let fields;
    let values;

    if (entityType === 'customers') {
      fields = [
        'name', 'business_name', 'mobile', 'email', 'address', 'gstin', 'pan',
      ];
      values = [
        readText(data.name, 'name', 200, true, false),
        readText(data.business_name, 'business_name', 250),
        readText(data.mobile, 'mobile', 40, true, false),
        readText(data.email, 'email', 254),
        readText(data.address, 'address', 2000),
        readText(data.gstin, 'gstin', 15)?.toUpperCase() ?? null,
        readText(data.pan, 'pan', 10)?.toUpperCase() ?? null,
      ];
    } else if (entityType === 'invoices') {
      const customerId = await findCustomerId(
        client, organizationId, data.customer_sync_id,
      );
      fields = [
        'invoice_number', 'invoice_date', 'customer_id', 'service',
        'quantity', 'rate', 'gst_percent', 'gst_type', 'subtotal',
        'cgst', 'sgst', 'igst', 'gst_amount', 'total',
        'payment_status', 'paid_amount', 'payment_date', 'payment_mode',
      ];
      values = [
        readText(data.invoice_number, 'invoice_number', 80, true, false),
        readText(data.invoice_date, 'invoice_date', 40, true, false),
        customerId,
        readText(data.service, 'service', 500, true, false),
        readNumber(data.quantity, 'quantity', 1),
        readNumber(data.rate, 'rate'),
        readNumber(data.gst_percent, 'gst_percent'),
        readGstType(data.gst_type),
        readNumber(data.subtotal, 'subtotal'),
        readNumber(data.cgst, 'cgst'),
        readNumber(data.sgst, 'sgst'),
        readNumber(data.igst, 'igst'),
        readNumber(data.gst_amount, 'gst_amount'),
        readNumber(data.total, 'total'),
        readText(data.payment_status, 'payment_status', 30, false) || 'PENDING',
        readNumber(data.paid_amount, 'paid_amount'),
        readText(data.payment_date, 'payment_date', 40),
        readText(data.payment_mode, 'payment_mode', 80),
      ];
    } else if (entityType === 'invoice_items') {
      const invoice = await findInvoice(
        client, organizationId, data.invoice_sync_id,
      );
      fields = [
        'invoice_id', 'description', 'service', 'sac_code', 'quantity',
        'rate', 'gst_percent', 'gst_type', 'subtotal', 'cgst', 'sgst',
        'igst', 'gst_amount', 'total', 'amount',
      ];
      values = [
        invoice.id,
        readText(data.description, 'description', 1000) || '',
        readText(data.service, 'service', 1000) || '',
        readText(data.sac_code, 'sac_code', 30) || '',
        readNumber(data.quantity, 'quantity', 1),
        readNumber(data.rate, 'rate'),
        readNumber(data.gst_percent, 'gst_percent'),
        readGstType(data.gst_type),
        readNumber(data.subtotal, 'subtotal'),
        readNumber(data.cgst, 'cgst'),
        readNumber(data.sgst, 'sgst'),
        readNumber(data.igst, 'igst'),
        readNumber(data.gst_amount, 'gst_amount'),
        readNumber(data.total, 'total'),
        readNumber(data.amount, 'amount', readNumber(data.total, 'total')),
      ];
    } else if (entityType === 'payments') {
      const customerId = await findCustomerId(
        client, organizationId, data.customer_sync_id,
      );
      let invoiceId = null;
      if (data.invoice_sync_id !== undefined && data.invoice_sync_id !== null && data.invoice_sync_id !== '') {
        const invoice = await findInvoice(
          client, organizationId, data.invoice_sync_id,
        );
        if (String(invoice.customer_id) !== String(customerId)) {
          throw new SyncRequestError(409, 'Payment customer and invoice do not match.');
        }
        invoiceId = invoice.id;
      }
      fields = [
        'customer_id', 'invoice_id', 'amount', 'payment_date', 'payment_mode', 'notes',
      ];
      values = [
        customerId,
        invoiceId,
        readNumber(data.amount, 'amount'),
        readText(data.payment_date, 'payment_date', 40, true, false),
        readText(data.payment_mode, 'payment_mode', 80, true, false),
        readText(data.notes, 'notes', 2000),
      ];
    } else {
      throw new SyncRequestError(400, 'Unsupported sync entity.');
    }

    const columns = [
      'organization_id', 'sync_id', ...fields, 'created_at', 'updated_at', 'version',
    ];
    const parameters = [organizationId, syncId, ...values, createdAt, updatedAt, sourceVersion];
    const placeholders = parameters.map((_, index) => `$${index + 1}`).join(', ');
    const assignments = fields.map((field) => `${field} = EXCLUDED.${field}`);
    assignments.push(
      'updated_at = EXCLUDED.updated_at',
      'version = EXCLUDED.version',
      'deleted_at = NULL',
      'deleted_by = NULL',
    );

    const sql = `
      INSERT INTO ${entityType} (${columns.join(', ')})
      VALUES (${placeholders})
      ON CONFLICT (organization_id, sync_id)
      DO UPDATE SET ${assignments.join(', ')}
      WHERE EXCLUDED.version > ${entityType}.version
         OR (EXCLUDED.version = ${entityType}.version AND EXCLUDED.updated_at > ${entityType}.updated_at)
      RETURNING id
    `;

    const result = await client.query(sql, parameters);
    if (result.rowCount) return result.rows[0].id;

    // A retry or older edit can legitimately produce no UPDATE. Return the
    // already-existing cloud ID so the matching local queue item can be acked.
    const existingId = await findIdBySyncId(
      client, entityType, organizationId, syncId,
    );
    if (existingId === null) {
      throw new SyncRequestError(409, 'Cloud record was not found after upsert.');
    }
    return existingId;
  }

  async function applyDelete(client, organizationId, entityType, syncId, sourceVersion, userId) {
    // Lock the organization-scoped cloud row so a concurrent update cannot
    // pass the version check between reading and archiving it.
    const existing = await client.query(
      `SELECT id, version, deleted_at
       FROM ${entityType}
       WHERE organization_id = $1 AND sync_id = $2
       LIMIT 1
       FOR UPDATE`,
      [organizationId, syncId],
    );

    // A record deleted locally before its first upload has no cloud row.
    // There is nothing to archive, so this tombstone can be acknowledged.
    if (!existing.rowCount) return null;

    const row = existing.rows[0];
    const cloudVersion = Number(row.version);
    if (!Number.isSafeInteger(cloudVersion) || cloudVersion < 1) {
      throw new SyncRequestError(500, 'Cloud record version is invalid.');
    }

    const alreadyDeleted = row.deleted_at !== null;

    if (sourceVersion < cloudVersion) {
      throw new SyncRequestError(
        409,
        'A newer cloud version exists. Refresh and resolve the record before retrying this delete.',
      );
    }

    // Repeated delivery of the same delete is idempotent.
    if (alreadyDeleted && sourceVersion === cloudVersion) {
      return row.id;
    }

    if (!alreadyDeleted && sourceVersion <= cloudVersion) {
      throw new SyncRequestError(
        409,
        'Delete version is not newer than the active cloud record. Refresh and retry.',
      );
    }

    const archived = await client.query(
      `UPDATE ${entityType}
       SET deleted_at = COALESCE(deleted_at, NOW()),
           deleted_by = $3,
           updated_at = NOW(),
           version = $4
       WHERE organization_id = $1
         AND sync_id = $2
         AND version = $5
       RETURNING id`,
      [organizationId, syncId, userId, sourceVersion, cloudVersion],
    );

    if (!archived.rowCount) {
      throw new SyncRequestError(
        409,
        'Cloud record changed during delete. Refresh and retry.',
      );
    }

    return archived.rows[0].id;
  }

  router.get('/status', (req, res) => {
    return res.json({ success: true, service: 'PS Tax Consultancy Cloud Sync API' });
  });

  router.post('/push', requireWriter, async (req, res) => {
    const records = req.body?.records;
    if (!Array.isArray(records) || records.length < 1 || records.length > 100) {
      return res.status(400).json({
        success: false,
        error: 'records must contain between 1 and 100 queue items.',
      });
    }

    let client;
    try {
      client = await pool.connect();
      await client.query('BEGIN');

      const results = [];
      for (const record of records) {
        if (!record || typeof record !== 'object' || Array.isArray(record)) {
          throw new SyncRequestError(400, 'Invalid queue item.');
        }

        const queueId = positiveInteger(record.queue_id, 'queue_id');
        const localId = positiveInteger(record.local_id, 'local_id');
        const recordVersion = positiveInteger(record.record_version, 'record_version');
        const entityType = record.entity_type;
        const operation = record.operation;
        const syncId = record.sync_id;

        if (!TABLES.has(entityType)) {
          throw new SyncRequestError(400, 'Unsupported sync entity.');
        }
        if (!['upsert', 'delete'].includes(operation)) {
          throw new SyncRequestError(400, 'Unsupported sync operation.');
        }
        if (typeof syncId !== 'string' || !UUID_RE.test(syncId)) {
          throw new SyncRequestError(400, 'Invalid sync_id.');
        }

        let cloudId;
        if (operation === 'delete') {
          cloudId = await applyDelete(
            client, req.user.organizationId, entityType, syncId, recordVersion, req.user.uid,
          );
        } else {
          cloudId = await upsertRecord(
            client, req.user.organizationId, entityType, syncId, record.data,
          );
        }

        const numericCloudId = cloudId === null ? null : Number(cloudId);
        if (numericCloudId !== null && !Number.isSafeInteger(numericCloudId)) {
          throw new SyncRequestError(500, 'Cloud record ID exceeds the supported integer range.');
        }

        results.push({
          queue_id: queueId,
          entity_type: entityType,
          local_id: localId,
          sync_id: syncId,
          operation,
          record_version: recordVersion,
          cloud_id: numericCloudId,
        });
      }

      await client.query('COMMIT');
      return res.json({ success: true, accepted: results.length, results });
    } catch (error) {
      if (client) await client.query('ROLLBACK').catch(() => {});
      if (error instanceof SyncRequestError) {
        return res.status(error.status).json({ success: false, error: error.message });
      }

      console.error('Cloud sync push failed:', error.code || 'unknown');
      if (error.code === '23505') {
        return res.status(409).json({
          success: false,
          error: 'A conflicting record already exists. Check invoice numbering and sync dependencies.',
        });
      }
      if (error.code === '23503') {
        return res.status(409).json({
          success: false,
          error: 'A related customer or invoice must sync first. Retry the queue in order.',
        });
      }
      return res.status(500).json({ success: false, error: 'Unable to sync records.' });
    } finally {
      if (client) client.release();
    }
  });

  return router;
}

module.exports = { createSyncRouter };
