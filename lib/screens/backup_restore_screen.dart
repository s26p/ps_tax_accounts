
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color background = Color(0xFFF6F7F9);

  static const String backupFormat = 'PS_TAX_CONSULTANCY_BACKUP';
  static const int backupVersion = 1;

  bool _isBusy = false;

  String _timestamp() {
    final now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}-${two(now.month)}-${two(now.day)}'
        '_${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }

  Future<Map<String, dynamic>> _readPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, dynamic>{};

    for (final key in prefs.getKeys()) {
      if (key == 'is_logged_in') continue;

      final value = prefs.get(key);

      if (value is String ||
          value is bool ||
          value is int ||
          value is double ||
          value is List<String>) {
        result[key] = value;
      }
    }

    return result;
  }

  bool _isSupportedPreferenceValue(dynamic value) {
    if (value is String ||
        value is bool ||
        value is int ||
        value is double) {
      return true;
    }

    if (value is List) {
      return value.every((item) => item is String);
    }

    return false;
  }

  Map<String, dynamic> _validateBackup(Uint8List fileBytes) {
    if (fileBytes.isEmpty) {
      throw const FormatException('The selected backup file is empty.');
    }

    if (fileBytes.length > 100 * 1024 * 1024) {
      throw const FormatException(
        'Backup file is too large to process safely.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(utf8.decode(fileBytes));
    } on FormatException {
      throw const FormatException(
        'The backup file is not valid JSON or uses an unsupported encoding.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file structure.');
    }

    if (decoded['format'] != backupFormat) {
      throw const FormatException(
        'This is not a PS Tax Consultancy backup file.',
      );
    }

    if (decoded['version'] != backupVersion) {
      throw const FormatException(
        'Unsupported backup version.',
      );
    }

    if (decoded['database'] is! String ||
        (decoded['database'] as String).isEmpty) {
      throw const FormatException(
        'The backup does not contain database data.',
      );
    }

    if (decoded['preferences'] is! Map<String, dynamic>) {
      throw const FormatException(
        'The backup settings section is invalid.',
      );
    }

    final preferences =
        decoded['preferences'] as Map<String, dynamic>;

    for (final entry in preferences.entries) {
      if (entry.key.isEmpty ||
          entry.key == 'is_logged_in' ||
          !_isSupportedPreferenceValue(entry.value)) {
        throw FormatException(
          'Unsupported setting value in backup: ${entry.key}',
        );
      }
    }

    try {
      base64Decode(decoded['database'] as String);
    } on FormatException {
      throw const FormatException(
        'The database data in the backup is corrupted.',
      );
    }

    return decoded;
  }

  Future<void> _restorePreferences(
    Map<String, dynamic> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in values.entries) {
      final key = entry.key;
      final value = entry.value;

      // Never restore the login state from a backup.
      if (key == 'is_logged_in') continue;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List &&
          value.every((item) => item is String)) {
        await prefs.setStringList(key, value.cast<String>());
      } else {
        throw FormatException(
          'Unsupported setting value: $key',
        );
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createBackup() async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      final databaseBytes =
          await DatabaseHelper.instance.createBackupBytes();

      if (databaseBytes.isEmpty) {
        throw Exception('Database backup returned no data.');
      }

      final preferences = await _readPreferences();

      final backup = <String, dynamic>{
        'format': backupFormat,
        'version': backupVersion,
        'created_at': DateTime.now().toIso8601String(),
        'database': base64Encode(databaseBytes),
        'preferences': preferences,
      };

      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode(backup)),
      );

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save PS Tax Consultancy Backup',
        fileName: 'PS_Tax_Consultancy_${_timestamp()}.pstcbackup',
        bytes: bytes,
        mimeType: 'application/octet-stream',
      );

      if (!mounted) return;

      if (savedPath == null) {
        _message('Backup cancelled.');
      } else {
        _message('Backup saved successfully.');
      }
    } catch (e) {
      _message('Backup failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'Restoring replaces the current database with the selected '
          'backup. A safety copy of the existing database will be kept. '
          'Newer records may be lost. Create a backup of current data first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pstcbackup'],
      );

      if (picked == null) {
        _message('Restore cancelled.');
        return;
      }

      final fileBytes = await picked.readAsBytes();
      final decoded = _validateBackup(fileBytes);

      final databaseBytes = Uint8List.fromList(
        base64Decode(decoded['database'] as String),
      );

      final preferences =
          decoded['preferences'] as Map<String, dynamic>;

      // DatabaseHelper validates SQLite integrity and required tables,
      // and keeps a safety copy of the current database.
      await DatabaseHelper.instance.restoreBackupBytes(databaseBytes);

      // Restore only keys present in the backup.
      // Keys missing from the backup are intentionally left untouched.
      await _restorePreferences(preferences);

      _message(
        'Restore completed. Please close and reopen the app.',
      );
    } on FormatException catch (e) {
      _message('Backup file validation failed: ${e.message}');
    } catch (e) {
      _message('Restore failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: _isBusy ? null : onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryRed, size: 25),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFB00000)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.backup_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Protect Your Business Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Back up customers, invoices, invoice items, '
                      'payments and supported app settings.',
                      style: TextStyle(color: Colors.white, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _actionTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Create Backup',
                subtitle: 'Save a backup file to a location you choose.',
                onTap: _createBackup,
              ),
              const SizedBox(height: 12),
              _actionTile(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore Backup',
                subtitle: 'Restore from a .pstcbackup file.',
                onTap: _restoreBackup,
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Create backups regularly.\n'
                        '• Keep backup files in a safe place.\n'
                        '• Restore replaces current database records.\n'
                        '• Keep more than one backup copy.',
                        style: TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isBusy)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: primaryRed),
                        SizedBox(height: 14),
                        Text('Please wait...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
