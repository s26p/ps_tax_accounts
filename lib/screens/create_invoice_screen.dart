import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  // If invoice is null -> CREATE mode
  // If invoice is not null -> EDIT mode
  final Map<String, dynamic>? invoice;

  const CreateInvoiceScreen({
    super.key,
    required this.customer,
    this.invoice,
  });

  @override
  State<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState
    extends State<CreateInvoiceScreen> {
  // =====================================================
  // COLORS
  // =====================================================

  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  // =====================================================
  // SERVICE ITEMS
  // =====================================================

  final List<Map<String, TextEditingController>> serviceItems = [];

  final TextEditingController gstController =
      TextEditingController(text: '18');

  // LOCAL / INTERSTATE / WITHOUT_GST
  String gstType = 'LOCAL';

  // Default GST loaded from Invoice Settings
  double defaultGst = 18;

  double subtotal = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;
  double gstAmount = 0;
  double total = 0;

  bool isSaving = false;
  bool isLoadingEdit = false;

  // =====================================================
  // EDIT MODE
  // =====================================================

  bool get isEditMode => widget.invoice != null;

  String get existingInvoiceNumber {
    return (widget.invoice?['invoice_number'] ?? '')
        .toString();
  }

  // =====================================================
  // FORMAT GST
  // =====================================================

  String formatGst(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      // EDIT MODE:
      // Always use GST values saved in this invoice.
      loadExistingInvoice();
    } else {
      // CREATE MODE:
      // Add one service item and load Invoice Settings.
      addServiceItem();
      loadDefaultInvoiceSettings();
    }
  }

  // =====================================================
  // LOAD DEFAULT INVOICE SETTINGS
  // =====================================================

  Future<void> loadDefaultInvoiceSettings() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      // -------------------------------------------------
      // READ DEFAULT GST %
      // -------------------------------------------------

      final double? savedGst =
          prefs.getDouble('invoice_default_gst');

      // -------------------------------------------------
      // READ DEFAULT GST TYPE
      // -------------------------------------------------

      final String? savedGstType =
          prefs.getString('invoice_default_gst_type');

      // -------------------------------------------------
      // DEFAULT GST %
      // -------------------------------------------------

      if (savedGst != null &&
          savedGst >= 0 &&
          savedGst <= 100) {
        defaultGst = savedGst;
      } else {
        defaultGst = 18;
      }

      // -------------------------------------------------
      // DEFAULT GST TYPE
      // -------------------------------------------------

      if (savedGstType == 'LOCAL' ||
          savedGstType == 'INTERSTATE' ||
          savedGstType == 'WITHOUT_GST') {
        gstType = savedGstType!;
      } else {
        gstType = 'LOCAL';
      }

      // -------------------------------------------------
      // SET GST FIELD
      // -------------------------------------------------

      if (gstType == 'WITHOUT_GST') {
        gstController.text = '0';
      } else {
        gstController.text =
            formatGst(defaultGst);
      }

      if (!mounted) return;

      // Recalculate invoice using the newly loaded settings.
      calculateTotal();
    } catch (e) {
      // -------------------------------------------------
      // SAFE FALLBACK
      // -------------------------------------------------

      defaultGst = 18;
      gstType = 'LOCAL';
      gstController.text = '18';

      if (mounted) {
        calculateTotal();
      }
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    for (final item in serviceItems) {
      item['service']?.dispose();
      item['quantity']?.dispose();
      item['rate']?.dispose();
      item['sac_code']?.dispose();
    }

    gstController.dispose();

    super.dispose();
  }

  // =====================================================
  // ADD SERVICE ITEM
  // =====================================================

  void addServiceItem({
    String service = '',
    String quantity = '1',
    String rate = '',
    String sacCode = '',
  }) {
    serviceItems.add({
      'service':
          TextEditingController(text: service),
      'quantity':
          TextEditingController(text: quantity),
      'rate':
          TextEditingController(text: rate),
      'sac_code':
          TextEditingController(text: sacCode),
    });

    if (mounted) {
      setState(() {});
    }
  }

  // =====================================================
  // REMOVE SERVICE ITEM
  // =====================================================

  void removeServiceItem(int index) {
    if (serviceItems.length == 1) {
      showMessage(
        'At least one service is required.',
        Colors.red,
      );
      return;
    }

    final item = serviceItems[index];

    item['service']?.dispose();
    item['quantity']?.dispose();
    item['rate']?.dispose();

    setState(() {
      serviceItems.removeAt(index);
    });

    calculateTotal();
  }

  // =====================================================
  // LOAD EXISTING INVOICE
  // =====================================================

  Future<void> loadExistingInvoice() async {
    setState(() {
      isLoadingEdit = true;
    });

    try {
      final invoice = widget.invoice!;

      // -------------------------------------------------
      // GST TYPE
      // -------------------------------------------------

      final String savedGstType =
          (invoice['gst_type'] ?? 'LOCAL')
              .toString();

      if (savedGstType == 'LOCAL' ||
          savedGstType == 'INTERSTATE' ||
          savedGstType == 'WITHOUT_GST') {
        gstType = savedGstType;
      } else {
        gstType = 'LOCAL';
      }

      // -------------------------------------------------
      // GST %
      // -------------------------------------------------

      final double savedGst =
          (invoice['gst_percent'] as num?)
                  ?.toDouble() ??
              0;

      // Keep edit invoice GST as its own saved value.
      defaultGst = savedGst;

      gstController.text =
          formatGst(savedGst);

      if (gstType == 'WITHOUT_GST') {
        gstController.text = '0';
      }

      // -------------------------------------------------
      // LOAD ITEMS FROM DATABASE
      // -------------------------------------------------

      final invoiceId =
          (invoice['id'] as num?)?.toInt();

      List<Map<String, dynamic>> items = [];

      if (invoiceId != null) {
        items = await DatabaseHelper.instance
            .getInvoiceItems(invoiceId);
      }

      // -------------------------------------------------
      // CLEAR CURRENT ITEMS
      // -------------------------------------------------

      for (final item in serviceItems) {
        item['service']?.dispose();
        item['quantity']?.dispose();
        item['rate']?.dispose();
      item['sac_code']?.dispose();
      }

      serviceItems.clear();

      // -------------------------------------------------
      // LOAD MULTIPLE SERVICE ITEMS
      // -------------------------------------------------

      if (items.isNotEmpty) {
        for (final item in items) {
          final service =
              (item['service'] ?? '')
                  .toString();

          final double quantity =
              (item['quantity'] as num?)
                      ?.toDouble() ??
                  1;

          final double rate =
              (item['rate'] as num?)
                      ?.toDouble() ??
                  0;

          addServiceItem(
            service: service,
            sacCode: (item['sac_code'] ?? '').toString(),
            quantity: quantity.toString(),
            rate: rate == 0
                ? ''
                : formatGst(rate),
          );
        }
      } else {
        // ------------------------------------------------
        // OLD INVOICE COMPATIBILITY
        // ------------------------------------------------

        final service =
            (invoice['service'] ?? '')
                .toString();

        final double quantity =
            (invoice['quantity'] as num?)
                    ?.toDouble() ??
                1;

        final double rate =
            (invoice['rate'] as num?)
                    ?.toDouble() ??
                0;

        addServiceItem(
          service: service,
          quantity: quantity.toString(),
          rate: rate == 0
              ? ''
              : formatGst(rate),
        );
      }

      if (mounted) {
        setState(() {
          isLoadingEdit = false;
        });

        calculateTotal();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingEdit = false;
      });

      showMessage(
        'Unable to load invoice: $e',
        Colors.red,
      );
    }
  }

  // =====================================================
  // SERVICE AMOUNT
  // =====================================================

  double getServiceAmount(
    Map<String, TextEditingController> item,
  ) {
    final quantity =
        double.tryParse(
              item['quantity']?.text.trim() ?? '',
            ) ??
            0;

    final rate =
        double.tryParse(
              item['rate']?.text.trim() ?? '',
            ) ??
            0;

    return quantity * rate;
  }

  // =====================================================
  // GST CALCULATION
  // =====================================================

  void calculateTotal() {
    double calculatedSubtotal = 0;

    for (final item in serviceItems) {
      calculatedSubtotal +=
          getServiceAmount(item);
    }

    final gstPercent =
        double.tryParse(
              gstController.text.trim(),
            ) ??
            0;

    if (gstType == 'WITHOUT_GST') {
      if (!mounted) return;

      setState(() {
        subtotal = calculatedSubtotal;
        cgst = 0;
        sgst = 0;
        igst = 0;
        gstAmount = 0;
        total = calculatedSubtotal;
      });

      return;
    }

    final calculatedGst =
        calculatedSubtotal *
            gstPercent /
            100;

    double calculatedCgst = 0;
    double calculatedSgst = 0;
    double calculatedIgst = 0;

    if (gstType == 'LOCAL') {
      calculatedCgst =
          calculatedGst / 2;

      calculatedSgst =
          calculatedGst / 2;
    } else if (gstType == 'INTERSTATE') {
      calculatedIgst =
          calculatedGst;
    }

    if (!mounted) return;

    setState(() {
      subtotal =
          calculatedSubtotal;

      gstAmount =
          calculatedGst;

      cgst =
          calculatedCgst;

      sgst =
          calculatedSgst;

      igst =
          calculatedIgst;

      total =
          calculatedSubtotal +
              calculatedGst;
    });
  }

  // =====================================================
  // GST TYPE CHANGE
  // =====================================================

  void changeGstType(String type) {
    setState(() {
      gstType = type;

      if (type == 'WITHOUT_GST') {
        gstController.text = '0';
      } else {
        final current =
            double.tryParse(
                  gstController.text.trim(),
                ) ??
                0;

        if (current == 0) {
          final double restoreGst =
              defaultGst > 0
                  ? defaultGst
                  : 18.0;

          gstController.text =
              formatGst(restoreGst);
        }
      }
    });

    calculateTotal();
  }

  // =====================================================
  // SAVE / UPDATE INVOICE
  // =====================================================

  Future<void> saveInvoice() async {
    FocusScope.of(context).unfocus();

    // -----------------------------------------------------
    // VALIDATE SERVICE ITEMS
    // -----------------------------------------------------

    for (int i = 0;
        i < serviceItems.length;
        i++) {
      final item = serviceItems[i];

      final service =
          item['service']?.text.trim() ?? '';

      final quantity =
          double.tryParse(
                item['quantity']?.text.trim() ?? '',
              ) ??
              0;

      final rate =
          double.tryParse(
                item['rate']?.text.trim() ?? '',
              ) ??
              0;

      if (service.isEmpty) {
        showMessage(
          'Please enter Service ${i + 1} description.',
          Colors.red,
        );
        return;
      }

      if (quantity <= 0) {
        showMessage(
          'Quantity must be greater than 0 for Service ${i + 1}.',
          Colors.red,
        );
        return;
      }

      if (rate <= 0) {
        showMessage(
          'Rate must be greater than 0 for Service ${i + 1}.',
          Colors.red,
        );
        return;
      }
    }

    // -----------------------------------------------------
    // GST
    // -----------------------------------------------------

    double gstPercent =
        double.tryParse(
              gstController.text.trim(),
            ) ??
            0;

    if (gstType == 'WITHOUT_GST') {
      gstPercent = 0;
      gstController.text = '0';
    }

    if (gstPercent < 0 ||
        gstPercent > 100) {
      showMessage(
        'GST percentage must be between 0 and 100.',
        Colors.red,
      );
      return;
    }

    // Calculate once before saving
    calculateTotal();

    await Future.delayed(
      const Duration(milliseconds: 50),
    );

    if (!mounted) return;

    setState(() {
      isSaving = true;
    });

    try {
      // ---------------------------------------------------
      // INVOICE NUMBER
      // ---------------------------------------------------

      String invoiceNumber;

      if (isEditMode) {
        // Keep existing invoice number
        invoiceNumber =
            existingInvoiceNumber;
      } else {
        // Generate new invoice number
        invoiceNumber =
            await DatabaseHelper.instance
                .getNextInvoiceNumber();
      }

      // ---------------------------------------------------
      // INVOICE DATE
      // ---------------------------------------------------

      String invoiceDate;

      if (isEditMode &&
          widget.invoice?['invoice_date'] != null) {
        invoiceDate =
            widget.invoice!['invoice_date']
                .toString();
      } else {
        invoiceDate =
            DateTime.now()
                .toIso8601String();
      }

      // ---------------------------------------------------
      // PREPARE DATABASE ITEMS
      // ---------------------------------------------------

      final List<Map<String, dynamic>> items = [];

      for (final item in serviceItems) {
        final service =
            item['service']!.text.trim();

        final quantity =
            double.parse(
          item['quantity']!.text.trim(),
        );

        final rate =
            double.parse(
          item['rate']!.text.trim(),
        );

        final itemSubtotal =
            quantity * rate;

        double itemCgst = 0;
        double itemSgst = 0;
        double itemIgst = 0;
        double itemGstAmount = 0;

        if (gstType != 'WITHOUT_GST') {
          itemGstAmount =
              itemSubtotal *
                  gstPercent /
                  100;

          if (gstType == 'LOCAL') {
            itemCgst =
                itemGstAmount / 2;

            itemSgst =
                itemGstAmount / 2;
          } else if (gstType == 'INTERSTATE') {
            itemIgst =
                itemGstAmount;
          }
        }

        final itemTotal =
            itemSubtotal +
                itemGstAmount;

        items.add({
          'service': service,
          'description': service,
          'sac_code': item['sac_code']!.text.trim(),
          'quantity': quantity,
          'rate': rate,
          'gst_percent':
              gstType == 'WITHOUT_GST'
                  ? 0
                  : gstPercent,
          'gst_type': gstType,
          'subtotal': itemSubtotal,
          'cgst': itemCgst,
          'sgst': itemSgst,
          'igst': itemIgst,
          'gst_amount': itemGstAmount,
          'total': itemTotal,
        });
      }

      // ---------------------------------------------------
      // FIRST SERVICE FOR OLD INVOICE FIELD
      // ---------------------------------------------------

      final firstService =
          serviceItems.first['service']!
              .text
              .trim();

      final firstQuantity =
          double.parse(
        serviceItems.first['quantity']!
            .text
            .trim(),
      );

      final firstRate =
          double.parse(
        serviceItems.first['rate']!
            .text
            .trim(),
      );

      // ---------------------------------------------------
      // INVOICE DATA
      // ---------------------------------------------------

      final invoiceData =
          <String, dynamic>{
        'invoice_number':
            invoiceNumber,

        'invoice_date':
            invoiceDate,

        'customer_id':
            widget.customer['id'],

        // Backward compatibility
        'service':
            firstService,

        'quantity':
            firstQuantity,

        'rate':
            firstRate,

        'gst_percent':
            gstType == 'WITHOUT_GST'
                ? 0
                : gstPercent,

        'gst_type':
            gstType,

        'subtotal':
            subtotal,

        'cgst':
            cgst,

        'sgst':
            sgst,

        'igst':
            igst,

        'gst_amount':
            gstAmount,

        'total':
            total,

        // Keep existing payment information
        'payment_status':
            widget.invoice?['payment_status'] ??
                'PENDING',

        'paid_amount':
            widget.invoice?['paid_amount'] ??
                0,

        'payment_date':
            widget.invoice?['payment_date'],

        'payment_mode':
            widget.invoice?['payment_mode'],
      };

      // ===================================================
      // EDIT
      // ===================================================

      if (isEditMode) {
        final invoiceId =
            (widget.invoice!['id'] as num?)
                ?.toInt();

        if (invoiceId == null) {
          throw Exception(
            'Invoice ID not found.',
          );
        }

        await DatabaseHelper.instance
            .updateInvoiceWithItems(
          invoiceId: invoiceId,
          invoice: invoiceData,
          items: items,
        );

        if (!mounted) return;

        setState(() {
          isSaving = false;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Invoice updated successfully!',
            ),
            backgroundColor:
                Colors.green,
            duration:
                Duration(seconds: 2),
          ),
        );

        await Future.delayed(
          const Duration(
            milliseconds: 700,
          ),
        );

        if (!mounted) return;

        Navigator.pop(
          context,
          true,
        );

        return;
      }

      // ===================================================
      // CREATE NEW INVOICE
      // ===================================================

      final invoiceId =
          await DatabaseHelper.instance
              .insertInvoiceWithItems(
        invoice: invoiceData,
        items: items,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Invoice successfully saved! ID: $invoiceId',
          ),
          backgroundColor:
              Colors.green,
          duration:
              const Duration(seconds: 2),
        ),
      );

      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage(
        isEditMode
            ? 'Invoice update failed: $e'
            : 'Invoice save failed: $e',
        Colors.red,
      );
    }
  }

  // =====================================================
  // MESSAGE
  // =====================================================

  void showMessage(
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // =====================================================
  // TEXT FIELD
  // =====================================================

  Widget invoiceField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? prefixText,
    String? suffixText,
    Function(String)? onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 15,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration:
            InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: primaryRed,
          ),
          prefixText: prefixText,
          suffixText: suffixText,
          filled: true,
          fillColor: enabled
              ? Colors.white
              : Colors.grey.shade100,
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
            borderSide:
                BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
            borderSide:
                BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),
          focusedBorder:
              const OutlineInputBorder(
            borderRadius:
                BorderRadius.all(
              Radius.circular(14),
            ),
            borderSide:
                BorderSide(
              color: primaryRed,
              width: 1.5,
            ),
          ),
          disabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
            borderSide:
                BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // CUSTOMER CARD
  // =====================================================

  Widget customerCard() {
    final name =
        (widget.customer['name'] ?? '')
            .toString();

    final business =
        (widget.customer['business_name'] ??
                '')
            .toString();

    final mobile =
        (widget.customer['mobile'] ?? '')
            .toString();

    final gstin =
        (widget.customer['gstin'] ?? '')
            .toString();

    final firstLetter =
        name.isNotEmpty
            ? name[0].toUpperCase()
            : 'C';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            darkBlack,
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
            width: 55,
            height: 55,
            decoration:
                BoxDecoration(
              color: primaryRed,
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                firstLetter,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 23,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? 'Customer'
                      : name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                if (business.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    business,
                    maxLines: 1,
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
                if (mobile.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    mobile,
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (gstin.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'GSTIN: $gstin',
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SERVICE ITEM CARD
  // =====================================================

  Widget serviceItemCard(int index) {
    final item =
        serviceItems[index];

    final service =
        item['service']!;

    final sacCode =
        item['sac_code']!;

    final quantity =
        item['quantity']!;

    final rate =
        item['rate']!;

    final amount =
        getServiceAmount(item);

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.03,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFEBEE,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style:
                        const TextStyle(
                      color:
                          primaryRed,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Service Item',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              if (serviceItems.length > 1)
                IconButton(
                  onPressed:
                      isSaving
                          ? null
                          : () {
                              removeServiceItem(
                                index,
                              );
                            },
                  icon: const Icon(
                    Icons
                        .delete_outline_rounded,
                    color:
                        primaryRed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // DESCRIPTION
          TextField(
            controller:
                service,
            enabled:
                !isSaving,
            textCapitalization:
                TextCapitalization.sentences,
            onChanged: (_) {
              setState(() {});
              calculateTotal();
            },
            decoration:
                InputDecoration(
              labelText:
                  'Service / Description *',
              hintText:
                  'Eg: GST Registration Charges',
              prefixIcon:
                  const Icon(
                Icons
                    .description_outlined,
                color:
                    primaryRed,
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF8F8F8),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              focusedBorder:
                  const OutlineInputBorder(
                borderRadius:
                    BorderRadius.all(
                  Radius.circular(14),
                ),
                borderSide:
                    BorderSide(
                  color: primaryRed,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // SAC CODE
          TextField(
            controller: sacCode,
            enabled: !isSaving,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'SAC Code',
              hintText: 'Enter service SAC code',
              prefixIcon: const Icon(
                Icons.qr_code_2_rounded,
                color: primaryRed,
              ),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              // QUANTITY
              Expanded(
                child: TextField(
                  controller:
                      quantity,
                  enabled:
                      !isSaving,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    calculateTotal();
                  },
                  decoration:
                      InputDecoration(
                    labelText:
                        'Quantity',
                    prefixIcon:
                        const Icon(
                      Icons
                          .numbers_rounded,
                      color:
                          primaryRed,
                    ),
                    filled: true,
                    fillColor:
                        const Color(
                      0xFFF8F8F8,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // RATE
              Expanded(
                child: TextField(
                  controller:
                      rate,
                  enabled:
                      !isSaving,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    calculateTotal();
                  },
                  decoration:
                      InputDecoration(
                    labelText:
                        'Rate',
                    prefixText:
                        '₹ ',
                    prefixIcon:
                        const Icon(
                      Icons
                          .currency_rupee_rounded,
                      color:
                          primaryRed,
                    ),
                    filled: true,
                    fillColor:
                        const Color(
                      0xFFF8F8F8,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration:
                BoxDecoration(
              color:
                  background,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Item Amount',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                Text(
                  '₹ ${amount.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        primaryRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GST TYPE SELECTOR
  // =====================================================

  Widget gstTypeSelector() {
    return Container(
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
        children: [
          gstOption(
            value: 'LOCAL',
            title:
                'Local / Intra-State',
            subtitle:
                'CGST + SGST',
            icon:
                Icons.home_work_outlined,
          ),
          Divider(
            height: 1,
            color:
                Colors.grey.shade200,
          ),
          gstOption(
            value: 'INTERSTATE',
            title:
                'Inter-State',
            subtitle:
                'IGST',
            icon:
                Icons
                    .local_shipping_outlined,
          ),
          Divider(
            height: 1,
            color:
                Colors.grey.shade200,
          ),
          gstOption(
            value: 'WITHOUT_GST',
            title:
                'Without GST',
            subtitle:
                'No GST • GST 0%',
            icon:
                Icons
                    .money_off_csred_outlined,
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GST OPTION
  // =====================================================

  Widget gstOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected =
        gstType == value;

    return InkWell(
      onTap: isSaving
          ? null
          : () {
              changeGstType(value);
            },
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xFFFFEBEE,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color: selected
                    ? primaryRed
                    : Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Colors.white
                    : Colors.grey.shade700,
                size: 22,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
                      color: selected
                          ? primaryRed
                          : const Color(
                              0xFF222222,
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style:
                        TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width: 24,
              height: 24,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: selected
                    ? primaryRed
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? primaryRed
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      size: 15,
                      color:
                          Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // AMOUNT ROW
  // =====================================================

  Widget amountRow(
    String title,
    String amount, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize:
                bold ? 16 : 14,
            fontWeight:
                bold
                    ? FontWeight.bold
                    : FontWeight.w500,
            color:
                const Color(0xFF222222),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize:
                bold ? 17 : 14,
            fontWeight:
                bold
                    ? FontWeight.bold
                    : FontWeight.w600,
            color:
                darkBlack,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final gstPercent =
        double.tryParse(
              gstController.text.trim(),
            ) ??
            0;

    final halfGst =
        gstPercent / 2;

    final withoutGst =
        gstType == 'WITHOUT_GST';

    return Scaffold(
      backgroundColor:
          background,

      // =================================================
      // APP BAR
      // =================================================

      appBar: AppBar(
        backgroundColor:
            darkBlack,
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              isEditMode
                  ? 'Edit Invoice'
                  : 'Create Invoice',
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              isEditMode
                  ? existingInvoiceNumber
                  : 'PS Tax Consultancy',
              style:
                  const TextStyle(
                fontSize: 10,
                color:
                    Colors.white60,
              ),
            ),
          ],
        ),
      ),

      // =================================================
      // BODY
      // =================================================

      body: isLoadingEdit
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primaryRed,
              ),
            )
          : SingleChildScrollView(
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
                  // =================================================
                  // CUSTOMER
                  // =================================================

                  const Text(
                    'Customer',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          darkBlack,
                    ),
                  ),

                  const SizedBox(height: 10),

                  customerCard(),

                  const SizedBox(height: 24),

                  // =================================================
                  // SERVICES
                  // =================================================

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Services',
                          style:
                              TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                darkBlack,
                          ),
                        ),
                      ),

                      OutlinedButton.icon(
                        onPressed:
                            isSaving
                                ? null
                                : addServiceItem,
                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              primaryRed,
                          side:
                              const BorderSide(
                            color:
                                primaryRed,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                        icon:
                            const Icon(
                          Icons.add,
                          size: 20,
                        ),
                        label:
                            const Text(
                          'Add Service',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // SERVICE ITEMS
                  // =================================================

                  ...List.generate(
                    serviceItems.length,
                    (index) =>
                        serviceItemCard(index),
                  ),

                  const SizedBox(height: 5),

                  // =================================================
                  // GST INFORMATION
                  // =================================================

                  const Text(
                    'GST Information',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          darkBlack,
                    ),
                  ),

                  const SizedBox(height: 12),

                  invoiceField(
                    label:
                        'GST Rate',
                    icon:
                        Icons.percent_rounded,
                    controller:
                        gstController,
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                    suffixText:
                        '%',
                    enabled:
                        !withoutGst &&
                            !isSaving,
                    onChanged: (_) {
                      calculateTotal();
                    },
                  ),

                  if (withoutGst)
                    Container(
                      width:
                          double.infinity,
                      margin:
                          const EdgeInsets.only(
                        bottom: 15,
                      ),
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFE8F5E9,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .check_circle_outline,
                            color:
                                Colors.green,
                            size: 20,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              'GST is not applicable. GST rate has been set to 0%.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.green,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // =================================================
                  // GST TYPE
                  // =================================================

                  const Text(
                    'GST Type',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          darkBlack,
                    ),
                  ),

                  const SizedBox(height: 10),

                  gstTypeSelector(),

                  const SizedBox(height: 24),

                  // =================================================
                  // AMOUNT DETAILS
                  // =================================================

                  const Text(
                    'Amount Details',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          darkBlack,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      border:
                          Border.all(
                        color:
                            Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(
                            alpha: 0.04,
                          ),
                          blurRadius: 10,
                          offset:
                              const Offset(
                            0,
                            4,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        amountRow(
                          'Taxable Amount',
                          '₹ ${subtotal.toStringAsFixed(2)}',
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        if (gstType ==
                            'LOCAL') ...[
                          amountRow(
                            'CGST (${halfGst.toStringAsFixed(2)}%)',
                            '₹ ${cgst.toStringAsFixed(2)}',
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          amountRow(
                            'SGST (${halfGst.toStringAsFixed(2)}%)',
                            '₹ ${sgst.toStringAsFixed(2)}',
                          ),
                        ],

                        if (gstType ==
                            'INTERSTATE')
                          amountRow(
                            'IGST (${gstPercent.toStringAsFixed(2)}%)',
                            '₹ ${igst.toStringAsFixed(2)}',
                          ),

                        if (gstType ==
                            'WITHOUT_GST')
                          amountRow(
                            'GST',
                            '₹ 0.00',
                          ),

                        const SizedBox(
                          height: 15,
                        ),

                        Divider(
                          color:
                              Colors.grey.shade300,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        amountRow(
                          'Total GST',
                          '₹ ${gstAmount.toStringAsFixed(2)}',
                          bold: true,
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        // =================================================
                        // GRAND TOTAL
                        // =================================================

                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets.all(
                            15,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFEBEE,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style:
                                    TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹ ${total.toStringAsFixed(2)}',
                                style:
                                    const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      primaryRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =================================================
                  // SAVE / UPDATE
                  // =================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 56,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          isSaving ||
                                  isLoadingEdit
                              ? null
                              : saveInvoice,
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            primaryRed,
                        foregroundColor:
                            Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.shade400,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                        ),
                        elevation: 3,
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.5,
                                color:
                                    Colors.white,
                              ),
                            )
                          : Icon(
                              isEditMode
                                  ? Icons
                                      .update_rounded
                                  : Icons
                                      .save_rounded,
                            ),
                      label: Text(
                        isSaving
                            ? isEditMode
                                ? 'Updating Invoice...'
                                : 'Saving Invoice...'
                            : isEditMode
                                ? 'Update Invoice'
                                : withoutGst
                                    ? 'Save Invoice'
                                    : 'Save GST Invoice',
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
