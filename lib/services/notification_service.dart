import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _timezoneInitialized = false;

  static const int _testNotificationId = 1001;
  static const int _invoiceReminderId = 2001;
  static const int _paymentReminderId = 2002;

  Future<void> _initialize() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Notifications are currently supported on Android only.',
      );
    }

    if (_isInitialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );

    await _plugin.initialize(settings: settings);
    _isInitialized = true;
  }

  Future<void> _initializeTimezone() async {
    if (_timezoneInitialized) return;

    tz_data.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(
      tz.getLocation(timezoneInfo.identifier),
    );

    _timezoneInitialized = true;
  }

  Future<bool> _requestNotificationPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? permissionGranted =
        await androidPlugin?.requestNotificationsPermission();

    return permissionGranted ?? true;
  }

  Future<bool> showTestNotification() async {
    await _initialize();

    final permissionGranted = await _requestNotificationPermission();

    if (!permissionGranted) return false;

    const androidDetails = AndroidNotificationDetails(
      'pstc_test_notifications',
      'PS Tax Consultancy Notifications',
      channelDescription: 'App notification testing and reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: _testNotificationId,
      title: 'PS Tax Consultancy',
      body: 'Test Notification - உங்கள் மொபைல் அறிவிப்பு சரியாக வேலை செய்கிறது.',
      notificationDetails: details,
    );

    return true;
  }

  Future<String> _getInvoiceReminderMessage() async {
    try {
      final invoices = await DatabaseHelper.instance.getInvoices();

      var pendingCount = 0;

      for (final invoice in invoices) {
        final status = (invoice['payment_status'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        if (status == 'PENDING' || status == 'PARTIAL') {
          pendingCount++;
        }
      }

      if (pendingCount == 0) {
        return 'தற்போது நிலுவையில் உள்ள Invoice இல்லை.';
      }

      return 'நிலுவையில் உள்ள Invoice எண்ணிக்கை: $pendingCount. '
          'PS Tax Consultancy App-ல் சரிபார்க்கவும்.';
    } catch (e) {
      return 'நிலுவையில் உள்ள Invoice-களைச் சரிபார்க்கவும்.';
    }
  }

  Future<String> _getPaymentReminderMessage() async {
    try {
      final outstandingAmount =
          await DatabaseHelper.instance.getTotalOutstandingAmount();

      final amount = outstandingAmount < 0 ? 0.0 : outstandingAmount;

      if (amount == 0) {
        return 'தற்போது கணக்கிடப்பட்ட நிலுவைத் தொகை இல்லை.';
      }

      final formattedAmount = amount.toStringAsFixed(2);

      return 'மொத்த நிலுவைத் தொகை: ₹$formattedAmount. '
          'Payment விவரங்களைச் சரிபார்க்கவும்.';
    } catch (e) {
      return 'பெற வேண்டிய Payment-களைச் சரிபார்க்கவும்.';
    }
  }

  Future<bool> scheduleDailyReminders({
    required bool invoiceEnabled,
    required bool paymentEnabled,
    bool requestPermission = true,
  }) async {
    await _initialize();

    if (!invoiceEnabled) {
      await _plugin.cancel(id: _invoiceReminderId);
    }

    if (!paymentEnabled) {
      await _plugin.cancel(id: _paymentReminderId);
    }

    if (!invoiceEnabled && !paymentEnabled) {
      return true;
    }

    if (requestPermission) {
      final permissionGranted =
          await _requestNotificationPermission();

      if (!permissionGranted) return false;
    }

    await _initializeTimezone();

    final now = tz.TZDateTime.now(tz.local);

    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      10,
      0,
    );

    if (!scheduledTime.isAfter(now)) {
      scheduledTime = scheduledTime.add(
        const Duration(days: 1),
      );
    }

    if (invoiceEnabled) {
      final invoiceMessage = await _getInvoiceReminderMessage();

      const invoiceDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'pstc_invoice_reminders',
          'Invoice Reminders',
          channelDescription: 'Daily reminders to review invoices',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );

      await _plugin.zonedSchedule(
        id: _invoiceReminderId,
        title: 'PS Tax Consultancy - Invoice Reminder',
        body: invoiceMessage,
        scheduledDate: scheduledTime,
        notificationDetails: invoiceDetails,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      await _plugin.cancel(id: _invoiceReminderId);
    }

    if (paymentEnabled) {
      final paymentMessage = await _getPaymentReminderMessage();

      const paymentDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'pstc_payment_reminders',
          'Payment Reminders',
          channelDescription: 'Daily reminders to review pending payments',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );

      await _plugin.zonedSchedule(
        id: _paymentReminderId,
        title: 'PS Tax Consultancy - Payment Reminder',
        body: paymentMessage,
        scheduledDate: scheduledTime,
        notificationDetails: paymentDetails,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      await _plugin.cancel(id: _paymentReminderId);
    }

    return true;
  }
}