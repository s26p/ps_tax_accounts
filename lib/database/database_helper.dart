import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  DatabaseHelper._internal();

  // ============================================================
  // DATABASE GETTER
  // ============================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    try {
      // Repair old / existing invoice_items table.
      await _repairInvoiceItemsTable(_database!);

      // Make sure permanent invoice sequence table exists.
      await _ensureInvoiceSequenceTable(_database!);

      // Install idempotent local cloud-sync metadata and queue.
      await _ensureCloudSyncSchema(_database!);

      return _database!;
    } catch (_) {
      final failedDatabase = _database;
      _database = null;
      await failedDatabase?.close();
      rethrow;
    }
  }

  // ============================================================
  // CLOUD SYNC FOUNDATION (VERSION 13)
  // ============================================================

  Future<void> _ensureCloudSyncSchema(Database db) async {
    const tableNames = <String>[
      'customers',
      'invoices',
      'invoice_items',
      'payments',
    ];

    const columnDefinitions = <String, String>{
      'sync_id': 'TEXT',
      'cloud_id': 'INTEGER',
      'sync_status': "TEXT NOT NULL DEFAULT 'pending'",
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
      'deleted_at': 'TEXT',
      'version': 'INTEGER NOT NULL DEFAULT 1',
    };

    const uuidSql =
        "lower(hex(randomblob(4))) || '-' || "
        "lower(hex(randomblob(2))) || '-4' || "
        "substr(lower(hex(randomblob(2))), 2) || '-' || "
        "substr('89ab', abs(random()) % 4 + 1, 1) || "
        "substr(lower(hex(randomblob(2))), 2) || '-' || "
        "lower(hex(randomblob(6)))";

    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          local_id INTEGER NOT NULL,
          sync_id TEXT NOT NULL,
          operation TEXT NOT NULL CHECK (operation IN ('upsert', 'delete')),
          record_version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          UNIQUE (entity_type, sync_id)
        )
      ''');

      for (final table in tableNames) {
        final info = await txn.rawQuery('PRAGMA table_info($table)');
        if (info.isEmpty) {
          throw StateError('Required SQLite table is missing: $table');
        }

        final columns = info
            .map((row) => row['name']?.toString())
            .whereType<String>()
            .toSet();

        for (final entry in columnDefinitions.entries) {
          if (!columns.contains(entry.key)) {
            await txn.execute(
              'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
        }

        // Give every existing local row a stable ID and queue it for the
        // first explicit cloud upload. Existing business fields are untouched.
        await txn.execute('''
          UPDATE $table
          SET sync_id = COALESCE(NULLIF(sync_id, ''), $uuidSql),
              created_at = COALESCE(created_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
              updated_at = COALESCE(updated_at, created_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
              sync_status = COALESCE(NULLIF(sync_status, ''), 'pending'),
              version = CASE WHEN version IS NULL OR version < 1 THEN 1 ELSE version END
          WHERE sync_id IS NULL OR sync_id = ''
             OR created_at IS NULL OR updated_at IS NULL
             OR sync_status IS NULL OR sync_status = ''
             OR version IS NULL OR version < 1
        ''');

        await txn.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_sync_id
          ON $table(sync_id)
        ''');

        await txn.execute('''
          CREATE INDEX IF NOT EXISTS idx_${table}_sync_status
          ON $table(sync_status, updated_at)
        ''');

        // First migration queue: all records not yet acknowledged by cloud.
        await txn.execute('''
          INSERT OR IGNORE INTO sync_queue (
            entity_type, local_id, sync_id, operation,
            record_version, created_at
          )
          SELECT '$table', id, sync_id,
                 CASE WHEN deleted_at IS NULL THEN 'upsert' ELSE 'delete' END,
                 version,
                 COALESCE(updated_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
          FROM $table
          WHERE sync_status <> 'synced'
            AND sync_id IS NOT NULL
            AND sync_id <> ''
        ''');

        // New local inserts automatically receive sync metadata and enter
        // the queue. A remote pull may set sync_status='synced' to avoid echo.
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_${table}_sync_after_insert
          AFTER INSERT ON $table
          WHEN COALESCE(NEW.sync_status, 'pending') <> 'synced'
          BEGIN
            UPDATE $table
            SET sync_id = COALESCE(NULLIF(NEW.sync_id, ''), $uuidSql),
                created_at = COALESCE(NEW.created_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
                updated_at = COALESCE(NEW.updated_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
                sync_status = 'pending',
                version = CASE WHEN NEW.version IS NULL OR NEW.version < 1 THEN 1 ELSE NEW.version END
            WHERE id = NEW.id;

            INSERT OR REPLACE INTO sync_queue (
              entity_type, local_id, sync_id, operation,
              record_version, created_at, attempts, last_error
            )
            SELECT '$table', id, sync_id,
                   CASE WHEN deleted_at IS NULL THEN 'upsert' ELSE 'delete' END,
                   version, updated_at, 0, NULL
            FROM $table
            WHERE id = NEW.id AND sync_status = 'pending';
          END;
        ''');

        // Existing app UPDATE statements are automatically tracked. Sync
        // acknowledgements change sync_status, so they do not re-enqueue.
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_${table}_sync_after_update
          AFTER UPDATE ON $table
          WHEN NEW.sync_status = OLD.sync_status
           AND NEW.updated_at IS OLD.updated_at
           AND NEW.version = OLD.version
          BEGIN
            UPDATE $table
            SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                sync_status = 'pending',
                version = OLD.version + 1
            WHERE id = NEW.id;

            INSERT OR REPLACE INTO sync_queue (
              entity_type, local_id, sync_id, operation,
              record_version, created_at, attempts, last_error
            )
            SELECT '$table', id, sync_id,
                   CASE WHEN deleted_at IS NULL THEN 'upsert' ELSE 'delete' END,
                   version, updated_at, 0, NULL
            FROM $table
            WHERE id = NEW.id AND sync_id IS NOT NULL;
          END;
        ''');

        // Preserve a tombstone in the queue when existing app code performs
        // a physical delete. The server can then archive by sync_id.
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS trg_${table}_sync_before_delete
          BEFORE DELETE ON $table
          WHEN OLD.sync_id IS NOT NULL AND OLD.sync_id <> ''
          BEGIN
            INSERT OR REPLACE INTO sync_queue (
              entity_type, local_id, sync_id, operation,
              record_version, created_at, attempts, last_error
            ) VALUES (
              '$table', OLD.id, OLD.sync_id, 'delete',
              OLD.version + 1,
              strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
              0, NULL
            );
          END;
        ''');
      }

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_queue_created
        ON sync_queue(id)
      ''');
    });
  }

  // Build a server-ready snapshot for one local sync queue item.
  // Parent relationships are represented by sync_id, never by local SQLite IDs.
  Future<Map<String, dynamic>?> buildSyncQueuePayload(
    Map<String, dynamic> queueItem,
  ) async {
    final db = await database;

    final entityType = queueItem['entity_type']?.toString() ?? '';
    final operation = queueItem['operation']?.toString() ?? '';
    final localId = (queueItem['local_id'] as num?)?.toInt();
    final syncId = queueItem['sync_id']?.toString() ?? '';

    const allowedTables = <String>{
      'customers',
      'invoices',
      'invoice_items',
      'payments',
    };

    if (!allowedTables.contains(entityType) ||
        localId == null ||
        localId < 1 ||
        syncId.isEmpty ||
        !<String>{'upsert', 'delete'}.contains(operation)) {
      throw StateError('Invalid local sync queue item.');
    }

    final payload = <String, dynamic>{
      'queue_id': (queueItem['id'] as num).toInt(),
      'entity_type': entityType,
      'local_id': localId,
      'sync_id': syncId,
      'operation': operation,
      'record_version': (queueItem['record_version'] as num).toInt(),
    };

    // Physical deletes have already removed the local row. The queue keeps
    // the stable sync_id tombstone needed by the cloud archive endpoint.
    if (operation == 'delete') {
      return payload;
    }

    List<Map<String, Object?>> rows;

    switch (entityType) {
      case 'customers':
        rows = await db.rawQuery(
          '''
          SELECT name, business_name, mobile, email, address, gstin, pan,
                 created_at, updated_at, version
          FROM customers
          WHERE id = ? AND sync_id = ?
          LIMIT 1
          ''',
          [localId, syncId],
        );
        break;

      case 'invoices':
        rows = await db.rawQuery(
          '''
          SELECT i.invoice_number, i.invoice_date,
                 c.sync_id AS customer_sync_id,
                 i.service, i.quantity, i.rate, i.gst_percent, i.gst_type,
                 i.subtotal, i.cgst, i.sgst, i.igst, i.gst_amount, i.total,
                 i.payment_status, i.paid_amount, i.payment_date, i.payment_mode,
                 i.created_at, i.updated_at, i.version
          FROM invoices i
          INNER JOIN customers c ON c.id = i.customer_id
          WHERE i.id = ? AND i.sync_id = ?
          LIMIT 1
          ''',
          [localId, syncId],
        );
        break;

      case 'invoice_items':
        rows = await db.rawQuery(
          '''
          SELECT i.sync_id AS invoice_sync_id,
                 it.description, it.service, it.sac_code,
                 it.quantity, it.rate, it.gst_percent, it.gst_type,
                 it.subtotal, it.cgst, it.sgst, it.igst,
                 it.gst_amount, it.total, it.amount,
                 it.created_at, it.updated_at, it.version
          FROM invoice_items it
          INNER JOIN invoices i ON i.id = it.invoice_id
          WHERE it.id = ? AND it.sync_id = ?
          LIMIT 1
          ''',
          [localId, syncId],
        );
        break;

      case 'payments':
        rows = await db.rawQuery(
          '''
          SELECT c.sync_id AS customer_sync_id,
                 i.sync_id AS invoice_sync_id,
                 p.amount, p.payment_date, p.payment_mode, p.notes,
                 p.created_at, p.updated_at, p.version
          FROM payments p
          INNER JOIN customers c ON c.id = p.customer_id
          LEFT JOIN invoices i ON i.id = p.invoice_id
          WHERE p.id = ? AND p.sync_id = ?
          LIMIT 1
          ''',
          [localId, syncId],
        );
        break;

      default:
        throw StateError('Unsupported local sync entity.');
    }

    if (rows.isEmpty) {
      return null;
    }

    payload['data'] = Map<String, dynamic>.from(rows.first);
    return payload;
  }

  // Return a bounded, oldest-first batch for the CloudSyncService.
  Future<List<Map<String, dynamic>>> getPendingSyncQueue({
    int limit = 100,
  }) async {
    final db = await database;
    final safeLimit = limit < 1 ? 1 : (limit > 500 ? 500 : limit);
    return db.query('sync_queue', orderBy: 'id ASC', limit: safeLimit);
  }

  // Call only after the server confirms this exact queue item was accepted.
  // If a newer local edit occurred while the request was in flight, keep it.
  Future<void> acknowledgeSyncQueueItem({
    required int queueId,
    required String entityType,
    required int localId,
    required String syncId,
    required int recordVersion,
    required int cloudId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final currentQueue = await txn.query(
        'sync_queue',
        where: 'id = ? AND entity_type = ? AND sync_id = ?',
        whereArgs: [queueId, entityType, syncId],
        limit: 1,
      );
      if (currentQueue.isEmpty) return;

      final currentVersion =
          (currentQueue.first['record_version'] as num?)?.toInt() ?? -1;
      if (currentVersion != recordVersion) return;

      final operation = currentQueue.first['operation']?.toString() ?? 'upsert';
      if (operation != 'delete') {
        const allowedTables = <String>{
          'customers',
          'invoices',
          'invoice_items',
          'payments',
        };
        if (!allowedTables.contains(entityType)) {
          throw ArgumentError('Unsupported sync entity: $entityType');
        }
        await txn.update(
          entityType,
          {'cloud_id': cloudId, 'sync_status': 'synced'},
          where: 'id = ? AND sync_id = ? AND version = ?',
          whereArgs: [localId, syncId, recordVersion],
        );
      } else {
        const allowedTables = <String>{
          'customers',
          'invoices',
          'invoice_items',
          'payments',
        };
        if (!allowedTables.contains(entityType)) {
          throw ArgumentError('Unsupported sync entity: $entityType');
        }
      }

      await txn.delete(
        'sync_queue',
        where: 'id = ? AND record_version = ?',
        whereArgs: [queueId, recordVersion],
      );
    });
  }

  Future<void> recordSyncFailure({
    required int queueId,
    required String message,
  }) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE sync_queue
      SET attempts = attempts + 1,
          last_error = ?
      WHERE id = ?
      ''',
      [message.length > 500 ? message.substring(0, 500) : message, queueId],
    );
  }
  // ============================================================
  // REPAIR INVOICE ITEMS TABLE
  // ============================================================

  Future<void> _repairInvoiceItemsTable(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='invoice_items'",
    );

    if (tables.isEmpty) {
      return;
    }

    var columns = await db.rawQuery('PRAGMA table_info(invoice_items)');

    var columnNames = columns
        .map((column) => column['name']?.toString())
        .whereType<String>()
        .toSet();

    // ------------------------------------------------------------
    // DESCRIPTION
    // ------------------------------------------------------------

    if (!columnNames.contains('description')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN description TEXT NOT NULL DEFAULT ''
      ''');
    }

    // ------------------------------------------------------------
    // SERVICE
    // ------------------------------------------------------------

    if (!columnNames.contains('service')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN service TEXT NOT NULL DEFAULT ''
      ''');
    }

    // ------------------------------------------------------------
    // QUANTITY
    // ------------------------------------------------------------

    if (!columnNames.contains('quantity')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN quantity REAL NOT NULL DEFAULT 1
      ''');
    }

    // ------------------------------------------------------------
    // RATE
    // ------------------------------------------------------------

    if (!columnNames.contains('rate')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN rate REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // GST PERCENT
    // ------------------------------------------------------------

    if (!columnNames.contains('gst_percent')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN gst_percent REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // GST TYPE
    // ------------------------------------------------------------

    if (!columnNames.contains('gst_type')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN gst_type TEXT NOT NULL DEFAULT 'LOCAL'
      ''');
    }

    // ------------------------------------------------------------
    // SUBTOTAL
    // ------------------------------------------------------------

    if (!columnNames.contains('subtotal')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN subtotal REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // CGST
    // ------------------------------------------------------------

    if (!columnNames.contains('cgst')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN cgst REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // SGST
    // ------------------------------------------------------------

    if (!columnNames.contains('sgst')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN sgst REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // IGST
    // ------------------------------------------------------------

    if (!columnNames.contains('igst')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN igst REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // GST AMOUNT
    // ------------------------------------------------------------

    if (!columnNames.contains('gst_amount')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN gst_amount REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // TOTAL
    // ------------------------------------------------------------

    if (!columnNames.contains('total')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN total REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // AMOUNT
    // ------------------------------------------------------------

    if (!columnNames.contains('amount')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN amount REAL NOT NULL DEFAULT 0
      ''');
    }

    // ------------------------------------------------------------
    // ------------------------------------------------------------
    // SAC CODE
    // ------------------------------------------------------------

    if (!columnNames.contains('sac_code')) {
      await db.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN sac_code TEXT NOT NULL DEFAULT ''
      ''');
    }
    // REFRESH COLUMNS
    // ------------------------------------------------------------

    columns = await db.rawQuery('PRAGMA table_info(invoice_items)');

    columnNames = columns
        .map((column) => column['name']?.toString())
        .whereType<String>()
        .toSet();

    // ------------------------------------------------------------
    // COPY SERVICE -> DESCRIPTION FOR OLD RECORDS
    // ------------------------------------------------------------

    if (columnNames.contains('description') &&
        columnNames.contains('service')) {
      await db.execute('''
        UPDATE invoice_items
        SET description = service
        WHERE description IS NULL
           OR TRIM(description) = ''
      ''');
    }

    // ------------------------------------------------------------
    // COPY TOTAL -> AMOUNT FOR OLD RECORDS
    // ------------------------------------------------------------

    if (columnNames.contains('amount') && columnNames.contains('total')) {
      await db.execute('''
        UPDATE invoice_items
        SET amount = total
        WHERE amount IS NULL
           OR amount = 0
      ''');
    }
  }

  // ============================================================
  // PERMANENT INVOICE SEQUENCE TABLE
  //
  // This table remembers the next invoice number.
  //
  // Example:
  //
  // PSTC-INV-0001
  // PSTC-INV-0002
  // PSTC-INV-0003
  //
  // If PSTC-INV-0003 is deleted,
  // PSTC-INV-0003 will NOT be reused.
  // Next number will be PSTC-INV-0004.
  // ============================================================

  Future<void> _ensureInvoiceSequenceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_sequence (
        id INTEGER PRIMARY KEY,
        next_number INTEGER NOT NULL
      )
    ''');

    final sequenceResult = await db.query(
      'invoice_sequence',
      where: 'id = 1',
      limit: 1,
    );

    // ------------------------------------------------------------
    // If sequence already exists, do nothing.
    // ------------------------------------------------------------

    if (sequenceResult.isNotEmpty) {
      return;
    }

    // ------------------------------------------------------------
    // Existing database:
    // Find the highest PSTC-INV number already used.
    // ------------------------------------------------------------

    final invoices = await db.query('invoices', columns: ['invoice_number']);

    int highestNumber = 0;

    for (final row in invoices) {
      final invoiceNumber = row['invoice_number']?.toString().trim() ?? '';

      if (invoiceNumber.isEmpty) {
        continue;
      }

      final match = RegExp(
        r'^PSTC-INV-(\d+)$',
        caseSensitive: false,
      ).firstMatch(invoiceNumber);

      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '') ?? 0;

        if (number > highestNumber) {
          highestNumber = number;
        }
      }
    }

    // ------------------------------------------------------------
    // Store the NEXT number.
    // ------------------------------------------------------------

    await db.insert('invoice_sequence', {
      'id': 1,
      'next_number': highestNumber + 1,
    });
  }

  // ============================================================
  // INITIALIZE DATABASE
  // ============================================================

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final dbPath = join(databasePath, 'ps_tax_accounts.db');

    return await openDatabase(
      dbPath,

      // Existing database version retained.
      version: 13,

      // ==========================================================
      // CREATE DATABASE
      // ==========================================================
      onCreate: (db, version) async {
        // --------------------------------------------------------
        // CUSTOMERS
        // --------------------------------------------------------

        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            business_name TEXT,
            mobile TEXT NOT NULL,
            email TEXT,
            address TEXT,
            gstin TEXT,
            pan TEXT
          )
        ''');

        // --------------------------------------------------------
        // INVOICES
        // --------------------------------------------------------

        await db.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT NOT NULL,
            invoice_date TEXT NOT NULL,
            customer_id INTEGER NOT NULL,
            service TEXT NOT NULL,
            quantity REAL NOT NULL,
            rate REAL NOT NULL,
            gst_percent REAL NOT NULL,
            gst_type TEXT NOT NULL DEFAULT 'LOCAL',
            subtotal REAL NOT NULL,
            cgst REAL NOT NULL DEFAULT 0,
            sgst REAL NOT NULL DEFAULT 0,
            igst REAL NOT NULL DEFAULT 0,
            gst_amount REAL NOT NULL,
            total REAL NOT NULL,
            payment_status TEXT NOT NULL DEFAULT 'PENDING',
            paid_amount REAL NOT NULL DEFAULT 0,
            payment_date TEXT,
            payment_mode TEXT
          )
        ''');

        // --------------------------------------------------------
        // INVOICE ITEMS
        // --------------------------------------------------------

        await db.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            service TEXT NOT NULL DEFAULT '',
            quantity REAL NOT NULL DEFAULT 1,
            rate REAL NOT NULL DEFAULT 0,
            gst_percent REAL NOT NULL DEFAULT 0,
            gst_type TEXT NOT NULL DEFAULT 'LOCAL',
            subtotal REAL NOT NULL DEFAULT 0,
            cgst REAL NOT NULL DEFAULT 0,
            sgst REAL NOT NULL DEFAULT 0,
            igst REAL NOT NULL DEFAULT 0,
            gst_amount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            amount REAL NOT NULL DEFAULT 0
          )
        ''');

        // --------------------------------------------------------
        // PAYMENTS
        // --------------------------------------------------------

        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            invoice_id INTEGER,
            amount REAL NOT NULL,
            payment_date TEXT NOT NULL,
            payment_mode TEXT NOT NULL,
            notes TEXT
          )
        ''');

        // --------------------------------------------------------
        // PERMANENT INVOICE SEQUENCE
        // --------------------------------------------------------

        await db.execute('''
          CREATE TABLE invoice_sequence (
            id INTEGER PRIMARY KEY,
            next_number INTEGER NOT NULL
          )
        ''');

        await db.insert('invoice_sequence', {'id': 1, 'next_number': 1});
      },

      // ==========================================================
      // DATABASE UPGRADE
      // ==========================================================
      onUpgrade: (db, oldVersion, newVersion) async {
        // --------------------------------------------------------
        // VERSION 2 -> 3
        // --------------------------------------------------------

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS invoices (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              invoice_number TEXT NOT NULL,
              invoice_date TEXT NOT NULL,
              customer_id INTEGER NOT NULL,
              service TEXT NOT NULL,
              quantity REAL NOT NULL,
              rate REAL NOT NULL,
              gst_percent REAL NOT NULL,
              subtotal REAL NOT NULL,
              gst_amount REAL NOT NULL,
              total REAL NOT NULL
            )
          ''');
        }

        // --------------------------------------------------------
        // VERSION 3 -> 4
        // --------------------------------------------------------

        if (oldVersion < 4) {
          final columns = await db.rawQuery('PRAGMA table_info(invoices)');

          final columnNames = columns
              .map((column) => column['name'])
              .whereType<String>()
              .toSet();

          if (!columnNames.contains('gst_type')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN gst_type TEXT NOT NULL DEFAULT 'LOCAL'
            ''');
          }

          if (!columnNames.contains('cgst')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN cgst REAL NOT NULL DEFAULT 0
            ''');
          }

          if (!columnNames.contains('sgst')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN sgst REAL NOT NULL DEFAULT 0
            ''');
          }

          if (!columnNames.contains('igst')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN igst REAL NOT NULL DEFAULT 0
            ''');
          }
        }

        // --------------------------------------------------------
        // VERSION 4 -> 5
        // --------------------------------------------------------

        if (oldVersion < 5) {
          final columns = await db.rawQuery('PRAGMA table_info(invoices)');

          final columnNames = columns
              .map((column) => column['name'])
              .whereType<String>()
              .toSet();

          if (!columnNames.contains('gst_type')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN gst_type TEXT NOT NULL DEFAULT 'LOCAL'
            ''');
          }

          if (!columnNames.contains('cgst')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN cgst REAL NOT NULL DEFAULT 0
            ''');
          }

          if (!columnNames.contains('sgst')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN sgst REAL NOT NULL DEFAULT 0
            ''');
          }

          if (!columnNames.contains('igst')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN igst REAL NOT NULL DEFAULT 0
            ''');
          }
        }

        // --------------------------------------------------------
        // VERSION 5 -> 6
        // --------------------------------------------------------

        if (oldVersion < 6) {
          final columns = await db.rawQuery('PRAGMA table_info(invoices)');

          final columnNames = columns
              .map((column) => column['name'])
              .whereType<String>()
              .toSet();

          if (!columnNames.contains('payment_status')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'PENDING'
            ''');
          }

          if (!columnNames.contains('paid_amount')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0
            ''');
          }

          if (!columnNames.contains('payment_date')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN payment_date TEXT
            ''');
          }

          if (!columnNames.contains('payment_mode')) {
            await db.execute('''
              ALTER TABLE invoices
              ADD COLUMN payment_mode TEXT
            ''');
          }
        }

        // --------------------------------------------------------
        // VERSION 6 -> 7
        // --------------------------------------------------------

        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_id INTEGER NOT NULL,
              invoice_id INTEGER,
              amount REAL NOT NULL,
              payment_date TEXT NOT NULL,
              payment_mode TEXT NOT NULL,
              notes TEXT
            )
          ''');
        }

        // --------------------------------------------------------
        // VERSION 7 -> 8
        // --------------------------------------------------------

        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS invoice_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              invoice_id INTEGER NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              service TEXT NOT NULL DEFAULT '',
              quantity REAL NOT NULL DEFAULT 1,
              rate REAL NOT NULL DEFAULT 0,
              gst_percent REAL NOT NULL DEFAULT 0,
              gst_type TEXT NOT NULL DEFAULT 'LOCAL',
              subtotal REAL NOT NULL DEFAULT 0,
              cgst REAL NOT NULL DEFAULT 0,
              sgst REAL NOT NULL DEFAULT 0,
              igst REAL NOT NULL DEFAULT 0,
              gst_amount REAL NOT NULL DEFAULT 0,
              total REAL NOT NULL DEFAULT 0
            )
          ''');
        }

        // --------------------------------------------------------
        // VERSION 8 -> 9
        // --------------------------------------------------------

        if (oldVersion < 9) {
          // No new columns.
        }

        // --------------------------------------------------------
        // VERSION 9 -> 10
        // --------------------------------------------------------

        if (oldVersion < 10) {
          // Automatic repair.
        }

        // --------------------------------------------------------
        // VERSION 10 -> 11
        // --------------------------------------------------------

        if (oldVersion < 11) {
          // Automatic repair.
        }

        // --------------------------------------------------------
        // VERSION 11 -> 12
        // --------------------------------------------------------

        if (oldVersion < 12) {
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='invoice_items'",
          );

          if (tables.isNotEmpty) {
            final columns = await db.rawQuery(
              'PRAGMA table_info(invoice_items)',
            );

            final columnNames = columns
                .map((column) => column['name'])
                .whereType<String>()
                .toSet();

            if (!columnNames.contains('amount')) {
              await db.execute('''
                ALTER TABLE invoice_items
                ADD COLUMN amount REAL NOT NULL DEFAULT 0
              ''');
            }

            await db.execute('''
              UPDATE invoice_items
              SET amount = total
              WHERE amount = 0
            ''');
          }
        }
      },
    );
  }

  // ============================================================
  // CUSTOMER
  // ============================================================

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;

    return await db.insert('customers', customer);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;

    return await db.query('customers', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getCustomerById(int customerId) async {
    final db = await database;

    final result = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<int> updateCustomer(
    int customerId,
    Map<String, dynamic> customer,
  ) async {
    final db = await database;

    return await db.update(
      'customers',
      customer,
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<int> deleteCustomer(int customerId) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      await txn.delete(
        'payments',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );

      final invoices = await txn.query(
        'invoices',
        columns: ['id'],
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );

      for (final invoice in invoices) {
        final invoiceId = invoice['id'] as int;

        await txn.delete(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );
      }

      await txn.delete(
        'invoices',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );

      return await txn.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
      );
    });
  }

  Future<int> getCustomerCount() async {
    final db = await database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM customers');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============================================================
  // INVOICE
  // ============================================================

  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await database;

    return await db.insert('invoices', invoice);
  }

  // ============================================================
  // INSERT INVOICE WITH ITEMS
  // ============================================================

  Future<int> insertInvoiceWithItems({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      final invoiceId = await txn.insert('invoices', invoice);

      for (final item in items) {
        final service =
            item['service']?.toString() ??
            item['description']?.toString() ??
            '';
        final sacCode = item['sac_code']?.toString().trim() ?? '';

        final description =
            item['description']?.toString().trim().isNotEmpty == true
            ? item['description'].toString()
            : service;

        final quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;

        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;

        final gstPercent = (item['gst_percent'] as num?)?.toDouble() ?? 0.0;

        final gstType = item['gst_type']?.toString() ?? 'LOCAL';

        final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;

        final cgst = (item['cgst'] as num?)?.toDouble() ?? 0.0;

        final sgst = (item['sgst'] as num?)?.toDouble() ?? 0.0;

        final igst = (item['igst'] as num?)?.toDouble() ?? 0.0;

        final gstAmount = (item['gst_amount'] as num?)?.toDouble() ?? 0.0;

        final total = (item['total'] as num?)?.toDouble() ?? 0.0;

        final amount = (item['amount'] as num?)?.toDouble() ?? total;

        await txn.rawInsert(
          '''
          INSERT INTO invoice_items (
            invoice_id,
            description,
            service,
            sac_code,
            quantity,
            rate,
            gst_percent,
            gst_type,
            subtotal,
            cgst,
            sgst,
            igst,
            gst_amount,
            total,
            amount
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            description,
            service,
            sacCode,
            quantity,
            rate,
            gstPercent,
            gstType,
            subtotal,
            cgst,
            sgst,
            igst,
            gstAmount,
            total,
            amount,
          ],
        );
      }

      return invoiceId;
    });
  }

  // ============================================================
  // GET INVOICES
  // ============================================================

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final db = await database;

    return await db.query('invoices', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getInvoiceById(int invoiceId) async {
    final db = await database;

    final result = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ============================================================
  // GET INVOICE ITEMS
  // ============================================================

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final db = await database;

    return await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );
  }

  // ============================================================
  // UPDATE INVOICE
  // ============================================================

  Future<int> updateInvoice(int invoiceId, Map<String, dynamic> invoice) async {
    final db = await database;

    return await db.update(
      'invoices',
      invoice,
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  // ============================================================
  // UPDATE INVOICE WITH ITEMS
  // ============================================================

  Future<int> updateInvoiceWithItems({
    required int invoiceId,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      await txn.update(
        'invoices',
        invoice,
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      for (final item in items) {
        final service =
            item['service']?.toString() ??
            item['description']?.toString() ??
            '';
        final sacCode = item['sac_code']?.toString().trim() ?? '';

        final description =
            item['description']?.toString().trim().isNotEmpty == true
            ? item['description'].toString()
            : service;

        final quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;

        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;

        final gstPercent = (item['gst_percent'] as num?)?.toDouble() ?? 0.0;

        final gstType = item['gst_type']?.toString() ?? 'LOCAL';

        final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;

        final cgst = (item['cgst'] as num?)?.toDouble() ?? 0.0;

        final sgst = (item['sgst'] as num?)?.toDouble() ?? 0.0;

        final igst = (item['igst'] as num?)?.toDouble() ?? 0.0;

        final gstAmount = (item['gst_amount'] as num?)?.toDouble() ?? 0.0;

        final total = (item['total'] as num?)?.toDouble() ?? 0.0;

        final amount = (item['amount'] as num?)?.toDouble() ?? total;

        await txn.rawInsert(
          '''
          INSERT INTO invoice_items (
            invoice_id,
            description,
            service,
            sac_code,
            quantity,
            rate,
            gst_percent,
            gst_type,
            subtotal,
            cgst,
            sgst,
            igst,
            gst_amount,
            total,
            amount
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            description,
            service,
            sacCode,
            quantity,
            rate,
            gstPercent,
            gstType,
            subtotal,
            cgst,
            sgst,
            igst,
            gstAmount,
            total,
            amount,
          ],
        );
      }

      return invoiceId;
    });
  }

  // ============================================================
  // DELETE INVOICE
  // ============================================================

  Future<int> deleteInvoice(int invoiceId) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      await txn.delete(
        'payments',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      return await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    });
  }

  Future<int> deleteInvoiceItems(int invoiceId) async {
    final db = await database;

    return await db.delete(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<int> getInvoiceCount() async {
    final db = await database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM invoices');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============================================================
  // TOTAL BILLING
  // ============================================================

  Future<double> getTotalInvoiceAmount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(total) as total FROM invoices',
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }

    return (result.first['total'] as num).toDouble();
  }

  // ============================================================
  // TOTAL PAID
  // ============================================================

  Future<double> getTotalPaidAmount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments',
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }

    return (result.first['total'] as num).toDouble();
  }

  // ============================================================
  // TOTAL OUTSTANDING
  // ============================================================

  Future<double> getTotalOutstandingAmount() async {
    final totalInvoice = await getTotalInvoiceAmount();

    final totalPaid = await getTotalPaidAmount();

    final outstanding = totalInvoice - totalPaid;

    if (outstanding < 0) {
      return 0.0;
    }

    return outstanding;
  }

  // ============================================================
  // OLD INVOICE PAYMENT UPDATE
  // ============================================================

  Future<int> updateInvoicePayment({
    required int invoiceId,
    required double paidAmount,
    required String paymentDate,
    required String paymentMode,
  }) async {
    final db = await database;

    final invoiceResult = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );

    if (invoiceResult.isEmpty) {
      return 0;
    }

    final invoice = invoiceResult.first;

    final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;

    final oldPaidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;

    final newPaidAmount = oldPaidAmount + paidAmount;

    String paymentStatus;

    if (newPaidAmount >= total) {
      paymentStatus = 'PAID';
    } else if (newPaidAmount > 0) {
      paymentStatus = 'PARTIAL';
    } else {
      paymentStatus = 'PENDING';
    }

    return await db.update(
      'invoices',
      {
        'payment_status': paymentStatus,
        'paid_amount': newPaidAmount,
        'payment_date': paymentDate,
        'payment_mode': paymentMode,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await database;

    return await db.insert('payments', payment);
  }

  Future<List<Map<String, dynamic>>> getCustomerPayments(int customerId) async {
    final db = await database;

    return await db.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'payment_date DESC, id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getInvoicePayments(int invoiceId) async {
    final db = await database;

    return await db.query(
      'payments',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'payment_date DESC, id DESC',
    );
  }

  Future<double> getCustomerTotalPaid(int customerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM payments
      WHERE customer_id = ?
      ''',
      [customerId],
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getCustomerTotalInvoiced(int customerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(total) as total
      FROM invoices
      WHERE customer_id = ?
      ''',
      [customerId],
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getCustomerOutstanding(int customerId) async {
    final totalInvoiced = await getCustomerTotalInvoiced(customerId);

    final totalPaid = await getCustomerTotalPaid(customerId);

    final outstanding = totalInvoiced - totalPaid;

    if (outstanding < 0) {
      return 0.0;
    }

    return outstanding;
  }

  Future<List<Map<String, dynamic>>> getAllPayments() async {
    final db = await database;

    return await db.query('payments', orderBy: 'payment_date DESC, id DESC');
  }

  Future<int> deletePayment(int paymentId) async {
    final db = await database;

    return await db.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  // ============================================================
  // NEXT INVOICE NUMBER
  //
  // PERMANENT SEQUENCE
  //
  // PSTC-INV-0001
  // PSTC-INV-0002
  // PSTC-INV-0003
  //
  // IMPORTANT:
  // Once a number is issued, it is never reused.
  // Even if that invoice is deleted.
  // ============================================================

  Future<String> getNextInvoiceNumber() async {
    final db = await database;

    return await db.transaction<String>((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS invoice_sequence (
          id INTEGER PRIMARY KEY,
          next_number INTEGER NOT NULL
        )
      ''');

      final sequenceRows = await txn.query(
        'invoice_sequence',
        where: 'id = 1',
        limit: 1,
      );

      int nextNumber = 1;
      bool repairSequence = sequenceRows.isEmpty;

      if (sequenceRows.isNotEmpty) {
        final storedValue =
            (sequenceRows.first['next_number'] as num?)?.toInt() ?? 1;

        // Repair a timestamp-sized or invalid sequence value.
        if (storedValue < 1 || storedValue > 999999) {
          repairSequence = true;
        } else {
          nextNumber = storedValue;
        }
      }

      if (repairSequence) {
        final invoices = await txn.query(
          'invoices',
          columns: ['invoice_number'],
        );

        int highestNumber = 0;

        for (final row in invoices) {
          final value = row['invoice_number']?.toString().trim() ?? '';

          final match = RegExp(
            r'^PSTC-INV-(\d+)$',
            caseSensitive: false,
          ).firstMatch(value);

          if (match != null) {
            final number = int.tryParse(match.group(1) ?? '') ?? 0;

            // Ignore old timestamp-style numbers.
            if (number >= 1 && number <= 999999 && number > highestNumber) {
              highestNumber = number;
            }
          }
        }

        nextNumber = highestNumber + 1;
      }

      if (sequenceRows.isEmpty) {
        await txn.insert('invoice_sequence', {
          'id': 1,
          'next_number': nextNumber + 1,
        });
      } else {
        await txn.update('invoice_sequence', {
          'next_number': nextNumber + 1,
        }, where: 'id = 1');
      }

      return 'PSTC-INV-${nextNumber.toString().padLeft(4, '0')}';
    });
  }

  // ============================================================
  // CREATE DATABASE BACKUP
  // ============================================================

  Future<Uint8List> createBackupBytes() async {
    final db = await database;
    final dbPath = db.path;

    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await db.rawQuery('PRAGMA journal_mode=DELETE');
    await db.close();
    _database = null;

    try {
      final file = File(dbPath);

      if (!await file.exists()) {
        throw Exception('Database file not found.');
      }

      final bytes = await file.readAsBytes();
      await database;
      return bytes;
    } catch (_) {
      _database = null;
      try {
        await database;
      } catch (_) {
        _database = null;
      }
      rethrow;
    }
  }

  // ============================================================
  // RESTORE DATABASE BACKUP
  // ============================================================

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    if (bytes.length < 100) {
      throw Exception('Backup file is too small.');
    }

    if (String.fromCharCodes(bytes.take(16)) != 'SQLite format 3\u0000') {
      throw Exception('Invalid SQLite backup file.');
    }

    final directory = await getDatabasesPath();
    final dbPath = join(directory, 'ps_tax_accounts.db');
    final stagedPath = join(directory, 'restore_staged.db');
    final validationPath = join(directory, 'restore_validation.db');

    final currentFile = File(dbPath);
    final stagedFile = File(stagedPath);
    final validationFile = File(validationPath);

    if (await stagedFile.exists()) await stagedFile.delete();
    if (await validationFile.exists()) await validationFile.delete();

    await validationFile.writeAsBytes(bytes, flush: true);

    final validationDb = await openDatabase(validationPath, readOnly: true);

    try {
      final integrity = await validationDb.rawQuery('PRAGMA integrity_check');

      if (integrity.isEmpty ||
          integrity.first.values.first?.toString() != 'ok') {
        throw Exception('Backup integrity check failed.');
      }

      final rows = await validationDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final tables = rows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();

      const requiredTables = [
        'customers',
        'invoices',
        'invoice_items',
        'payments',
        'invoice_sequence',
      ];

      for (final table in requiredTables) {
        if (!tables.contains(table)) {
          throw Exception('Backup is missing table: $table');
        }
      }
    } finally {
      await validationDb.close();
      if (await validationFile.exists()) {
        await validationFile.delete();
      }
    }

    await stagedFile.writeAsBytes(bytes, flush: true);

    if (_database != null) {
      final currentDb = _database!;
      await currentDb.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await currentDb.rawQuery('PRAGMA journal_mode=DELETE');
      await currentDb.close();
      _database = null;
    }

    if (!await currentFile.exists()) {
      await stagedFile.delete();
      throw Exception('Current database file not found.');
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final safetyFile = File('$dbPath.pre_restore_$timestamp');
    await currentFile.copy(safetyFile.path);

    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');

    try {
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      await currentFile.delete();
      await stagedFile.rename(dbPath);

      _database = null;
      await database;
    } catch (_) {
      _database = null;

      try {
        if (await currentFile.exists()) await currentFile.delete();
        if (await safetyFile.exists()) {
          await safetyFile.copy(dbPath);
        }
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();
        await database;
      } catch (_) {
        _database = null;
      }

      rethrow;
    }
  }
}
