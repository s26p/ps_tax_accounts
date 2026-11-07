import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() =>
      _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState
    extends State<PaymentSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  String defaultPaymentMethod = 'UPI';

  bool cashEnabled = true;
  bool upiEnabled = true;
  bool bankTransferEnabled = true;
  bool cardEnabled = true;

  bool isLoading = true;
  bool isSaving = false;

  final List<String> paymentMethods = [
    'UPI',
    'Cash',
    'Bank Transfer',
    'Card',
  ];

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  Future<void> _loadPaymentSettings() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        defaultPaymentMethod =
            preferences.getString(
                  'default_payment_method',
                ) ??
                'UPI';

        cashEnabled =
            preferences.getBool(
                  'payment_cash_enabled',
                ) ??
                true;

        upiEnabled =
            preferences.getBool(
                  'payment_upi_enabled',
                ) ??
                true;

        bankTransferEnabled =
            preferences.getBool(
                  'payment_bank_enabled',
                ) ??
                true;

        cardEnabled =
            preferences.getBool(
                  'payment_card_enabled',
                ) ??
                true;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load payment settings.',
      );
    }
  }

  Future<void> _savePaymentSettings() async {
    if (!_isDefaultMethodEnabled()) {
      _showMessage(
        'Please select an enabled payment method as default.',
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setString(
        'default_payment_method',
        defaultPaymentMethod,
      );

      await preferences.setBool(
        'payment_cash_enabled',
        cashEnabled,
      );

      await preferences.setBool(
        'payment_upi_enabled',
        upiEnabled,
      );

      await preferences.setBool(
        'payment_bank_enabled',
        bankTransferEnabled,
      );

      await preferences.setBool(
        'payment_card_enabled',
        cardEnabled,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Payment settings saved successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save payment settings.',
      );
    }
  }

  Future<void> _resetPaymentSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Reset Payment Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Reset payment settings to the default values?',
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

      await preferences.setString(
        'default_payment_method',
        'UPI',
      );

      await preferences.setBool(
        'payment_cash_enabled',
        true,
      );

      await preferences.setBool(
        'payment_upi_enabled',
        true,
      );

      await preferences.setBool(
        'payment_bank_enabled',
        true,
      );

      await preferences.setBool(
        'payment_card_enabled',
        true,
      );

      if (!mounted) return;

      setState(() {
        defaultPaymentMethod = 'UPI';
        cashEnabled = true;
        upiEnabled = true;
        bankTransferEnabled = true;
        cardEnabled = true;
      });

      _showMessage(
        'Payment settings reset successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to reset payment settings.',
      );
    }
  }

  bool _isDefaultMethodEnabled() {
    switch (defaultPaymentMethod) {
      case 'Cash':
        return cashEnabled;
      case 'UPI':
        return upiEnabled;
      case 'Bank Transfer':
        return bankTransferEnabled;
      case 'Card':
        return cardEnabled;
      default:
        return false;
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

  Widget _paymentMethodTile({
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

  Widget _defaultMethodCard() {
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
            'DEFAULT PAYMENT METHOD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: defaultPaymentMethod,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.account_balance_wallet_outlined,
                color: primaryRed,
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
            items: paymentMethods
                .map(
                  (method) =>
                      DropdownMenuItem<String>(
                    value: method,
                    child: Text(method),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                defaultPaymentMethod = value;
              });
            },
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
              'Payment Settings controls the payment methods available '
              'for customer payment records. The selected default method '
              'can be used as the preferred payment option.',
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
          'Payment Settings',
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.grey.shade300,
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
                                  .payments_rounded,
                              size: 38,
                              color: primaryRed,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Payment Settings',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                              color: darkBlack,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Manage payment method preferences',
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
                    _defaultMethodCard(),
                    const SizedBox(height: 20),
                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'PAYMENT METHODS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _paymentMethodTile(
                      icon:
                          Icons.currency_rupee_rounded,
                      title: 'Cash',
                      subtitle:
                          'Allow cash payment records',
                      value: cashEnabled,
                      onChanged: (value) {
                        if (!value &&
                            !_hasAnotherMethod(
                              'Cash',
                            )) {
                          _showMessage(
                            'At least one payment method must remain enabled.',
                          );
                          return;
                        }

                        setState(() {
                          cashEnabled = value;
                        });
                      },
                    ),
                    _paymentMethodTile(
                      icon:
                          Icons.qr_code_2_rounded,
                      title: 'UPI',
                      subtitle:
                          'Allow UPI payment records',
                      value: upiEnabled,
                      onChanged: (value) {
                        if (!value &&
                            !_hasAnotherMethod(
                              'UPI',
                            )) {
                          _showMessage(
                            'At least one payment method must remain enabled.',
                          );
                          return;
                        }

                        setState(() {
                          upiEnabled = value;
                        });
                      },
                    ),
                    _paymentMethodTile(
                      icon:
                          Icons.account_balance_rounded,
                      title: 'Bank Transfer',
                      subtitle:
                          'Allow bank transfer payment records',
                      value: bankTransferEnabled,
                      onChanged: (value) {
                        if (!value &&
                            !_hasAnotherMethod(
                              'Bank Transfer',
                            )) {
                          _showMessage(
                            'At least one payment method must remain enabled.',
                          );
                          return;
                        }

                        setState(() {
                          bankTransferEnabled = value;
                        });
                      },
                    ),
                    _paymentMethodTile(
                      icon:
                          Icons.credit_card_rounded,
                      title: 'Card',
                      subtitle:
                          'Allow card payment records',
                      value: cardEnabled,
                      onChanged: (value) {
                        if (!value &&
                            !_hasAnotherMethod(
                              'Card',
                            )) {
                          _showMessage(
                            'At least one payment method must remain enabled.',
                          );
                          return;
                        }

                        setState(() {
                          cardEnabled = value;
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    _infoCard(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving
                                ? null
                                : _savePaymentSettings,
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
                              : 'SAVE PAYMENT SETTINGS',
                          style: const TextStyle(
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
                            _resetPaymentSettings,
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                        ),
                        label: const Text(
                          'RESET PAYMENT SETTINGS',
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

  bool _hasAnotherMethod(String currentMethod) {
    int enabledCount = 0;

    if (cashEnabled) enabledCount++;
    if (upiEnabled) enabledCount++;
    if (bankTransferEnabled) enabledCount++;
    if (cardEnabled) enabledCount++;

    if (currentMethod == defaultPaymentMethod &&
        enabledCount <= 1) {
      return false;
    }

    return enabledCount > 1;
  }
}

