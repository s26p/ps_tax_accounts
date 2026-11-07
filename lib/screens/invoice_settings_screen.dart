import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() =>
      _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState
    extends State<InvoiceSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController gstController =
      TextEditingController();

  String gstType = 'LOCAL';
  String dateFormat = 'DD-MM-YYYY';

  String nextInvoiceNumber = 'Loading...';

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    gstController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD SETTINGS
  // ============================================================

  Future<void> loadSettings() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final savedGst =
          prefs.getDouble('invoice_default_gst');

      final savedGstType =
          prefs.getString('invoice_default_gst_type');

      final savedDateFormat =
          prefs.getString('invoice_date_format');

      gstController.text =
          (savedGst ?? 18).toStringAsFixed(
        (savedGst ?? 18) ==
                (savedGst ?? 18).roundToDouble()
            ? 0
            : 2,
      );

      if (savedGstType == 'LOCAL' ||
          savedGstType == 'INTERSTATE' ||
          savedGstType == 'WITHOUT_GST') {
        gstType = savedGstType!;
      } else {
        gstType = 'LOCAL';
      }

      if (savedDateFormat != null &&
          savedDateFormat.isNotEmpty) {
        dateFormat = savedDateFormat;
      }

      await loadNextInvoiceNumber();

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(
        'Unable to load Invoice Settings: $e',
        Colors.red,
      );
    }
  }

  // ============================================================
  // NEXT INVOICE NUMBER
  // ============================================================

  Future<void> loadNextInvoiceNumber() async {
    try {
      final number =
          await DatabaseHelper.instance
              .getNextInvoiceNumber();

      if (!mounted) return;

      setState(() {
        nextInvoiceNumber = number;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        nextInvoiceNumber = 'Unable to load';
      });
    }
  }

  // ============================================================
  // SAVE SETTINGS
  // ============================================================

  Future<void> saveSettings() async {
    FocusScope.of(context).unfocus();

    double gst =
        double.tryParse(
              gstController.text.trim(),
            ) ??
            -1;

    if (gst < 0 || gst > 100) {
      showMessage(
        'GST percentage must be between 0 and 100.',
        Colors.red,
      );
      return;
    }

    if (gstType == 'WITHOUT_GST') {
      gst = 0;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setDouble(
        'invoice_default_gst',
        gst,
      );

      await prefs.setString(
        'invoice_default_gst_type',
        gstType,
      );

      await prefs.setString(
        'invoice_date_format',
        dateFormat,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Invoice Settings saved successfully!',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

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

      showMessage(
        'Failed to save Invoice Settings: $e',
        Colors.red,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

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

  // ============================================================
  // SETTING CARD
  // ============================================================

  Widget settingCard({
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget label(
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: darkBlack,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Invoice Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryRed,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // INVOICE NUMBER
                    // ==================================================

                    const Text(
                      'INVOICE NUMBER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryRed,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 10),

                    settingCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: primaryRed
                                      .withValues(alpha: 0.10),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: primaryRed,
                                ),
                              ),

                              const SizedBox(width: 14),

                              const Expanded(
                                child: Text(
                                  'Invoice Prefix',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),

                              const Text(
                                'PSTC-INV-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: darkBlack,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          const Divider(),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              const Icon(
                                Icons.numbers,
                                color: primaryRed,
                              ),

                              const SizedBox(width: 12),

                              const Expanded(
                                child: Text(
                                  'Next Invoice Number',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),

                              Text(
                                nextInvoiceNumber,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: primaryRed,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Invoice numbers are generated automatically and deleted numbers are not reused.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // GST SETTINGS
                    // ==================================================

                    const Text(
                      'GST SETTINGS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryRed,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 10),

                    settingCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          label('Default GST Percentage'),

                          TextField(
                            controller: gstController,
                            keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                              decimal: true,
                            ),
                            decoration:
                                InputDecoration(
                              hintText: '18',
                              suffixText: '%',
                              prefixIcon:
                                  const Icon(
                                Icons.percent,
                                color: primaryRed,
                              ),
                              filled: true,
                              fillColor:
                                  background,
                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                                borderSide:
                                    BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              if (gstType ==
                                  'WITHOUT_GST') {
                                gstType = 'LOCAL';

                                setState(() {});
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          label('Default GST Type'),

                          DropdownButtonFormField<String>(
                            initialValue: gstType,
                            decoration:
                                InputDecoration(
                              prefixIcon:
                                  const Icon(
                                Icons.account_balance,
                                color: primaryRed,
                              ),
                              filled: true,
                              fillColor:
                                  background,
                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                                borderSide:
                                    BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'LOCAL',
                                child: Text(
                                  'LOCAL - CGST + SGST',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'INTERSTATE',
                                child: Text(
                                  'INTERSTATE - IGST',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'WITHOUT_GST',
                                child: Text(
                                  'WITHOUT GST',
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                gstType = value;

                                if (value ==
                                    'WITHOUT_GST') {
                                  gstController.text =
                                      '0';
                                } else if (double.tryParse(
                                          gstController
                                              .text
                                              .trim(),
                                        ) ==
                                        0) {
                                  gstController.text =
                                      '18';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // DATE FORMAT
                    // ==================================================

                    const Text(
                      'DATE FORMAT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryRed,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 10),

                    settingCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          label(
                            'Invoice Date Format',
                          ),

                          DropdownButtonFormField<String>(
                            initialValue: dateFormat,
                            decoration:
                                InputDecoration(
                              prefixIcon:
                                  const Icon(
                                Icons.calendar_month,
                                color: primaryRed,
                              ),
                              filled: true,
                              fillColor:
                                  background,
                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                                borderSide:
                                    BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'DD-MM-YYYY',
                                child:
                                    Text('DD-MM-YYYY'),
                              ),
                              DropdownMenuItem(
                                value: 'DD/MM/YYYY',
                                child:
                                    Text('DD/MM/YYYY'),
                              ),
                              DropdownMenuItem(
                                value: 'YYYY-MM-DD',
                                child:
                                    Text('YYYY-MM-DD'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                dateFormat = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // SAVE
                    // ==================================================

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving
                                ? null
                                : saveSettings,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primaryRed,
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save,
                              ),
                        label: Text(
                          isSaving
                              ? 'Saving...'
                              : 'Save Settings',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                          ),
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
