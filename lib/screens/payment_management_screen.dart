import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'add_payment_screen.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState
    extends State<PaymentManagementScreen> {
  final DatabaseHelper db = DatabaseHelper.instance;

  List<Map<String, dynamic>> customers = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> loadCustomers() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final result = await db.getCustomers();

      if (!mounted) return;

      setState(() {
        customers = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load customers.',
        isError: true,
      );
    }
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(double amount) {
    return '₹ ${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // TOTAL INVOICED
  // ============================================================

  Future<double> getTotalInvoiced(int customerId) async {
    return await db.getCustomerTotalInvoiced(customerId);
  }

  // ============================================================
  // TOTAL PAID
  // ============================================================

  Future<double> getTotalPaid(int customerId) async {
    return await db.getCustomerTotalPaid(customerId);
  }

  // ============================================================
  // OUTSTANDING
  // ============================================================

  Future<double> getOutstanding(int customerId) async {
    return await db.getCustomerOutstanding(customerId);
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(double total, double paid) {
    if (total <= 0) {
      return Colors.grey;
    }

    if (paid >= total) {
      return Colors.green;
    }

    if (paid > 0) {
      return Colors.orange;
    }

    return Colors.red;
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String statusText(double total, double paid) {
    if (total <= 0) {
      return 'NO INVOICE';
    }

    if (paid >= total) {
      return 'PAID';
    }

    if (paid > 0) {
      return 'PARTIALLY PAID';
    }

    return 'PENDING';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Management',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Customer-wise payment tracking',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: loadCustomers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE50914),
              ),
            )
          : customers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: loadCustomers,

                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,

                    itemBuilder: (context, index) {
                      return _buildCustomerCard(
                        customers[index],
                      );
                    },
                  ),
                ),
    );
  }

  // ============================================================
  // CUSTOMER CARD
  // ============================================================

  Widget _buildCustomerCard(
    Map<String, dynamic> customer,
  ) {
    final int customerId =
        (customer['id'] as num).toInt();

    final String customerName =
        (customer['name'] ?? '').toString();

    final String businessName =
        (customer['business_name'] ?? '').toString();

    final String mobile =
        (customer['mobile'] ?? '').toString();

    return FutureBuilder<List<double>>(
      future: Future.wait([
        getTotalInvoiced(customerId),
        getTotalPaid(customerId),
        getOutstanding(customerId),
      ]),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 14),

            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final totalInvoiced = snapshot.data![0];
        final totalPaid = snapshot.data![1];
        final outstanding = snapshot.data![2];

        final color =
            statusColor(totalInvoiced, totalPaid);

        final status =
            statusText(totalInvoiced, totalPaid);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 2,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ==================================================
                // CUSTOMER HEADER
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,

                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914)
                            .withValues(alpha: 0.10),

                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.person,
                        color: Color(0xFFE50914),
                      ),
                    ),

                    const SizedBox(width: 12),

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
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF111111),
                            ),
                          ),

                          if (businessName.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top: 3,
                              ),

                              child: Text(
                                businessName,
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),

                          if (mobile.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top: 3,
                              ),

                              child: Text(
                                mobile,
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // STATUS
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: 0.10,
                        ),

                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: Text(
                        status,

                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                const Divider(height: 1),

                const SizedBox(height: 15),

                // ==================================================
                // AMOUNT SUMMARY
                // ==================================================

                Row(
                  children: [
                    Expanded(
                      child: _amountBox(
                        title: 'Invoiced',
                        amount: totalInvoiced,
                        icon:
                            Icons.receipt_long,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: _amountBox(
                        title: 'Paid',
                        amount: totalPaid,
                        icon:
                            Icons.check_circle,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: _amountBox(
                        title: 'Pending',
                        amount: outstanding,
                        icon: Icons.pending,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // ==================================================
                // VIEW PAYMENT DETAILS
                // ==================================================

                SizedBox(
                  width: double.infinity,

                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showCustomerPaymentDetails(
                        customer,
                        totalInvoiced,
                        totalPaid,
                        outstanding,
                      );
                    },

                    icon: const Icon(
                      Icons.account_balance_wallet,
                      size: 18,
                    ),

                    label: const Text(
                      'View Payment Details',
                    ),

                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          const Color(0xFFE50914),

                      side: const BorderSide(
                        color: Color(0xFFE50914),
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // AMOUNT BOX
  // ============================================================

  Widget _amountBox({
    required String title,
    required double amount,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF111111),
          ),

          const SizedBox(height: 6),

          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            money(amount),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER PAYMENT DETAILS
  // ============================================================

  void _showCustomerPaymentDetails(
    Map<String, dynamic> customer,
    double totalInvoiced,
    double totalPaid,
    double outstanding,
  ) {
    final customerName =
        (customer['name'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),

      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ==================================================
                // HANDLE
                // ==================================================

                Center(
                  child: Container(
                    width: 45,
                    height: 5,

                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // CUSTOMER NAME
                // ==================================================

                Text(
                  customerName.isEmpty
                      ? 'Customer'
                      : customerName,

                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Payment Summary',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                _summaryRow(
                  'Total Invoiced',
                  totalInvoiced,
                ),

                _summaryRow(
                  'Total Paid',
                  totalPaid,
                ),

                _summaryRow(
                  'Outstanding',
                  outstanding,
                ),

                const SizedBox(height: 15),

                // ==================================================
                // ADD PAYMENT BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Close bottom sheet first.
                      Navigator.pop(context);

                      // Open Add Payment Screen.
                      final result =
                          await Navigator.push(
                        this.context,

                        MaterialPageRoute(
                          builder: (context) =>
                              AddPaymentScreen(
                            customer: customer,
                          ),
                        ),
                      );

                      // Refresh Payment Management
                      // after payment is saved.
                      if (!mounted) return;

                      if (result == true) {
                        await loadCustomers();
                      }
                    },

                    icon: const Icon(
                      Icons.add,
                    ),

                    label: const Text(
                      'Add Payment',
                    ),

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFE50914),

                      foregroundColor:
                          Colors.white,

                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String title,
    double amount,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 8),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Text(
            title,

            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),

          Text(
            money(amount),

            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.people_outline,
              size: 70,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 15),

            const Text(
              'No Customers Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Add a customer first to manage payments.',
              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }
}