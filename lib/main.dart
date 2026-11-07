
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Keep the existing daily invoice and payment reminders.
  try {
    final preferences = await SharedPreferences.getInstance();

    final invoiceEnabled =
        preferences.getBool('notification_invoice_reminders') ?? true;

    final paymentEnabled =
        preferences.getBool('notification_payment_reminders') ?? true;

    await NotificationService.instance.scheduleDailyReminders(
      invoiceEnabled: invoiceEnabled,
      paymentEnabled: paymentEnabled,
      requestPermission: false,
    );
  } catch (error) {
    debugPrint('Reminder startup sync failed: $error');
  }

  runApp(const PSTaxAccountsApp());
}

class PSTaxAccountsApp extends StatelessWidget {
  const PSTaxAccountsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS Tax Consultancy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF6F7F9),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE50914),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Unable to check login status. Please restart the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const AppLockGate(
              child: HomeScreen(),
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
