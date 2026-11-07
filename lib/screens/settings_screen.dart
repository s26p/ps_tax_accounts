import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_settings_screen.dart';
import 'backup_restore_screen.dart';
import 'cloud_sync_settings_screen.dart';
import 'bank_details_screen.dart';
import 'business_profile_screen.dart';
import 'data_management_screen.dart';
import 'invoice_settings_screen.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';
import 'payment_settings_screen.dart';
import 'pdf_invoice_design_settings_screen.dart';
import 'security_settings_screen.dart';
import 'service_settings_screen.dart';
import 'terms_conditions_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  String businessName = 'PS Tax Consultancy';
  String ownerName = '';
  String mobile = '';
  String email = '';
  String address = '';
  String gstin = '';
  String pan = '';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessDetails();
  }

  Future<void> _loadBusinessDetails() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        businessName =
            preferences.getString('business_name') ?? 'PS Tax Consultancy';
        ownerName = preferences.getString('owner_name') ?? '';
        mobile =
            preferences.getString('business_mobile') ??
            preferences.getString('mobile') ??
            '';
        email =
            preferences.getString('business_email') ??
            preferences.getString('email') ??
            '';
        address =
            preferences.getString('business_address') ??
            preferences.getString('address') ??
            '';
        gstin =
            preferences.getString('business_gstin') ??
            preferences.getString('gstin') ??
            '';
        pan =
            preferences.getString('business_pan') ??
            preferences.getString('pan') ??
            '';
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _openAccountSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );

    if (!mounted) return;
    await _loadBusinessDetails();
  }

  Future<void> _openBusinessProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
    );

    if (!mounted) return;
    await _loadBusinessDetails();
  }

  Future<void> _openBankDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BankDetailsScreen()),
    );
  }

  Future<void> _openServices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServiceSettingsScreen()),
    );
  }

  Future<void> _openInvoiceSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InvoiceSettingsScreen()),
    );
  }

  Future<void> _openSecuritySettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
    );
  }

  Future<void> _openPaymentSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentSettingsScreen()),
    );
  }

  Future<void> _openPdfInvoiceDesignSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PdfInvoiceDesignSettingsScreen()),
    );
  }

  Future<void> _openTermsConditionsSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsSettingsScreen()),
    );
  }

  Future<void> _openBackupRestore() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
    );
  }

  Future<void> _openDataManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DataManagementScreen()),
    );
  }

  Future<void> _openCloudSyncSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CloudSyncSettingsScreen()),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firebase à®•à®£à®•à¯à®•à®¿à®²à®¿à®°à¯à®¨à¯à®¤à¯ Sign out.
      await FirebaseAuth.instance.signOut();

      // à®‰à®³à¯à®³à¯‚à®°à¯ Login à®¨à®¿à®²à¯ˆà®¯à¯ˆà®ªà¯ à®ªà¯à®¤à¯à®ªà¯à®ªà®¿à®•à¯à®•à®µà¯à®®à¯.
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('is_logged_in', false);

      if (!mounted) return;

      // à®ªà®´à¯ˆà®¯ à®¤à®¿à®°à¯ˆà®•à®³à¯ˆ à®¨à¯€à®•à¯à®•à®¿ Login à®¤à®¿à®°à¯ˆà®•à¯à®•à¯à®šà¯ à®šà¯†à®²à¯à®²à®µà¯à®®à¯.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout à®šà¯†à®¯à¯à®¯ à®®à¯à®Ÿà®¿à®¯à®µà®¿à®²à¯à®²à¯ˆ: $error',
          ),
          backgroundColor: primaryRed,
        ),
      );
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'PS Tax Consultancy',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primaryRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
      ),
      children: const [
        Text('GST Ã¢â‚¬Â¢ TAX Ã¢â‚¬Â¢ ACCOUNTS'),
        SizedBox(height: 8),
        Text(
          'PS Tax Consultancy helps manage customers, invoices, '
          'payments and tax-related business activities.',
        ),
      ],
    );
  }

  Widget _businessHeader() {
    final displayName = businessName.trim().isEmpty
        ? 'PS Tax Consultancy'
        : businessName.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE50914), Color(0xFFB00000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your application preferences',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 7,
          ),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryRed.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryRed, size: 23),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: darkBlack,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.black38,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkBlack,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadBusinessDetails,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryRed,
          onRefresh: _loadBusinessDetails,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            children: [
              _businessHeader(),

              _sectionTitle('ACCOUNT'),

              _settingsTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Account Settings',
                subtitle: 'Username, mobile and password',
                onTap: _openAccountSettings,
              ),

              _settingsTile(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Password and app security',
                onTap: _openSecuritySettings,
              ),

              _sectionTitle('BUSINESS SETTINGS'),

              _settingsTile(
                icon: Icons.business_outlined,
                title: 'Business Profile',
                subtitle: 'PS Tax Consultancy details',
                onTap: _openBusinessProfile,
              ),

              _settingsTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank Details',
                subtitle: 'Bank account and payment details',
                onTap: _openBankDetails,
              ),

              _settingsTile(
                icon: Icons.miscellaneous_services_outlined,
                title: 'Services',
                subtitle: 'Manage your consultancy services',
                onTap: _openServices,
              ),

              _settingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'Invoice Settings',
                subtitle: 'Invoice number, GST and defaults',
                onTap: _openInvoiceSettings,
              ),

              _settingsTile(
                icon: Icons.payments_outlined,
                title: 'Payment Settings',
                subtitle: 'Payment methods and collection preferences',
                onTap: _openPaymentSettings,
              ),

              _sectionTitle('INVOICE & DOCUMENTS'),

              _settingsTile(
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF / Invoice Design',
                subtitle: 'Invoice PDF and print design settings',
                onTap: _openPdfInvoiceDesignSettings,
              ),

              _settingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Manage invoice terms and conditions',
                onTap: _openTermsConditionsSettings,
              ),

              _sectionTitle('DATA & SYSTEM'),

              _settingsTile(
                icon: Icons.cloud_sync_outlined,
                title: 'Cloud Sync',
                subtitle: 'Cloud connection and pending local changes',
                onTap: _openCloudSyncSettings,
              ),

              _settingsTile(
                icon: Icons.backup_outlined,
                title: 'Backup & Restore',
                subtitle: 'Backup and restore application data',
                onTap: _openBackupRestore,
              ),

              _settingsTile(
                icon: Icons.storage_outlined,
                title: 'Data Management',
                subtitle: 'Manage customers, invoices and payments',
                onTap: _openDataManagement,
              ),

              _settingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Notification preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),

              _sectionTitle('APP'),

              _settingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'PS Tax Consultancy app information',
                onTap: _showAbout,
              ),

              _settingsTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out from this device',
                onTap: _logout,
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'PS Tax Consultancy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black45,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              const Center(
                child: Text(
                  'GST • TAX • ACCOUNTS',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
