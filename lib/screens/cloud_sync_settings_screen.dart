import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';

class CloudSyncSettingsScreen extends StatefulWidget {
  const CloudSyncSettingsScreen({super.key});

  @override
  State<CloudSyncSettingsScreen> createState() =>
      _CloudSyncSettingsScreenState();
}

class _CloudSyncSettingsScreenState
    extends State<CloudSyncSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  bool _checking = false;
  bool _syncing = false;
  bool _connected = false;
  bool _queueLoaded = false;

  int _pendingCount = 0;
  bool _pendingMayExceedLimit = false;

  String _statusTitle = 'Not checked';
  String _statusMessage = 'Cloud connection status has not been checked.';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('Cloud API URL is not configured')) {
      return 'Cloud API URL is not configured. '
          'Please configure PSTC_API_BASE_URL.';
    }

    if (message.contains('Please sign in')) {
      return 'Please sign in with your Firebase account.';
    }

    if (message.contains('Cloud API must use HTTPS')) {
      return 'A secure HTTPS API address is required.';
    }

    if (message.contains('Organization membership')) {
      return 'Your organization membership could not be verified.';
    }

    if (message.contains('Access denied') ||
        message.contains('Insufficient organization permissions')) {
      return 'Your account does not have permission to sync.';
    }

    return 'Cloud operation failed. Please check the server, '
        'API address and internet connection.';
  }

  Future<void> _loadPendingQueue() async {
    try {
      final queue =
          await DatabaseHelper.instance.getPendingSyncQueue(limit: 500);

      if (!mounted) return;

      setState(() {
        _queueLoaded = true;
        _pendingCount = queue.length;
        _pendingMayExceedLimit = queue.length == 500;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _queueLoaded = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    if (_checking || _syncing) return;

    setState(() {
      _checking = true;
    });

    await _loadPendingQueue();

    var connected = false;
    var statusTitle = 'Connection failed';
    var statusMessage = 'Unable to connect to the Cloud API.';

    try {
      final result = await CloudSyncService().checkStatus();

      connected = result['success'] == true;

      statusTitle = connected ? 'Connected' : 'Unavailable';

      statusMessage = connected
          ? 'Firebase authentication and Cloud API status verified.'
          : 'Cloud API is currently unavailable.';
    } catch (error) {
      statusTitle = 'Not connected';
      statusMessage = _friendlyError(error);
    }

    if (!mounted) return;

    setState(() {
      _connected = connected;
      _statusTitle = statusTitle;
      _statusMessage = statusMessage;
      _checking = false;
    });
  }

  Future<void> _syncNow() async {
    if (_checking || _syncing) return;

    setState(() {
      _syncing = true;
    });

    try {
      // Verify API connectivity and Firebase authentication first.
      await CloudSyncService().checkStatus();

      // Upload only after the user explicitly presses Sync Now.
      final report = await CloudSyncService().syncPending();

      if (!mounted) return;

      setState(() {
        _connected = true;
        _statusTitle = 'Connected';
        _statusMessage = report.message ?? 'Sync operation completed.';
        _queueLoaded = true;
        _pendingCount = report.pendingCount;
        _pendingMayExceedLimit = report.pendingCount >= 500;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            report.success
                ? 'Sync completed. Accepted: ${report.acceptedCount}, '
                    'Pending: ${report.pendingCount}'
                : 'Sync failed. ${_friendlyError(
                    StateError(report.message ?? 'Sync failed'),
                  )}',
          ),
          backgroundColor:
              report.success ? Colors.green.shade700 : Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _connected = false;
        _statusTitle = 'Sync failed';
        _statusMessage = _friendlyError(error);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );

      await _loadPendingQueue();
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Widget _informationCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (iconColor ?? primaryRed).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor ?? primaryRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: darkBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checking || _syncing;

    final statusColor = _connected
        ? Colors.green.shade700
        : Colors.orange.shade800;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Cloud Sync',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkBlack,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: busy ? null : _refreshStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE50914),
                    Color(0xFFB00000),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'PS Tax Consultancy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Cloud connection and data synchronization',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            _informationCard(
              icon: Icons.cloud_done_outlined,
              title: 'Cloud API Status',
              value: _checking ? 'Checking...' : _statusTitle,
              subtitle: _statusMessage,
              iconColor: statusColor,
            ),

            _informationCard(
              icon: Icons.pending_actions_rounded,
              title: 'Local Pending Queue',
              value: !_queueLoaded
                  ? 'Not available'
                  : (_pendingMayExceedLimit
                      ? '500+'
                      : '$_pendingCount'),
              subtitle: _queueLoaded
                  ? 'Local records waiting to be synchronized.'
                  : 'Unable to read the local sync queue.',
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFE0A3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.brown,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sync Now uploads pending local records to the '
                    'configured Cloud API. Only records accepted by '
                    'the server are marked as synchronized. '
                    'This screen does not automatically download '
                    'cloud records to the device.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: busy ? null : _syncNow,
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _syncing ? 'Syncing...' : 'Sync Now',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _refreshStatus,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh Status'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: darkBlack,
                  side: const BorderSide(color: darkBlack),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
