import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _bankNameController =
      TextEditingController();

  final TextEditingController _accountHolderController =
      TextEditingController();

  final TextEditingController _accountNumberController =
      TextEditingController();

  final TextEditingController _ifscController =
      TextEditingController();

  final TextEditingController _branchController =
      TextEditingController();

  final TextEditingController _upiController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadBankDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _bankNameController.text =
          prefs.getString('bank_name') ?? '';

      _accountHolderController.text =
          prefs.getString('bank_account_holder') ?? '';

      _accountNumberController.text =
          prefs.getString('bank_account_number') ?? '';

      _ifscController.text =
          prefs.getString('bank_ifsc') ?? '';

      _branchController.text =
          prefs.getString('bank_branch') ?? '';

      _upiController.text =
          prefs.getString('bank_upi') ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load bank details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'bank_name',
        _bankNameController.text.trim(),
      );

      await prefs.setString(
        'bank_account_holder',
        _accountHolderController.text.trim(),
      );

      await prefs.setString(
        'bank_account_number',
        _accountNumberController.text.trim(),
      );

      await prefs.setString(
        'bank_ifsc',
        _ifscController.text.trim().toUpperCase(),
      );

      await prefs.setString(
        'bank_branch',
        _branchController.text.trim(),
      );

      await prefs.setString(
        'bank_upi',
        _upiController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank details saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save bank details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearBankDetails() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear Bank Details'),
          content: const Text(
            'Are you sure you want to clear all bank details?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('bank_name');
      await prefs.remove('bank_account_holder');
      await prefs.remove('bank_account_number');
      await prefs.remove('bank_ifsc');
      await prefs.remove('bank_branch');
      await prefs.remove('bank_upi');

      _bankNameController.clear();
      _accountHolderController.clear();
      _accountNumberController.clear();
      _ifscController.clear();
      _branchController.clear();
      _upiController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank details cleared'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: primaryRed,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryRed,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool requiredField = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        hint: hint,
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bank Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryRed,
              ),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: darkBlack,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: primaryRed,
                            child: Icon(
                              Icons.account_balance,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bank Account Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'These details can be used for your invoices.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _textField(
                      controller: _bankNameController,
                      label: 'Bank Name',
                      icon: Icons.account_balance_outlined,
                      hint: 'Example: State Bank of India',
                      requiredField: true,
                    ),

                    const SizedBox(height: 14),

                    _textField(
                      controller: _accountHolderController,
                      label: 'Account Holder Name',
                      icon: Icons.person_outline,
                      requiredField: true,
                      textCapitalization:
                          TextCapitalization.words,
                    ),

                    const SizedBox(height: 14),

                    _textField(
                      controller: _accountNumberController,
                      label: 'Account Number',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      requiredField: true,
                    ),

                    const SizedBox(height: 14),

                    _textField(
                      controller: _ifscController,
                      label: 'IFSC Code',
                      icon: Icons.code,
                      hint: 'Example: SBIN0001234',
                      textCapitalization:
                          TextCapitalization.characters,
                      requiredField: true,
                    ),

                    const SizedBox(height: 14),

                    _textField(
                      controller: _branchController,
                      label: 'Branch',
                      icon: Icons.location_on_outlined,
                      textCapitalization:
                          TextCapitalization.words,
                    ),

                    const SizedBox(height: 14),

                    _textField(
                      controller: _upiController,
                      label: 'UPI ID',
                      icon: Icons.payment_outlined,
                      hint: 'Example: name@upi',
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSaving ? null : _saveBankDetails,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : 'Save Bank Details',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _clearBankDetails,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Clear Details',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.red.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Note',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Bank details are stored locally in the app using SharedPreferences.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}