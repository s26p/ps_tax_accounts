import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'add_payment_screen.dart';
import 'payment_history_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState
    extends State<CustomerDetailsScreen> {
  bool isLoading = true;

  double totalInvoiced = 0.0;
  double totalPaid = 0.0;
  double outstanding = 0.0;

  @override
  void initState() {
    super.initState();
    loadPaymentSummary();
  }

  // ============================================================
  // LOAD PAYMENT SUMMARY
  // ============================================================

  Future<void> loadPaymentSummary() async {
    try {
      final customerId =
          int.tryParse(
                widget.customer['id'].toString(),
              ) ??
              0;

      if (customerId > 0) {
        totalInvoiced =
            await DatabaseHelper.instance
                .getCustomerTotalInvoiced(
          customerId,
        );

        totalPaid =
            await DatabaseHelper.instance
                .getCustomerTotalPaid(
          customerId,
        );

        outstanding =
            await DatabaseHelper.instance
                .getCustomerOutstanding(
          customerId,
        );
      }
    } catch (_) {
      totalInvoiced = 0.0;
      totalPaid = 0.0;
      outstanding = 0.0;
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // ============================================================
  // OPEN ADD PAYMENT
  // ============================================================

  Future<void> openAddPayment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddPaymentScreen(
          customer: widget.customer,
        ),
      ),
    );

    if (!mounted) return;

    await loadPaymentSummary();
  }

  // ============================================================
  // OPEN PAYMENT HISTORY
  // ============================================================

  Future<void> openPaymentHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentHistoryScreen(
          customer: widget.customer,
        ),
      ),
    );

    if (!mounted) return;

    await loadPaymentSummary();
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // PAYMENT STATUS
  // ============================================================

  String get paymentStatus {
    if (totalInvoiced <= 0) {
      return 'No Invoice';
    }

    if (outstanding <= 0) {
      return 'Paid';
    }

    if (totalPaid > 0) {
      return 'Partial';
    }

    return 'Pending';
  }

  Color get statusColor {
    switch (paymentStatus) {
      case 'Paid':
        return Colors.green;

      case 'Partial':
        return Colors.orange;

      case 'Pending':
        return const Color(0xFFE50914);

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

  Widget infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFE50914),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        Colors.grey.shade600,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconBackground,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius:
                    BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color:
                    Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT ACTION BUTTON
  // ============================================================

  Widget paymentActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: primary
                ? const Color(0xFFE50914)
                : const Color(0xFFF6F7F9),
            borderRadius:
                BorderRadius.circular(15),
            border: primary
                ? null
                : Border.all(
                    color:
                        Colors.grey.shade300,
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white
                      : const Color(0xFFFFEBEE),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primary
                      ? const Color(0xFFE50914)
                      : const Color(0xFFE50914),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.bold,
                        color: primary
                            ? Colors.white
                            : const Color(
                                0xFF111111,
                              ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: primary
                            ? Colors.white70
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final name =
        (widget.customer['name'] ?? '')
            .toString()
            .trim();

    final business =
        (widget.customer['business_name'] ?? '')
            .toString()
            .trim();

    final mobile =
        (widget.customer['mobile'] ?? '')
            .toString()
            .trim();

    final email =
        (widget.customer['email'] ?? '')
            .toString()
            .trim();

    final address =
        (widget.customer['address'] ?? '')
            .toString()
            .trim();

    final gstin =
        (widget.customer['gstin'] ?? '')
            .toString()
            .trim();

    final pan =
        (widget.customer['pan'] ?? '')
            .toString()
            .trim();

    final displayName =
        name.isEmpty
            ? 'Unnamed Customer'
            : name;

    final firstLetter =
        displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'C';

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF111111),
        foregroundColor:
            Colors.white,
        elevation: 0,

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              'PS Tax Consultancy',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                loadPaymentSummary,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: RefreshIndicator(
        color:
            const Color(0xFFE50914),
        onRefresh:
            loadPaymentSummary,

        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            30,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // ==================================================
              // CUSTOMER HEADER
              // ==================================================

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF111111),
                      Color(0xFF292929),
                    ],
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                ),

                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration:
                          BoxDecoration(
                        gradient:
                            const LinearGradient(
                          colors: [
                            Color(0xFFE50914),
                            Color(0xFFB00000),
                          ],
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          firstLetter,
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          if (business.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              business,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // CUSTOMER INFORMATION
              // ==================================================

              const Text(
                'Customer Information',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF111111),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        Colors.grey.shade200,
                  ),
                ),

                child: Column(
                  children: [
                    infoRow(
                      Icons.person_outline_rounded,
                      'Customer Name',
                      displayName,
                    ),

                    infoRow(
                      Icons.business_outlined,
                      'Business Name',
                      business,
                    ),

                    infoRow(
                      Icons.phone_outlined,
                      'Mobile',
                      mobile,
                    ),

                    infoRow(
                      Icons.email_outlined,
                      'Email',
                      email,
                    ),

                    infoRow(
                      Icons.location_on_outlined,
                      'Address',
                      address,
                    ),

                    infoRow(
                      Icons.receipt_long_outlined,
                      'GSTIN',
                      gstin,
                    ),

                    infoRow(
                      Icons.badge_outlined,
                      'PAN',
                      pan,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // BILLING & PAYMENT
              // ==================================================

              const Text(
                'Billing & Payment',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF111111),
                ),
              ),

              const SizedBox(height: 12),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding:
                        EdgeInsets.all(20),
                    child:
                        CircularProgressIndicator(
                      color:
                          Color(0xFFE50914),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    summaryCard(
                      icon:
                          Icons.receipt_long_rounded,
                      title:
                          'Total Invoice',
                      value:
                          money(totalInvoiced),
                      iconBackground:
                          const Color(
                        0xFFFFEBEE,
                      ),
                      iconColor:
                          const Color(
                        0xFFE50914,
                      ),
                    ),

                    const SizedBox(width: 10),

                    summaryCard(
                      icon:
                          Icons.account_balance_wallet_rounded,
                      title:
                          'Total Paid',
                      value:
                          money(totalPaid),
                      iconBackground:
                          const Color(
                        0xFFE8F5E9,
                      ),
                      iconColor:
                          Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // OUTSTANDING
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),

                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          Colors.grey.shade200,
                    ),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration:
                            BoxDecoration(
                          color:
                              statusColor.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .pending_actions_rounded,
                          color:
                              statusColor,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Outstanding Amount',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              money(outstanding),
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              statusColor.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          paymentStatus,
                          style: TextStyle(
                            color:
                                statusColor,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // ==================================================
              // PAYMENT MANAGEMENT
              // ==================================================

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(18),

                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        Colors.grey.shade200,
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // HEADER
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFEBEE,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color:
                                Color(0xFFE50914),
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Management',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 3),

                              Text(
                                'Customer payment tracking',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // BUTTONS
                    // ==================================================

                    Row(
                      children: [
                        paymentActionButton(
                          icon:
                              Icons.add_card_rounded,
                          title:
                              'Add Payment',
                          subtitle:
                              'Record a customer payment',
                          onTap:
                              openAddPayment,
                          primary: true,
                        ),

                        const SizedBox(width: 10),

                        paymentActionButton(
                          icon:
                              Icons.history_rounded,
                          title:
                              'Payment History',
                          subtitle:
                              'View all payment records',
                          onTap:
                              openPaymentHistory,
                          primary: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // INFO
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(12),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(0xFFF6F7F9),
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Customer payments are tracked separately. Invoice payment details are not changed.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}