import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../services/invoice_pdf_service.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoice,
  });

  @override
  State<InvoiceDetailsScreen> createState() =>
      _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState
    extends State<InvoiceDetailsScreen> {
  Map<String, dynamic>? customer;

  bool isLoadingCustomer = true;
  bool isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    loadCustomer();
  }

  // =====================================================
  // LOAD CUSTOMER
  // =====================================================

  Future<void> loadCustomer() async {
    final customerId =
        int.tryParse(
              '${widget.invoice['customer_id'] ?? ''}',
            ) ??
            0;

    if (customerId == 0) {
      if (!mounted) return;

      setState(() {
        isLoadingCustomer = false;
      });

      return;
    }

    final data =
        await DatabaseHelper.instance.getCustomerById(
      customerId,
    );

    if (!mounted) return;

    setState(() {
      customer = data;
      isLoadingCustomer = false;
    });
  }

  // =====================================================
  // NUMBER VALUE
  // =====================================================

  double numberValue(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  // =====================================================
  // CREATE PDF
  // =====================================================

  Future<Uint8List> createPdf() async {
  if (customer == null) {
    throw Exception('Customer details not found.');
  }

  return await InvoicePdfService.createPdf(
    widget.invoice,
    customer!,
  );
}

  // =====================================================
  // GENERATE PDF
  // =====================================================

  Future<void> generatePdf() async {
    if (isGeneratingPdf) return;

    setState(() {
      isGeneratingPdf = true;
    });

    try {
      final pdf = await createPdf();

      await Printing.layoutPdf(
        onLayout: (format) async => pdf,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF உருவாக்க முடியவில்லை: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingPdf = false;
        });
      }
    }
  }

  // =====================================================
  // SHARE PDF
  // =====================================================

  Future<void> sharePdf() async {
    if (isGeneratingPdf) return;

    setState(() {
      isGeneratingPdf = true;
    });

    try {
      final pdf = await createPdf();

      await Printing.sharePdf(
        bytes: pdf,
        filename:
            '${widget.invoice['invoice_number'] ?? 'invoice'}.pdf',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF Share செய்ய முடியவில்லை: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingPdf = false;
        });
      }
    }
  }

  // =====================================================
  // DETAIL ROW
  // =====================================================

  Widget detailRow(
    String title,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(
                fontWeight:
                    highlight
                        ? FontWeight.bold
                        : FontWeight.w600,
                fontSize:
                    highlight ? 16 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight:
                    highlight
                        ? FontWeight.bold
                        : FontWeight.normal,
                fontSize:
                    highlight ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;

    // =====================================================
    // BASIC VALUES
    // =====================================================

    final quantity =
        numberValue(invoice['quantity']);

    final rate =
        numberValue(invoice['rate']);

    final gstPercent =
        numberValue(invoice['gst_percent']);

    final subtotal =
        numberValue(invoice['subtotal']);

    // =====================================================
    // GST VALUES
    // =====================================================

    final cgst =
        numberValue(invoice['cgst']);

    final sgst =
        numberValue(invoice['sgst']);

    final igst =
        numberValue(invoice['igst']);

    final gstAmount =
        numberValue(invoice['gst_amount']);

    final total =
        numberValue(invoice['total']);

    // =====================================================
    // GST TYPE
    // =====================================================

    final gstType =
        '${invoice['gst_type'] ?? 'LOCAL'}'
            .toUpperCase();

    // =====================================================
    // GST TYPE CHECK
    // =====================================================

    final isNoGst =
        gstType == 'NO_GST' ||
        gstType == 'NO GST' ||
        gstType == 'WITHOUT GST';

    final isInterState =
        gstType == 'INTER-STATE' ||
        gstType == 'INTERSTATE' ||
        gstType == 'IGST';

    // =====================================================
    // TAX LABEL
    // =====================================================

    final halfGst =
        gstPercent / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invoice Details',
        ),
      ),

      body: isLoadingCustomer
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // =================================================
                  // BUSINESS HEADER
                  // =================================================

                  Card(
                    elevation: 3,

                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),

                      child: Column(
                        children: [

                          const Text(
                            'PS TAX CONSULTANCY',
                            textAlign:
                                TextAlign.center,

                            style: TextStyle(
                              fontSize: 23,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          const Text(
                            'VV COMPLEX, UDAIYARPALAYAM MAIN ROAD, SENDURAI',
                            textAlign:
                                TextAlign.center,
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          const Text(
                            'Mobile: 7339533148 / 7010309360',
                            textAlign:
                                TextAlign.center,
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          const Text(
                            'Email: pskumarconsultant@gmail.com',
                            textAlign:
                                TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // =================================================
                  // CUSTOMER DETAILS
                  // =================================================

                  const Text(
                    'CUSTOMER DETAILS',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          detailRow(
                            'Name',
                            '${customer?['name'] ?? '-'}',
                          ),

                          detailRow(
                            'Business',
                            '${customer?['business_name'] ?? '-'}',
                          ),

                          detailRow(
                            'Mobile',
                            '${customer?['mobile'] ?? '-'}',
                          ),

                          detailRow(
                            'Email',
                            '${customer?['email'] ?? '-'}',
                          ),

                          detailRow(
                            'Address',
                            '${customer?['address'] ?? '-'}',
                          ),

                          detailRow(
                            'GSTIN',
                            '${customer?['gstin'] ?? '-'}',
                          ),

                          detailRow(
                            'PAN',
                            '${customer?['pan'] ?? '-'}',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // =================================================
                  // INVOICE DETAILS
                  // =================================================

                  const Text(
                    'INVOICE DETAILS',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),

                      child: Column(
                        children: [

                          detailRow(
                            'Invoice No',
                            '${invoice['invoice_number'] ?? '-'}',
                          ),

                          detailRow(
                            'Invoice Date',
                            '${invoice['invoice_date'] ?? '-'}',
                          ),

                          detailRow(
                            'Service',
                            '${invoice['service'] ?? '-'}',
                          ),

                          detailRow(
                            'Quantity',
                            quantity.toString(),
                          ),

                          detailRow(
                            'Rate',
                            '₹ ${rate.toStringAsFixed(2)}',
                          ),

                          detailRow(
                            'GST Type',
                            isNoGst
                                ? 'WITHOUT GST'
                                : gstType,
                          ),

                          detailRow(
                            'GST Rate',
                            isNoGst
                                ? '0.00%'
                                : '${gstPercent.toStringAsFixed(2)}%',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // =================================================
                  // AMOUNT DETAILS
                  // =================================================

                  const Text(
                    'AMOUNT DETAILS',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Card(
                    elevation: 2,

                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),

                      child: Column(
                        children: [

                          // -----------------------------
                          // SUBTOTAL
                          // -----------------------------

                          detailRow(
                            'Subtotal',
                            '₹ ${subtotal.toStringAsFixed(2)}',
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          // =================================================
                          // WITHOUT GST
                          // =================================================

                          if (isNoGst) ...[
                            detailRow(
                              'GST',
                              'No GST',
                            ),
                          ]

                          // =================================================
                          // INTER-STATE GST
                          // =================================================

                          else if (isInterState) ...[
                            detailRow(
                              'IGST @ ${gstPercent.toStringAsFixed(2)}%',
                              '₹ ${igst.toStringAsFixed(2)}',
                            ),
                          ]

                          // =================================================
                          // LOCAL GST
                          // =================================================

                          else ...[
                            detailRow(
                              'CGST @ ${halfGst.toStringAsFixed(2)}%',
                              '₹ ${cgst.toStringAsFixed(2)}',
                            ),

                            detailRow(
                              'SGST @ ${halfGst.toStringAsFixed(2)}%',
                              '₹ ${sgst.toStringAsFixed(2)}',
                            ),
                          ],

                          const Divider(
                            height: 25,
                          ),

                          // -----------------------------
                          // TOTAL GST
                          // -----------------------------

                          detailRow(
                            'Total GST',
                            '₹ ${gstAmount.toStringAsFixed(2)}',
                          ),

                          const Divider(
                            height: 25,
                          ),

                          // -----------------------------
                          // GRAND TOTAL
                          // -----------------------------

                          detailRow(
                            'TOTAL',
                            '₹ ${total.toStringAsFixed(2)}',
                            highlight: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // =================================================
                  // GENERATE PDF
                  // =================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,

                    child:
                        ElevatedButton.icon(
                      onPressed:
                          isGeneratingPdf
                              ? null
                              : generatePdf,

                      icon: const Icon(
                        Icons.picture_as_pdf,
                      ),

                      label: Text(
                        isGeneratingPdf
                            ? 'Creating PDF...'
                            : 'Generate PDF',

                        style:
                            const TextStyle(
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // =================================================
                  // SHARE PDF
                  // =================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,

                    child:
                        ElevatedButton.icon(
                      onPressed:
                          isGeneratingPdf
                              ? null
                              : sharePdf,

                      icon: const Icon(
                        Icons.share,
                      ),

                      label: Text(
                        isGeneratingPdf
                            ? 'Please wait...'
                            : 'Share Invoice',

                        style:
                            const TextStyle(
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // =================================================
                  // FOOTER
                  // =================================================

                  const Center(
                    child: Text(
                       'Thank you for your business',

                      style: TextStyle(
                        fontStyle:
                            FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            ),
    );
  }
}