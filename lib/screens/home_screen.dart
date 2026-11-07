import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'customer_list_screen.dart';
import 'invoice_list_screen.dart';
import 'add_customer_screen.dart';
import 'settings_screen.dart';
import 'payment_management_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  // ============================================================
  // DASHBOARD DATA
  // ============================================================

  int customerCount = 0;
  int invoiceCount = 0;

  double totalBilling = 0.0;
  double totalPaid = 0.0;
  double totalOutstanding = 0.0;

  bool isDashboardLoading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ============================================================
  // LOAD DASHBOARD DATA
  // ============================================================

  Future<void> _loadDashboardData() async {
    try {
      final database = DatabaseHelper.instance;

      final customers = await database.getCustomerCount();
      final invoices = await database.getInvoiceCount();
      final billing = await database.getTotalInvoiceAmount();
      final paid = await database.getTotalPaidAmount();
      final outstanding = await database.getTotalOutstandingAmount();

      if (!mounted) return;

      setState(() {
        customerCount = customers;
        invoiceCount = invoices;
        totalBilling = billing;
        totalPaid = paid;
        totalOutstanding = outstanding;
        isDashboardLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isDashboardLoading = false;
      });
    }
  }

  // ============================================================
  // CUSTOMER LIST
  // ============================================================

  Future<void> _openCustomerList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerListScreen(),
      ),
    );

    if (!mounted) return;

    await _loadDashboardData();
  }

  // ============================================================
  // INVOICE LIST
  // ============================================================

  Future<void> _openInvoiceList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InvoiceListScreen(),
      ),
    );

    if (!mounted) return;

    await _loadDashboardData();
  }

  // ============================================================
  // ADD CUSTOMER
  // ============================================================

  Future<void> _addCustomer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCustomerScreen(),
      ),
    );

    if (!mounted) return;

    await _loadDashboardData();
  }

  // ============================================================
  // PAYMENT MANAGEMENT
  // ============================================================

  Future<void> _openPaymentManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentManagementScreen(),
      ),
    );

    if (!mounted) return;

    await _loadDashboardData();
  }

  // ============================================================
  // ============================================================
  // REPORTS
  // ============================================================

  Future<void> _openReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportsScreen(),
      ),
    );

    if (!mounted) return;

    await _loadDashboardData();
  }
  // SETTINGS
  // ============================================================

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );

    if (!mounted) return;

    await _loadDashboardData();
  }

  // ============================================================
  // MONEY FORMAT
  // ============================================================

  String _money(double value) {
    return '\u20B9${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 76,

        titleSpacing: 12,

        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(5),
              child: Image.asset(
                'assets/images/ps_tax_consultancy_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.business,
                    color: primaryRed,
                    size: 30,
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PS Tax Consultancy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'GST \u2022 TAX \u2022 ACCOUNTS',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No new notifications',
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 27,
            ),
          ),

          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings_outlined,
              size: 25,
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: RefreshIndicator(
        onRefresh: _loadDashboardData,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            30,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // WELCOME BANNER
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: darkBlack,
                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Welcome to',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 5),

                          const Text(
                            'PS Tax Consultancy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Manage your customers, invoices and payments easily.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 58,
                      height: 58,

                      decoration: BoxDecoration(
                        color: primaryRed,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // SECTION TITLE
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 5,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: darkBlack,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh dashboard',
                    onPressed: _loadDashboardData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: primaryRed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==================================================
              // CUSTOMER + INVOICE CARDS
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: _dashboardCard(
                      title: 'Customers',
                      value: isDashboardLoading
                          ? '...'
                          : customerCount.toString(),
                      icon: Icons.people_alt_rounded,
                      onTap: _openCustomerList,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: _dashboardCard(
                      title: 'Invoices',
                      value: isDashboardLoading
                          ? '...'
                          : invoiceCount.toString(),
                      icon: Icons.receipt_long_rounded,
                      onTap: _openInvoiceList,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==================================================
              // TOTAL BILLING
              // ==================================================

              _billingCard(),

              const SizedBox(height: 14),

              // ==================================================
              // PAYMENT SUMMARY
              // ==================================================

              _paymentSummaryCard(),

              const SizedBox(height: 24),

              // ==================================================
              // QUICK ACTIONS
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 5,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: darkBlack,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      title: 'Add Customer',
                      subtitle: 'Create new customer',
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: _addCustomer,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: _actionCard(
                      title: 'Create Invoice',
                      subtitle: 'Generate new invoice',
                      icon: Icons.add_card_rounded,
                      onTap: _openInvoiceList,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==================================================
              // PAYMENT MANAGEMENT ACTION
              // ==================================================

              _paymentManagementAction(),

              const SizedBox(height: 14),

              _actionCard(
                title: 'Reports',
                subtitle: 'Billing, collection & outstanding',
                icon: Icons.analytics_rounded,
                onTap: _openReports,
              ),

              const SizedBox(height: 28),

              // ==================================================
              // OUR SERVICES
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 5,
                    height: 25,
                    decoration: BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Our Services',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: darkBlack,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _serviceCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'GST',
                      subtitle: 'Registration & Returns',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _serviceCard(
                      icon: Icons.account_balance_rounded,
                      title: 'Income Tax',
                      subtitle: 'ITR & Tax Services',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _serviceCard(
                      icon: Icons.calculate_rounded,
                      title: 'Accounts',
                      subtitle: 'Accounting & Tally',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _serviceCard(
                      icon: Icons.business_center_rounded,
                      title: 'Business',
                      subtitle: 'Registration Services',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ==================================================
              // BRAND CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,

                      padding: const EdgeInsets.all(7),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),

                      child: Image.asset(
                        'assets/images/ps_tax_consultancy_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) {
                          return const Icon(
                            Icons.business,
                            color: primaryRed,
                            size: 38,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'PS Tax Consultancy',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: darkBlack,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Professional Tax \u2022 GST \u2022 Accounts Services',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // FOOTER
              // ==================================================

              Center(
                child: Text(
                  'PS Tax Consultancy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: Text(
                  'Professional Tax & Accounting Solutions',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD CARD
  // ============================================================

  Widget _dashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryRed.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: darkBlack.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primaryRed.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: primaryRed,
                      size: 24,
                    ),
                  ),
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: darkBlack,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BILLING CARD
  // ============================================================

  Widget _billingCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: primaryRed,
        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.currency_rupee_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Total Billing',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  isDashboardLoading
                      ? 'Loading...'
                      : _money(totalBilling),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.trending_up_rounded,
            color: Colors.white,
            size: 30,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT SUMMARY CARD
  // ============================================================

  Widget _paymentSummaryCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Payment Summary',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: darkBlack,
                  ),
                ),
              ),

              InkWell(
                onTap: _openPaymentManagement,
                borderRadius: BorderRadius.circular(20),

                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Paid',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        isDashboardLoading
                            ? '...'
                            : _money(totalPaid),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: primaryRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Outstanding',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        isDashboardLoading
                            ? '...'
                            : _money(totalOutstanding),
                        style: const TextStyle(
                          color: primaryRed,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTION CARD
  // ============================================================

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primaryRed.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: darkBlack.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primaryRed.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: primaryRed,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: Colors.grey.shade500,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: darkBlack,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT MANAGEMENT ACTION
  // ============================================================

  Widget _paymentManagementAction() {
    return InkWell(
      onTap: _openPaymentManagement,

      borderRadius: BorderRadius.circular(18),

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: darkBlack,
          borderRadius: BorderRadius.circular(18),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,

              decoration: BoxDecoration(
                color: primaryRed,
                borderRadius: BorderRadius.circular(13),
              ),

              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),

            const SizedBox(width: 14),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    'Payment Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    'Track customer-wise payments',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _serviceCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: primaryRed.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: darkBlack.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryRed.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: primaryRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: darkBlack,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}











