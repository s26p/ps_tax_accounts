
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState
    extends State<DataManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  int _customerCount = 0;
  int _invoiceCount = 0;
  int _paymentCount = 0;

  double _totalBilling = 0;
  double _totalPaid = 0;
  double _outstanding = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final db = DatabaseHelper.instance;

      final customers = await db.getCustomerCount();
      final invoices = await db.getInvoiceCount();
      final payments = await db.getAllPayments();
      final billing = await db.getTotalInvoiceAmount();
      final paid = await db.getTotalPaidAmount();
      final outstanding =
          await db.getTotalOutstandingAmount();

      if (!mounted) return;

      setState(() {
        _customerCount = customers;
        _invoiceCount = invoices;
        _paymentCount = payments.length;
        _totalBilling = billing;
        _totalPaid = paid;
        _outstanding = outstanding;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatAmount(double amount) {
    return '\u20B9 ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE50914);
    const darkBlack = Color(0xFF111111);
    const background = Color(0xFFF6F7F9);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Data Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: darkBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryRed,
              ),
            )
          : _errorMessage != null
              ? _buildError(primaryRed)
              : RefreshIndicator(
                  color: primaryRed,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Database Summary',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: darkBlack,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your customers, invoices and payment records.',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Record Counts'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCountCard(
                              title: 'Customers',
                              count: _customerCount,
                              icon: Icons.people_alt_outlined,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCountCard(
                              title: 'Invoices',
                              count: _invoiceCount,
                              icon: Icons.receipt_long_outlined,
                              color: primaryRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildCountCard(
                        title: 'Payment Records',
                        count: _paymentCount,
                        icon: Icons.payments_outlined,
                        color: Colors.green,
                      ),

                      const SizedBox(height: 24),
                      _buildSectionTitle('Billing Summary'),
                      const SizedBox(height: 10),

                      _buildAmountCard(
                        title: 'Total Billing',
                        amount: _formatAmount(_totalBilling),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.blue,
                      ),
                      _buildAmountCard(
                        title: 'Total Paid',
                        amount: _formatAmount(_totalPaid),
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      _buildAmountCard(
                        title: 'Outstanding Amount',
                        amount: _formatAmount(_outstanding),
                        icon: Icons.pending_actions_outlined,
                        color: Colors.orange,
                      ),

                      const SizedBox(height: 20),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: primaryRed,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This screen displays a summary of '
                                  'your saved data. It does not delete '
                                  'or modify customer, invoice or payment '
                                  'records.',
                                  style: TextStyle(
                                    height: 1.5,
                                    color: darkBlack,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(Color primaryRed) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: primaryRed,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF111111),
      ),
    );
  }

  Widget _buildCountCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text('Based on saved records'),
        trailing: Text(
          amount,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}
