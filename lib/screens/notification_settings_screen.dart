
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color background = Color(0xFFF6F7F9);

  bool _invoiceReminders = true;
  bool _paymentReminders = true;
  bool _businessUpdates = true;
  bool _generalUpdates = false;

  bool _isLoading = true;
  bool _isTestingNotification = false;
  bool _isUpdatingReminder = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _invoiceReminders =
            prefs.getBool('notification_invoice_reminders') ?? true;
        _paymentReminders =
            prefs.getBool('notification_payment_reminders') ?? true;
        _businessUpdates =
            prefs.getBool('notification_business_updates') ?? true;
        _generalUpdates =
            prefs.getBool('notification_general_updates') ?? false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('அமைப்புகளை ஏற்ற முடியவில்லை.');
    }
  }

  Future<void> _changePreference({
    required String key,
    required bool value,
    required void Function(bool) update,
  }) async {
    if (_isUpdatingReminder) return;

    final previousValue = switch (key) {
      'notification_invoice_reminders' => _invoiceReminders,
      'notification_payment_reminders' => _paymentReminders,
      'notification_business_updates' => _businessUpdates,
      _ => _generalUpdates,
    };

    final isReminder =
        key == 'notification_invoice_reminders' ||
        key == 'notification_payment_reminders';

    if (isReminder) {
      setState(() => _isUpdatingReminder = true);
    } else {
      setState(() => update(value));
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(key, value);

      if (isReminder) {
        if (mounted) {
          setState(() => update(value));
        }

        final success =
            await NotificationService.instance.scheduleDailyReminders(
          invoiceEnabled: _invoiceReminders,
          paymentEnabled: _paymentReminders,
        );

        if (!mounted) return;

        if (!success) {
          _showMessage(
            'Notification அனுமதி கிடைக்கவில்லை. '
            'மொபைல் Settings-ல் Notifications அனுமதிக்கவும்; '
            'பிறகு Reminder-ஐ மீண்டும் ON செய்யவும்.',
          );
        } else if (value) {
          _showMessage(
            'தினசரி காலை 10:00 மணி Reminder அமைக்கப்பட்டது.',
          );
        } else {
          _showMessage('Reminder OFF செய்யப்பட்டது.');
        }
      } else {
        if (!mounted) return;
        _showMessage('அமைப்பு சேமிக்கப்பட்டது.');
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, previousValue);

      if (!mounted) return;

      setState(() {
        update(previousValue);
      });

      _showMessage('அமைப்பை மாற்ற முடியவில்லை: $e');
    } finally {
      if (mounted && isReminder) {
        setState(() => _isUpdatingReminder = false);
      }
    }
  }

  Future<void> _sendTestNotification() async {
    if (_isTestingNotification) return;

    setState(() => _isTestingNotification = true);

    try {
      final success =
          await NotificationService.instance.showTestNotification();

      if (!mounted) return;

      if (success) {
        _showMessage(
          'Test Notification அனுப்பப்பட்டது. மொபைலைச் சரிபார்க்கவும்.',
        );
      } else {
        _showMessage(
          'Notification அனுமதி கிடைக்கவில்லை. '
          'மொபைல் Settings-ல் அனுமதிக்கவும்.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Notification அனுப்ப முடியவில்லை: $e');
    } finally {
      if (mounted) {
        setState(() => _isTestingNotification = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primaryRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primaryRed),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ),
      value: value,
      activeThumbColor: primaryRed,
      onChanged: _isUpdatingReminder ? null : onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: primaryRed,
                        size: 34,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Preferences',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'உங்கள் தேவைக்கேற்ப அறிவிப்பு விருப்பங்களைத் தேர்வு செய்யுங்கள்.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'REMINDERS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildNotificationTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Invoice Reminders',
                        subtitle:
                            'தினமும் காலை 10:00 மணிக்கு Invoice நினைவூட்டல்',
                        value: _invoiceReminders,
                        onChanged: (value) => _changePreference(
                          key: 'notification_invoice_reminders',
                          value: value,
                          update: (v) => _invoiceReminders = v,
                        ),
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildNotificationTile(
                        icon: Icons.payments_outlined,
                        title: 'Payment Reminders',
                        subtitle:
                            'தினமும் காலை 10:00 மணிக்கு Payment நினைவூட்டல்',
                        value: _paymentReminders,
                        onChanged: (value) => _changePreference(
                          key: 'notification_payment_reminders',
                          value: value,
                          update: (v) => _paymentReminders = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'UPDATES',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildNotificationTile(
                        icon: Icons.business_outlined,
                        title: 'Business Updates',
                        subtitle:
                            'GST மற்றும் வணிகச் சேவை தொடர்பான தகவல்கள்',
                        value: _businessUpdates,
                        onChanged: (value) => _changePreference(
                          key: 'notification_business_updates',
                          value: value,
                          update: (v) => _businessUpdates = v,
                        ),
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildNotificationTile(
                        icon: Icons.campaign_outlined,
                        title: 'General Updates',
                        subtitle:
                            'App புதுப்பிப்புகள் மற்றும் பொதுத் தகவல்கள்',
                        value: _generalUpdates,
                        onChanged: (value) => _changePreference(
                          key: 'notification_general_updates',
                          value: value,
                          update: (v) => _generalUpdates = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              color: primaryRed,
                              size: 26,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Test Notification',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'உங்கள் மொபைலில் Android Notification சரியாக '
                          'வருகிறதா என்பதைச் சோதிக்கவும்.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isTestingNotification
                                ? null
                                : _sendTestNotification,
                            icon: _isTestingNotification
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(
                              _isTestingNotification
                                  ? 'அனுப்பப்படுகிறது...'
                                  : 'Send Test Notification',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  color: Colors.white,
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blueGrey,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'குறிப்பு: Reminder ON செய்தால் தினசரி '
                            'நினைவூட்டல் அமைக்கப்படும். Android அனுமதி '
                            'மற்றும் battery settings காரணமாக நேரத்தில் '
                            'சிறிய தாமதம் ஏற்படலாம். இவை பொதுவான '
                            'நினைவூட்டல்கள்; நிலுவைத் தொகையை நேரடியாக '
                            'கணக்கிடுவதில்லை.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
