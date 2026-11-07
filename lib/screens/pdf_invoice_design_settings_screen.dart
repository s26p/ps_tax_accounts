import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfInvoiceDesignSettingsScreen extends StatefulWidget {
  const PdfInvoiceDesignSettingsScreen({
    super.key,
  });

  @override
  State<PdfInvoiceDesignSettingsScreen> createState() =>
      _PdfInvoiceDesignSettingsScreenState();
}

class _PdfInvoiceDesignSettingsScreenState
    extends State<PdfInvoiceDesignSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  bool showLogo = true;
  bool showBusinessDetails = true;
  bool showGstDetails = true;
  bool showBankDetails = true;
  bool showSignature = true;
  bool showFooter = true;

  String footerText =
      'Thank you for your business.';

  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController footerController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    footerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      if (!mounted) return;

      final savedFooter =
          preferences.getString(
        'invoice_pdf_footer_text',
      );

      setState(() {
        showLogo =
            preferences.getBool(
                  'invoice_pdf_show_logo',
                ) ??
                true;

        showBusinessDetails =
            preferences.getBool(
                  'invoice_pdf_show_business_details',
                ) ??
                true;

        showGstDetails =
            preferences.getBool(
                  'invoice_pdf_show_gst_details',
                ) ??
                true;

        showBankDetails =
            preferences.getBool(
                  'invoice_pdf_show_bank_details',
                ) ??
                true;

        showSignature =
            preferences.getBool(
                  'invoice_pdf_show_signature',
                ) ??
                true;

        showFooter =
            preferences.getBool(
                  'invoice_pdf_show_footer',
                ) ??
                true;

        footerText =
            savedFooter ??
            'Thank you for your business.';

        footerController.text = footerText;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load invoice design settings.',
      );
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      isSaving = true;
    });

    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool(
        'invoice_pdf_show_logo',
        showLogo,
      );

      await preferences.setBool(
        'invoice_pdf_show_business_details',
        showBusinessDetails,
      );

      await preferences.setBool(
        'invoice_pdf_show_gst_details',
        showGstDetails,
      );

      await preferences.setBool(
        'invoice_pdf_show_bank_details',
        showBankDetails,
      );

      await preferences.setBool(
        'invoice_pdf_show_signature',
        showSignature,
      );

      await preferences.setBool(
        'invoice_pdf_show_footer',
        showFooter,
      );

      await preferences.setString(
        'invoice_pdf_footer_text',
        footerController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'PDF / Invoice Design settings saved successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save invoice design settings.',
      );
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Reset Invoice Design',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Reset PDF / Invoice Design settings to the default values?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('RESET'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool(
        'invoice_pdf_show_logo',
        true,
      );

      await preferences.setBool(
        'invoice_pdf_show_business_details',
        true,
      );

      await preferences.setBool(
        'invoice_pdf_show_gst_details',
        true,
      );

      await preferences.setBool(
        'invoice_pdf_show_bank_details',
        true,
      );

      await preferences.setBool(
        'invoice_pdf_show_signature',
        true,
      );

      await preferences.setBool(
        'invoice_pdf_show_footer',
        true,
      );

      await preferences.setString(
        'invoice_pdf_footer_text',
        'Thank you for your business.',
      );

      if (!mounted) return;

      setState(() {
        showLogo = true;
        showBusinessDetails = true;
        showGstDetails = true;
        showBankDetails = true;
        showSignature = true;
        showFooter = true;
        footerText =
            'Thank you for your business.';
        footerController.text =
            footerText;
      });

      _showMessage(
        'Invoice design settings reset successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to reset invoice design settings.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: primaryRed,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        secondary: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primaryRed.withValues(
              alpha: 0.09,
            ),
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: primaryRed,
            size: 23,
          ),
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
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerCard() {
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
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'INVOICE FOOTER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: footerController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText:
                  'Enter invoice footer text',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(
                  bottom: 18,
                ),
                child: Icon(
                  Icons.notes_rounded,
                  color: primaryRed,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
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
                  const OutlineInputBorder(
                borderRadius:
                    BorderRadius.all(
                  Radius.circular(14),
                ),
                borderSide: BorderSide(
                  color: primaryRed,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blue.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'These settings are saved for the invoice PDF design. '
              'The existing invoice layout and business data are not changed automatically.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'PDF / Invoice Design',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkBlack,
        elevation: 0,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryRed,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              Colors.grey.shade300,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(
                              alpha: 0.05,
                            ),
                            blurRadius: 15,
                            offset:
                                const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration:
                                BoxDecoration(
                              color: primaryRed
                                  .withValues(
                                alpha: 0.10,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons
                                  .picture_as_pdf_rounded,
                              size: 38,
                              color: primaryRed,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'PDF / Invoice Design',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                              color: darkBlack,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Manage invoice PDF display preferences',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'PDF DISPLAY OPTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _switchTile(
                      icon:
                          Icons.image_outlined,
                      title: 'Show Logo',
                      subtitle:
                          'Display business logo on the invoice PDF',
                      value: showLogo,
                      onChanged: (value) {
                        setState(() {
                          showLogo = value;
                        });
                      },
                    ),
                    _switchTile(
                      icon:
                          Icons.business_outlined,
                      title:
                          'Show Business Details',
                      subtitle:
                          'Display business name, address and contact details',
                      value:
                          showBusinessDetails,
                      onChanged: (value) {
                        setState(() {
                          showBusinessDetails =
                              value;
                        });
                      },
                    ),
                    _switchTile(
                      icon:
                          Icons.receipt_long_outlined,
                      title: 'Show GST Details',
                      subtitle:
                          'Display GSTIN and GST-related invoice information',
                      value: showGstDetails,
                      onChanged: (value) {
                        setState(() {
                          showGstDetails = value;
                        });
                      },
                    ),
                    _switchTile(
                      icon:
                          Icons.account_balance_outlined,
                      title: 'Show Bank Details',
                      subtitle:
                          'Display bank details on the invoice PDF',
                      value: showBankDetails,
                      onChanged: (value) {
                        setState(() {
                          showBankDetails =
                              value;
                        });
                      },
                    ),
                    _switchTile(
                      icon:
                          Icons.draw_outlined,
                      title: 'Show Signature',
                      subtitle:
                          'Display authorised signature area',
                      value: showSignature,
                      onChanged: (value) {
                        setState(() {
                          showSignature =
                              value;
                        });
                      },
                    ),
                    _switchTile(
                      icon:
                          Icons.notes_outlined,
                      title: 'Show Footer',
                      subtitle:
                          'Display custom footer text on invoice PDF',
                      value: showFooter,
                      onChanged: (value) {
                        setState(() {
                          showFooter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    _footerCard(),
                    const SizedBox(height: 16),
                    _infoCard(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving
                                ? null
                                : _saveSettings,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                              ),
                        label: Text(
                          isSaving
                              ? 'SAVING...'
                              : 'SAVE PDF SETTINGS',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primaryRed,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed:
                            _resetSettings,
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                        ),
                        label: const Text(
                          'RESET PDF SETTINGS',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              primaryRed,
                          side: const BorderSide(
                            color: primaryRed,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
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
