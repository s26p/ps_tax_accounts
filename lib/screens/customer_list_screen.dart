import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'add_customer_screen.dart';
import 'create_invoice_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final DatabaseHelper db = DatabaseHelper.instance;

  List<Map<String, dynamic>> customers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await db.getCustomers();

      if (!mounted) return;

      setState(() {
        customers = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load customers: $e'),
        ),
      );
    }
  }

  Future<void> addCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddCustomerScreen(),
      ),
    );

    if (result == true) {
      await loadCustomers();
    }
  }

  Future<void> editCustomer(
    Map<String, dynamic> customer,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          customer: customer,
        ),
      ),
    );

    if (result == true) {
      await loadCustomers();
    }
  }

  Future<void> confirmDeleteCustomer(
    Map<String, dynamic> customer,
  ) async {
    final name = customer['name']?.toString() ?? 'Customer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Customer?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$name"?\n\n'
            'Customer details, related invoices and payment records '
            'will also be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final customerId = customer['id'];

      await db.deleteCustomer(
        customerId is int
            ? customerId
            : int.parse(customerId.toString()),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Customer deleted successfully',
          ),
        ),
      );

      await loadCustomers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete customer: $e',
          ),
        ),
      );
    }
  }

  Future<void> createInvoice(
    Map<String, dynamic> customer,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoiceScreen(
          customer: customer,
        ),
      ),
    );

    await loadCustomers();
  }

  Widget customerCard(
    Map<String, dynamic> customer,
  ) {
    final customerName =
        customer['name']?.toString().trim().isNotEmpty == true
            ? customer['name'].toString()
            : 'Unknown Customer';

    final businessName =
        customer['business_name']?.toString() ?? '';

    final mobile =
        customer['mobile']?.toString() ?? '';

    final gstin =
        customer['gstin']?.toString() ?? '';

    final pan =
        customer['pan']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      customerName.isNotEmpty
                          ? customerName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111111),
                        ),
                      ),

                      if (businessName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],

                      if (mobile.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 15,
                              color: Colors.black45,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              mobile,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.black54,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      editCustomer(customer);
                    } else if (value == 'delete') {
                      confirmDeleteCustomer(customer);
                    } else if (value == 'invoice') {
                      createInvoice(customer);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'invoice',
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text('Create Invoice'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (gstin.isNotEmpty || pan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (gstin.isNotEmpty)
                      Expanded(
                        child: _infoItem(
                          'GSTIN',
                          gstin,
                        ),
                      ),
                    if (pan.isNotEmpty)
                      Expanded(
                        child: _infoItem(
                          'PAN',
                          pan,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 13),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      editCustomer(customer);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF111111),
                      side: const BorderSide(
                        color: Colors.black12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      createInvoice(customer);
                    },
                    icon: const Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                    ),
                    label: const Text('Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: () {
                    confirmDeleteCustomer(customer);
                  },
                  tooltip: 'Delete',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Colors.red.withValues(alpha: 0.08),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF111111),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),

      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Customers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadCustomers,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE50914),
              ),
            )
          : customers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914)
                                .withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            size: 42,
                            color: Color(0xFFE50914),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'No Customers Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 7),

                        const Text(
                          'Add your first customer to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 22),

                        ElevatedButton.icon(
                          onPressed: addCustomer,
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                          ),
                          label: const Text(
                            'Add Customer',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFE50914),
                  onRefresh: loadCustomers,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      100,
                    ),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      return customerCard(
                        customers[index],
                      );
                    },
                  ),
                ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCustomer,
        backgroundColor: const Color(0xFFE50914),
        foregroundColor: Colors.white,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text(
          'Add Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}