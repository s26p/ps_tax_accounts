import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../database/database_helper.dart';

/// Result of one explicit Cloud Sync action. This service does not sync
/// automatically; the app must call syncPending() from a deliberate action.
class CloudSyncReport {
  const CloudSyncReport({
    required this.success,
    required this.acceptedCount,
    required this.pendingCount,
    this.message,
  });

  final bool success;
  final int acceptedCount;
  final int pendingCount;
  final String? message;
}

class CloudSyncService {
  CloudSyncService({
    String? baseUrl,
    DatabaseHelper? databaseHelper,
    FirebaseAuth? firebaseAuth,
  }) : _baseUrl = (baseUrl ?? _configuredBaseUrl).trim().replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _database = databaseHelper ?? DatabaseHelper.instance,
       _auth = firebaseAuth ?? FirebaseAuth.instance;

  static const String _configuredBaseUrl = String.fromEnvironment(
    'PSTC_API_BASE_URL',
  );

  final String _baseUrl;
  final DatabaseHelper _database;
  final FirebaseAuth _auth;

  Uri _endpoint(String path) {
    if (_baseUrl.isEmpty) {
      throw StateError(
        'Cloud API URL is not configured. Set PSTC_API_BASE_URL using --dart-define.',
      );
    }

    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasAuthority || base.host.isEmpty) {
      throw StateError('Cloud API URL is invalid.');
    }

    // Production traffic must use HTTPS. Plain HTTP is allowed only for
    // loopback development on the same computer.
    final isLoopback = base.host == '127.0.0.1' || base.host == 'localhost';
    if (base.scheme != 'https' && !(base.scheme == 'http' && isLoopback)) {
      throw StateError(
        'Cloud API must use HTTPS outside local loopback testing.',
      );
    }

    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$prefix$path', query: null, fragment: null);
  }

  Future<String> _firebaseIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before using Cloud Sync.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Firebase could not provide an ID token. Please sign in again.',
      );
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // A non-JSON response is reported below without exposing its body.
    }
    throw const FormatException('The Cloud API returned an invalid response.');
  }

  /// Checks the authenticated Cloud Sync status without sending local data.
  Future<Map<String, dynamic>> checkStatus() async {
    final token = await _firebaseIdToken();
    final response = await http
        .get(_endpoint('/api/sync/status'), headers: _headers(token))
        .timeout(const Duration(seconds: 20));

    final body = _decodeResponse(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw StateError(
        body['error']?.toString() ?? 'Cloud Sync status check failed.',
      );
    }
    return body;
  }

  /// Sends one bounded batch. Call this only after the user explicitly
  /// chooses Sync and after the API has been deployed/configured securely.
  Future<CloudSyncReport> syncPending({int batchSize = 100}) async {
    final safeBatchSize = batchSize < 1
        ? 1
        : (batchSize > 100 ? 100 : batchSize);
    final queue = await _database.getPendingSyncQueue(limit: safeBatchSize);

    if (queue.isEmpty) {
      return const CloudSyncReport(
        success: true,
        acceptedCount: 0,
        pendingCount: 0,
        message: 'There are no pending records to sync.',
      );
    }

    try {
      final token = await _firebaseIdToken();
      final records = <Map<String, dynamic>>[];

      for (final queueItem in queue) {
        final payload = await _database.buildSyncQueuePayload(queueItem);
        if (payload == null) {
          throw StateError(
            'A queued local record could not be found. Queue item: ${queueItem['id']}',
          );
        }
        records.add(payload);
      }

      final response = await http
          .post(
            _endpoint('/api/sync/push'),
            headers: _headers(token),
            body: jsonEncode({'records': records}),
          )
          .timeout(const Duration(seconds: 45));

      final body = _decodeResponse(response);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true ||
          body['results'] is! List) {
        throw StateError(
          body['error']?.toString() ??
              'Cloud Sync push failed (HTTP ${response.statusCode}).',
        );
      }

      final results = (body['results'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (results.length != records.length) {
        throw const FormatException(
          'Cloud API acknowledged an incomplete batch.',
        );
      }

      final queueById = <int, Map<String, dynamic>>{
        for (final item in queue) (item['id'] as num).toInt(): item,
      };

      for (final result in results) {
        final queueId = (result['queue_id'] as num?)?.toInt();
        final original = queueId == null ? null : queueById[queueId];
        if (original == null ||
            result['sync_id'] != original['sync_id'] ||
            result['entity_type'] != original['entity_type'] ||
            (result['record_version'] as num?)?.toInt() !=
                (original['record_version'] as num?)?.toInt()) {
          throw const FormatException(
            'Cloud API acknowledgement did not match the local queue.',
          );
        }

        // cloud_id is not needed for delete acknowledgements; the local
        // database method only removes the matching tombstone in that case.
        final cloudId = (result['cloud_id'] as num?)?.toInt() ?? 0;
        await _database.acknowledgeSyncQueueItem(
          queueId: queueId!,
          entityType: original['entity_type'].toString(),
          localId: (original['local_id'] as num).toInt(),
          syncId: original['sync_id'].toString(),
          recordVersion: (original['record_version'] as num).toInt(),
          cloudId: cloudId,
        );
      }

      final remaining = await _database.getPendingSyncQueue(limit: 500);
      return CloudSyncReport(
        success: true,
        acceptedCount: results.length,
        pendingCount: remaining.length,
        message: 'Cloud accepted ${results.length} queue item(s).',
      );
    } catch (error) {
      for (final item in queue) {
        await _database.recordSyncFailure(
          queueId: (item['id'] as num).toInt(),
          message: error.toString(),
        );
      }

      final remaining = await _database.getPendingSyncQueue(limit: 500);
      return CloudSyncReport(
        success: false,
        acceptedCount: 0,
        pendingCount: remaining.length,
        message: error.toString(),
      );
    }
  }
}
