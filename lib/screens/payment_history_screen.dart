import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const PaymentHistoryScreen({
    super.key,
    required this.customer,
  });

  @override
  State<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState
    extends State<PaymentHistoryScreen> {
  final DatabaseHelper db = DatabaseHelper.instance;

  bool isLoading = true;

  List<Map<String, dynamic>> payments = [];

  double totalInvoiced = 0;
  double totalPaid = 0;
  double outstanding = 0;

  int get customerId {
    return (widget.customer['id'] as num).toInt();
  }

  String get customerName {
    return (widget.customer['name'] ?? '').toString();
  }

  String get businessName {
    return (widget.customer['business_name'] ?? '').toString();
  }

  String get mobile {
    return (widget.customer['mobile'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    loadPaymentHistory();
  }

  Future<void> loadPaymentHistory() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        db.getCustomerPayments(customerId),
        db.getCustomerTotalInvoiced(customerId),
        db.getCustomerTotalPaid(customerId),
        db.getCustomerOutstanding(customerId),
      ]);

      if (!mounted) return;

      setState(() {
        payments =
            List<Map<String, dynamic>>.from(
          results[0] as List,
        );

        totalInvoiced =
            (results[1] as num).toDouble();

        totalPaid =
            (results[2] as num).toDouble();

        outstanding =
            (results[3] as num).toDouble();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment history load failed: $e',
          ),
        ),
      );
    }
  }

  String money(double amount) {
    return '₹ ${amount.toStringAsFixed(2)}';
  }

  String formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    try {
      final date = DateTime.parse(text);

      final day =
          date.day.toString().padLeft(2, '0');

      final month =
          date.month.toString().padLeft(2, '0');

      final year =
          date.year.toString();

      return '$day-$month-$year';
    } catch (_) {
      return text;
    }
  }

  IconData paymentModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'UPI':
        return Icons.phone_android;

      case 'CASH':
        return Icons.payments;

      case 'BANK TRANSFER':
        return Icons.account_balance;

      case 'CHEQUE':
        return Icons.receipt_long;

      default:
        return Icons.currency_rupee;
    }
  }

  Color paymentModeColor(String mode) {
    switch (mode.toUpperCase()) {
      case 'UPI':
        return Colors.deepPurple;

      case 'CASH':
        return Colors.green;

      case 'BANK TRANSFER':
        return Colors.blue;

      case 'CHEQUE':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  Future<void> deletePayment(
    Map<String, dynamic> payment,
  ) async {
    final paymentId =
        (payment['id'] as num).toInt();

    final amount =
        (payment['amount'] as num).toDouble();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Payment?',
          ),
          content: Text(
            'இந்த payment entry-ஐ delete செய்ய வேண்டுமா?\n\n'
            '${money(amount)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFE50914),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await db.deletePayment(paymentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment deleted successfully.',
          ),
        ),
      );

      await loadPaymentHistory();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Payment History',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Customer-wise payment records',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: loadPaymentHistory,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadPaymentHistory,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(16),
                children: [
                  _buildCustomerHeader(),

                  const SizedBox(height: 14),

                  _buildSummary(),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Icon(
                        Icons.history,
                        size: 21,
                        color: Color(0xFF111111),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Payment Records',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${payments.length} entries',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (payments.isEmpty)
                    _buildNoPayments()
                  else
                    ...payments.map(
                      _buildPaymentCard,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomerHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFE50914),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.isEmpty
                        ? 'Customer'
                        : customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  if (businessName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],

                  if (mobile.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      mobile,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _summaryBox(
                    title: 'Invoiced',
                    amount: totalInvoiced,
                    icon:
                        Icons.receipt_long,
                    iconColor:
                        Colors.blue,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _summaryBox(
                    title: 'Paid',
                    amount: totalPaid,
                    icon:
                        Icons.check_circle,
                    iconColor:
                        Colors.green,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _summaryBox(
                    title: 'Balance',
                    amount: outstanding,
                    icon:
                        Icons.pending,
                    iconColor:
                        outstanding > 0
                            ? Colors.red
                            : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox({
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF6F7F9),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor,
          ),

          const SizedBox(height: 7),

          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 4),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment:
                Alignment.centerLeft,
            child: Text(
              money(amount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    Map<String, dynamic> payment,
  ) {
    final amount =
        (payment['amount'] as num?)
                ?.toDouble() ??
            0;

    final mode =
        (payment['payment_mode'] ??
                'Other')
            .toString();

    final date =
        payment['payment_date'];

    final notes =
        (payment['notes'] ?? '')
            .toString()
            .trim();

    final modeColor =
        paymentModeColor(mode);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        modeColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    paymentModeIcon(mode),
                    color: modeColor,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(amount),
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        formatDate(date),
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        modeColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    mode,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                      color: modeColor,
                    ),
                  ),
                ),

                const SizedBox(width: 2),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      deletePayment(
                        payment,
                      );
                    }
                  },
                  itemBuilder:
                      (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF6F7F9),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes,
                      size: 17,
                      color: Colors.grey,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        notes,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoPayments() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(35),
        child: Column(
          children: [
            Icon(
              Icons
                  .account_balance_wallet_outlined,
              size: 60,
              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(height: 14),

            const Text(
              'No Payment Records',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'இந்த customer-க்கு இதுவரை payment பதிவு செய்யப்படவில்லை.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}