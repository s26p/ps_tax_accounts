import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState
    extends State<BusinessProfileScreen> {
  // ==========================================================
  // COLORS
  // ==========================================================

  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  final TextEditingController businessNameController =
      TextEditingController();

  final TextEditingController ownerNameController =
      TextEditingController();

  final TextEditingController mobileController =
      TextEditingController();

  final TextEditingController whatsappController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController addressController =
      TextEditingController();

  final TextEditingController gstinController =
      TextEditingController();

  final TextEditingController panController =
      TextEditingController();

  final TextEditingController bankNameController =
      TextEditingController();

  final TextEditingController accountNumberController =
      TextEditingController();

  final TextEditingController ifscController =
      TextEditingController();

  final TextEditingController branchController =
      TextEditingController();

  final TextEditingController invoicePrefixController =
      TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  // ==========================================================
  // LOAD BUSINESS PROFILE
  // ==========================================================

  Future<void> _loadBusinessProfile() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      businessNameController.text =
          preferences.getString('business_name') ??
              'PS Tax Consultancy';

      ownerNameController.text =
          preferences.getString('owner_name') ?? '';

      mobileController.text =
          preferences.getString('business_mobile') ?? '';

      whatsappController.text =
          preferences.getString('business_whatsapp') ?? '';

      emailController.text =
          preferences.getString('business_email') ?? '';

      addressController.text =
          preferences.getString('business_address') ?? '';

      gstinController.text =
          preferences.getString('business_gstin') ?? '';

      panController.text =
          preferences.getString('business_pan') ?? '';

      bankNameController.text =
          preferences.getString('bank_name') ?? '';

      accountNumberController.text =
          preferences.getString('account_number') ?? '';

      ifscController.text =
          preferences.getString('ifsc_code') ?? '';

      branchController.text =
          preferences.getString('bank_branch') ?? '';

      invoicePrefixController.text =
          preferences.getString('invoice_prefix') ?? 'INV';

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // ==========================================================
  // SAVE BUSINESS PROFILE
  // ==========================================================

  Future<void> _saveBusinessProfile() async {
    if (businessNameController.text.trim().isEmpty) {
      _showMessage(
        'Business Name is required',
        isError: true,
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
        'business_name',
        businessNameController.text.trim(),
      );

      await preferences.setString(
        'owner_name',
        ownerNameController.text.trim(),
      );

      await preferences.setString(
        'business_mobile',
        mobileController.text.trim(),
      );

      await preferences.setString(
        'business_whatsapp',
        whatsappController.text.trim(),
      );

      await preferences.setString(
        'business_email',
        emailController.text.trim(),
      );

      await preferences.setString(
        'business_address',
        addressController.text.trim(),
      );

      await preferences.setString(
        'business_gstin',
        gstinController.text.trim().toUpperCase(),
      );

      await preferences.setString(
        'business_pan',
        panController.text.trim().toUpperCase(),
      );

      await preferences.setString(
        'bank_name',
        bankNameController.text.trim(),
      );

      await preferences.setString(
        'account_number',
        accountNumberController.text.trim(),
      );

      await preferences.setString(
        'ifsc_code',
        ifscController.text.trim().toUpperCase(),
      );

      await preferences.setString(
        'bank_branch',
        branchController.text.trim(),
      );

      await preferences.setString(
        'invoice_prefix',
        invoicePrefixController.text.trim().toUpperCase(),
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Business Profile saved successfully',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save Business Profile',
        isError: true,
      );
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    businessNameController.dispose();
    ownerNameController.dispose();
    mobileController.dispose();
    whatsappController.dispose();
    emailController.dispose();
    addressController.dispose();
    gstinController.dispose();
    panController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    ifscController.dispose();
    branchController.dispose();
    invoicePrefixController.dispose();

    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ======================================================
      // APP BAR
      // ======================================================

      appBar: AppBar(
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Business Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ======================================================
      // BODY
      // ======================================================

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
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
                  // =================================================
                  // PROFILE HEADER
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF111111),
                          Color(0xFF292929),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          padding:
                              const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                          child: Image.asset(
                            'assets/images/ps_tax_consultancy_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PS Tax Consultancy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'BUSINESS PROFILE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryRed,
                                  borderRadius:
                                      BorderRadius.circular(
                                    15,
                                  ),
                                ),
                                child: const Text(
                                  'Edit Business Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // BUSINESS INFORMATION
                  // =================================================

                  _sectionTitle(
                    'Business Information',
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller:
                        businessNameController,
                    label: 'Business Name',
                    hint: 'Enter business name',
                    icon:
                        Icons.business_outlined,
                    required: true,
                  ),

                  _textField(
                    controller:
                        ownerNameController,
                    label:
                        'Owner / Consultant Name',
                    hint:
                        'Enter owner or consultant name',
                    icon:
                        Icons.person_outline_rounded,
                  ),

                  _textField(
                    controller:
                        mobileController,
                    label: 'Mobile Number',
                    hint:
                        'Enter mobile number',
                    icon:
                        Icons.phone_outlined,
                    keyboardType:
                        TextInputType.phone,
                  ),

                  _textField(
                    controller:
                        whatsappController,
                    label: 'WhatsApp Number',
                    hint:
                        'Enter WhatsApp number',
                    icon:
                        Icons.chat_outlined,
                    keyboardType:
                        TextInputType.phone,
                  ),

                  _textField(
                    controller:
                        emailController,
                    label: 'Email Address',
                    hint:
                        'Enter email address',
                    icon:
                        Icons.email_outlined,
                    keyboardType:
                        TextInputType.emailAddress,
                  ),

                  _textField(
                    controller:
                        addressController,
                    label: 'Business Address',
                    hint:
                        'Enter complete business address',
                    icon:
                        Icons.location_on_outlined,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // TAX INFORMATION
                  // =================================================

                  _sectionTitle(
                    'Tax Information',
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller:
                        gstinController,
                    label: 'GSTIN',
                    hint:
                        'Enter GSTIN',
                    icon:
                        Icons.receipt_long_outlined,
                    textCapitalization:
                        TextCapitalization.characters,
                  ),

                  _textField(
                    controller:
                        panController,
                    label: 'PAN',
                    hint:
                        'Enter PAN',
                    icon:
                        Icons.badge_outlined,
                    textCapitalization:
                        TextCapitalization.characters,
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // BANK INFORMATION
                  // =================================================

                  _sectionTitle(
                    'Bank Information',
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller:
                        bankNameController,
                    label: 'Bank Name',
                    hint:
                        'Enter bank name',
                    icon:
                        Icons.account_balance_outlined,
                  ),

                  _textField(
                    controller:
                        accountNumberController,
                    label: 'Account Number',
                    hint:
                        'Enter account number',
                    icon:
                        Icons.credit_card_outlined,
                    keyboardType:
                        TextInputType.number,
                  ),

                  _textField(
                    controller:
                        ifscController,
                    label: 'IFSC Code',
                    hint:
                        'Enter IFSC code',
                    icon:
                        Icons.account_balance_wallet_outlined,
                    textCapitalization:
                        TextCapitalization.characters,
                  ),

                  _textField(
                    controller:
                        branchController,
                    label: 'Branch',
                    hint:
                        'Enter bank branch',
                    icon:
                        Icons.location_city_outlined,
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // INVOICE SETTINGS
                  // =================================================

                  _sectionTitle(
                    'Invoice Settings',
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller:
                        invoicePrefixController,
                    label: 'Invoice Prefix',
                    hint:
                        'Example: INV',
                    icon:
                        Icons.tag_outlined,
                    textCapitalization:
                        TextCapitalization.characters,
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // SAVE BUTTON
                  // =================================================

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : _saveBusinessProfile,
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
                              Icons.save_outlined,
                            ),
                      label: Text(
                        isSaving
                            ? 'SAVING...'
                            : 'SAVE BUSINESS PROFILE',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            primaryRed,
                        foregroundColor:
                            Colors.white,
                        disabledBackgroundColor:
                            Colors.grey,
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

                  const SizedBox(height: 25),

                  // =================================================
                  // FOOTER
                  // =================================================

                  const Center(
                    child: Text(
                      'PS Tax Consultancy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.black45,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Center(
                    child: Text(
                      'Professional Tax & Business Solutions',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: primaryRed,
            borderRadius:
                BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 9),

        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkBlack,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // TEXT FIELD
  // ==========================================================

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText:
              required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: darkBlack,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: primaryRed,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}