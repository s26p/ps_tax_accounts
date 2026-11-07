import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class AddPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const AddPaymentScreen({
    super.key,
    required this.customer,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController amountController =
      TextEditingController();

  final TextEditingController notesController =
      TextEditingController();

  DateTime selectedDate = DateTime.now();

  String selectedPaymentMode = 'UPI';

  bool isSaving = false;
  bool isLoading = true;

  double totalInvoiced = 0.0;
  double totalPaid = 0.0;
  double outstanding = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCustomerSummary();
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CUSTOMER SUMMARY
  // ============================================================

  Future<void> _loadCustomerSummary() async {
    try {
      final database = DatabaseHelper.instance;

      final customerId = widget.customer['id'] as int;

      final invoiced =
          await database.getCustomerTotalInvoiced(customerId);

      final paid =
          await database.getCustomerTotalPaid(customerId);

      final balance = invoiced - paid;

      if (!mounted) return;

      setState(() {
        totalInvoiced = invoiced;
        totalPaid = paid;
        outstanding = balance < 0 ? 0 : balance;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load customer payment details.',
        isError: true,
      );
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day-$month-$year';
  }

  // ============================================================
  // MONEY FORMAT
  // ============================================================

  String _money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // SAVE PAYMENT
  // ============================================================

  Future<void> _savePayment() async {
    if (isSaving) return;

    final amountText = amountController.text.trim();

    if (amountText.isEmpty) {
      _showMessage(
        'Please enter payment amount.',
        isError: true,
      );
      return;
    }

    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage(
        'Please enter a valid payment amount.',
        isError: true,
      );
      return;
    }

    if (outstanding <= 0) {
      _showMessage(
        'This customer has no outstanding amount.',
        isError: true,
      );
      return;
    }

    if (amount > outstanding + 0.01) {
      _showMessage(
        'Payment cannot be greater than outstanding amount.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final database = DatabaseHelper.instance;

      final customerId = widget.customer['id'] as int;

      // ========================================================
      // INSERT PAYMENT
      // ========================================================

      await database.insertPayment({
        'customer_id': customerId,
        'invoice_id': null,
        'amount': amount,
        'payment_date':
            selectedDate.toIso8601String(),
        'payment_mode': selectedPaymentMode,
        'notes': notesController.text.trim(),
      });

      // ========================================================
      // GET UPDATED PAYMENT TOTAL
      // ========================================================

      final updatedPaid =
          await database.getCustomerTotalPaid(customerId);

      final updatedOutstanding =
          totalInvoiced - updatedPaid;

      if (!mounted) return;

      setState(() {
        totalPaid = updatedPaid;
        outstanding =
            updatedOutstanding < 0 ? 0 : updatedOutstanding;
        isSaving = false;
      });

      // ========================================================
      // SUCCESS MESSAGE
      // ========================================================

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment saved successfully.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Give SnackBar a moment before returning.
      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save payment.',
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? primaryRed : Colors.green,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final customerName =
        (widget.customer['business_name'] ??
                widget.customer['name'] ??
                'Customer')
            .toString();

    final mobile =
        (widget.customer['mobile'] ?? '').toString();

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Add Payment',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryRed,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  30,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // CUSTOMER CARD
                    // ==========================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color: darkBlack,
                        borderRadius:
                            BorderRadius.circular(18),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,

                            decoration: BoxDecoration(
                              color: primaryRed,
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),

                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  customerName,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                if (mobile.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    mobile,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // PAYMENT SUMMARY
                    // ==========================================

                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            title: 'Invoiced',
                            value: _money(totalInvoiced),
                            icon:
                                Icons.receipt_long_rounded,
                            iconColor: Colors.blue,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _summaryCard(
                            title: 'Paid',
                            value: _money(totalPaid),
                            icon:
                                Icons.check_circle_rounded,
                            iconColor: Colors.green,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _summaryCard(
                            title: 'Balance',
                            value: _money(outstanding),
                            icon:
                                Icons.pending_actions_rounded,
                            iconColor: primaryRed,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ==========================================
                    // PAYMENT DETAILS TITLE
                    // ==========================================

                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: darkBlack,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==========================================
                    // AMOUNT
                    // ==========================================

                    _sectionLabel('Payment Amount'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          color: primaryRed,
                        ),

                        hintText: 'Enter payment amount',

                        filled: true,
                        fillColor: Colors.white,

                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: primaryRed,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // DATE
                    // ==========================================

                    _sectionLabel('Payment Date'),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: _selectDate,

                      borderRadius:
                          BorderRadius.circular(14),

                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 17,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: primaryRed,
                              size: 23,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                _formatDate(
                                  selectedDate,
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: darkBlack,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ),

                            const Icon(
                              Icons
                                  .keyboard_arrow_down_rounded,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // PAYMENT MODE
                    // ==========================================

                    _sectionLabel('Payment Mode'),

                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                      ),

                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPaymentMode,

                          isExpanded: true,

                          icon: const Icon(
                            Icons
                                .keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),

                          items: const [
                            DropdownMenuItem(
                              value: 'UPI',
                              child: Text('UPI'),
                            ),
                            DropdownMenuItem(
                              value: 'Cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'Bank Transfer',
                              child:
                                  Text('Bank Transfer'),
                            ),
                            DropdownMenuItem(
                              value: 'Cheque',
                              child: Text('Cheque'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],

                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedPaymentMode =
                                  value;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // NOTES
                    // ==========================================

                    _sectionLabel(
                      'Notes (Optional)',
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: notesController,

                      maxLines: 4,

                      decoration: InputDecoration(
                        hintText:
                            'Enter payment notes if needed...',

                        filled: true,
                        fillColor: Colors.white,

                        alignLabelWithHint: true,

                        prefixIcon: const Padding(
                          padding:
                              EdgeInsets.only(bottom: 60),
                          child: Icon(
                            Icons.notes_rounded,
                            color: primaryRed,
                          ),
                        ),

                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: primaryRed,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ==========================================
                    // SAVE BUTTON
                    // ==========================================

                    SizedBox(
                      width: double.infinity,
                      height: 55,

                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving ? null : _savePayment,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,

                          disabledBackgroundColor:
                              Colors.grey.shade400,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15),
                          ),

                          elevation: 2,
                        ),

                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                              ),

                        label: Text(
                          isSaving
                              ? 'Saving...'
                              : 'Save Payment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // INFORMATION
                    // ==========================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color:
                            Colors.blue.withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(13),
                        border: Border.all(
                          color:
                              Colors.blue.withValues(alpha: 0.15),
                        ),
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              'Payment will be recorded separately for this customer.',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.grey.shade700,
                                height: 1.4,
                              ),
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
  // SECTION LABEL
  // ============================================================

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: darkBlack,
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),

        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            color: iconColor,
            size: 21,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 3),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}