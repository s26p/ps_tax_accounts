import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class AddCustomerScreen extends StatefulWidget {
  final Map<String, dynamic>? customer;

  const AddCustomerScreen({
    super.key,
    this.customer,
  });

  bool get isEditMode => customer != null;

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  // ==========================================================
  // DATABASE
  // ==========================================================

  final DatabaseHelper db = DatabaseHelper.instance;

  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  final nameController = TextEditingController();
  final businessController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final gstinController = TextEditingController();
  final panController = TextEditingController();

  bool isSaving = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    if (widget.customer != null) {
      final customer = widget.customer!;

      nameController.text =
          customer['name']?.toString() ?? '';

      businessController.text =
          customer['business_name']?.toString() ?? '';

      mobileController.text =
          customer['mobile']?.toString() ?? '';

      emailController.text =
          customer['email']?.toString() ?? '';

      addressController.text =
          customer['address']?.toString() ?? '';

      gstinController.text =
          customer['gstin']?.toString() ?? '';

      panController.text =
          customer['pan']?.toString() ?? '';
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    nameController.dispose();
    businessController.dispose();
    mobileController.dispose();
    emailController.dispose();
    addressController.dispose();
    gstinController.dispose();
    panController.dispose();

    super.dispose();
  }

  // ==========================================================
  // SAVE / UPDATE CUSTOMER
  // ==========================================================

  Future<void> saveCustomer() async {
    FocusScope.of(context).unfocus();

    // --------------------------------------------------------
    // VALIDATION
    // --------------------------------------------------------

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter customer name',
          ),
        ),
      );
      return;
    }

    if (mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter mobile number',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final customer = <String, dynamic>{
      'name': nameController.text.trim(),
      'business_name': businessController.text.trim(),
      'mobile': mobileController.text.trim(),
      'email': emailController.text.trim(),
      'address': addressController.text.trim(),
      'gstin': gstinController.text.trim().toUpperCase(),
      'pan': panController.text.trim().toUpperCase(),
    };

    try {
      // ======================================================
      // EDIT CUSTOMER
      // ======================================================

      if (widget.isEditMode) {
        final originalCustomer = widget.customer!;

        final originalId = originalCustomer['id'];

        final customerId = originalId is int
            ? originalId
            : int.parse(originalId.toString());

        await db.updateCustomer(
          customerId,
          customer,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Customer updated successfully',
            ),
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
      }

      // ======================================================
      // ADD NEW CUSTOMER
      // ======================================================

      else {
        await db.insertCustomer(customer);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Customer successfully saved',
            ),
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Unable to update customer: $e'
                : 'Unable to save customer: $e',
          ),
        ),
      );

      setState(() {
        isSaving = false;
      });
    }
  }

  // ==========================================================
  // INPUT FIELD
  // ==========================================================

  Widget inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool textCapitalization = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: textCapitalization
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: Colors.red.shade700,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
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
              color: Color(0xFFE50914),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final editMode = widget.isEditMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),

      // ======================================================
      // APP BAR
      // ======================================================

      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          editMode
              ? 'Edit Customer'
              : 'Add Customer',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ======================================================
      // BODY
      // ======================================================

      body: SingleChildScrollView(
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
            // HEADER CARD
            // =================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
                    BorderRadius.circular(20),
              ),
              child: Row(
                children: [

                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFE50914),
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Icon(
                      editMode
                          ? Icons.edit_outlined
                          : Icons.person_add_alt_1_rounded,
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
                        Text(
                          editMode
                              ? 'Edit Customer Details'
                              : 'Customer Details',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          editMode
                              ? 'Update customer information'
                              : 'Add a new customer to your database',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // =================================================
            // BASIC INFORMATION
            // =================================================

            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),

            const SizedBox(height: 12),

            inputField(
              label: 'Customer Name *',
              icon: Icons.person_outline_rounded,
              controller: nameController,
            ),

            inputField(
              label: 'Business / Company Name',
              icon: Icons.business_outlined,
              controller: businessController,
            ),

            inputField(
              label: 'Mobile Number *',
              icon: Icons.phone_outlined,
              controller: mobileController,
              keyboardType:
                  TextInputType.phone,
            ),

            inputField(
              label: 'Email Address',
              icon: Icons.email_outlined,
              controller: emailController,
              keyboardType:
                  TextInputType.emailAddress,
            ),

            inputField(
              label: 'Address',
              icon: Icons.location_on_outlined,
              controller: addressController,
              maxLines: 3,
            ),

            const SizedBox(height: 8),

            // =================================================
            // TAX DETAILS
            // =================================================

            const Text(
              'Tax Information',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),

            const SizedBox(height: 12),

            inputField(
              label: 'GSTIN',
              icon: Icons.receipt_long_outlined,
              controller: gstinController,
              textCapitalization: true,
            ),

            inputField(
              label: 'PAN',
              icon: Icons.badge_outlined,
              controller: panController,
              textCapitalization: true,
            ),

            const SizedBox(height: 8),

            // =================================================
            // SAVE / UPDATE BUTTON
            // =================================================

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed:
                    isSaving ? null : saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE50914),
                  foregroundColor:
                      Colors.white,
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
                        width: 21,
                        height: 21,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        editMode
                            ? Icons
                                .save_as_rounded
                            : Icons.save_rounded,
                      ),
                label: Text(
                  isSaving
                      ? editMode
                          ? 'Updating...'
                          : 'Saving...'
                      : editMode
                          ? 'Update Customer'
                          : 'Save Customer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // =================================================
            // REQUIRED FIELD NOTE
            // =================================================

            const Center(
              child: Text(
                '* Required fields',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}