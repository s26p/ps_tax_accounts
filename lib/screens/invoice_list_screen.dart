import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'create_invoice_screen.dart';
import 'invoice_details_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() =>
      _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> filteredInvoices = [];

  final TextEditingController searchController =
      TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadInvoices();

    searchController.addListener(() {
      searchInvoices(searchController.text);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // LOAD INVOICES
  // =====================================================

  Future<void> loadInvoices() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final data = await DatabaseHelper.instance.getInvoices();

      if (!mounted) return;

      setState(() {
        invoices = data;
        filteredInvoices = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load invoices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // SEARCH
  // =====================================================

  void searchInvoices(String query) {
    final search = query.trim().toLowerCase();

    if (search.isEmpty) {
      setState(() {
        filteredInvoices = invoices;
      });
      return;
    }

    final results = invoices.where((invoice) {
      final invoiceNumber =
          (invoice['invoice_number'] ?? '').toString().toLowerCase();

      final service =
          (invoice['service'] ?? '').toString().toLowerCase();

      final gstType =
          (invoice['gst_type'] ?? '').toString().toLowerCase();

      return invoiceNumber.contains(search) ||
          service.contains(search) ||
          gstType.contains(search);
    }).toList();

    setState(() {
      filteredInvoices = results;
    });
  }

  // =====================================================
  // OPEN INVOICE
  // =====================================================

  Future<void> openInvoice(
    Map<String, dynamic> invoice,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailsScreen(
          invoice: invoice,
        ),
      ),
    );

    if (!mounted) return;

    await loadInvoices();
  }

  // =====================================================
  // EDIT INVOICE
  // =====================================================

  Future<void> editInvoice(
    Map<String, dynamic> invoice,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateInvoiceScreen(
          customer: {
            'id': invoice['customer_id'],
            'name': invoice['customer_name'] ?? '',
            'business_name': invoice['business_name'] ?? '',
            'mobile': invoice['mobile'] ?? '',
            'email': invoice['email'] ?? '',
            'address': invoice['address'] ?? '',
            'gstin': invoice['gstin'] ?? '',
            'pan': invoice['pan'] ?? '',
          },
          invoice: invoice,
        ),
      ),
    );

    if (!mounted) return;

    await loadInvoices();
  }

  // =====================================================
  // DELETE INVOICE
  // =====================================================

  Future<void> deleteInvoice(
    Map<String, dynamic> invoice,
  ) async {
    final invoiceId = invoice['id'];

    if (invoiceId == null) {
      return;
    }

    final invoiceNumber =
        (invoice['invoice_number'] ?? '-').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE50914),
              ),
              SizedBox(width: 10),
              Text(
                'Delete Invoice?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete invoice $invoiceNumber?\n\n'
            'This will also delete the invoice items linked to this invoice.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await DatabaseHelper.instance.deleteInvoice(invoiceId);

      if (!mounted) return;

      await loadInvoices();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invoice $invoiceNumber deleted successfully',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete invoice: $e',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =====================================================
  // INVOICE MENU
  // =====================================================

  Future<void> showInvoiceMenu(
    Map<String, dynamic> invoice,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  (invoice['invoice_number'] ?? '-').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                  ),
                ),

                const SizedBox(height: 18),

                // VIEW
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text(
                    'View Invoice',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'View invoice details and PDF',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openInvoice(invoice);
                  },
                ),

                const SizedBox(height: 5),

                // EDIT
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text(
                    'Edit Invoice',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Modify invoice services and amounts',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    editInvoice(invoice);
                  },
                ),

                const SizedBox(height: 5),

                // DELETE
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE50914),
                    ),
                  ),
                  title: const Text(
                    'Delete Invoice',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE50914),
                    ),
                  ),
                  subtitle: const Text(
                    'Permanently delete this invoice',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    deleteInvoice(invoice);
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // FORMAT DATE
  // =====================================================

  String formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(value.toString());

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day-$month-$year';
    } catch (_) {
      return value.toString();
    }
  }

  // =====================================================
  // INVOICE CARD
  // =====================================================

  Widget invoiceCard(
    Map<String, dynamic> invoice,
  ) {
    final invoiceNumber =
        (invoice['invoice_number'] ?? '-').toString();

    final service =
        (invoice['service'] ?? '-').toString();

    final date =
        formatDate(invoice['invoice_date']);

    final gstType =
        (invoice['gst_type'] ?? 'LOCAL').toString();

    final totalValue =
        invoice['total'] ?? 0;

    final total = totalValue is num
        ? totalValue.toDouble()
        : double.tryParse(
              totalValue.toString(),
            ) ??
            0;

    final isInterState =
        gstType == 'INTERSTATE';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openInvoice(invoice),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // INVOICE ICON
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE50914),
                          Color(0xFFB00000),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // INVOICE INFORMATION
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoiceNumber,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Color(0xFF111111),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          service,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Colors.grey.shade700,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color:
                                  Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // TOTAL + MENU
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹ ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Color(0xFFE50914),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 3),

                          // THREE DOT MENU
                          IconButton(
                            tooltip: 'Invoice Options',
                            onPressed: () =>
                                showInvoiceMenu(invoice),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),

              const SizedBox(height: 12),

              // GST TYPE + VIEW
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isInterState
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFE8F5E9),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          isInterState
                              ? Icons.local_shipping_outlined
                              : Icons.home_work_outlined,
                          size: 14,
                          color: isInterState
                              ? Colors.orange.shade800
                              : Colors.green.shade700,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isInterState
                              ? 'IGST'
                              : 'CGST + SGST',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                            color: isInterState
                                ? Colors.orange.shade800
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  TextButton.icon(
                    onPressed: () =>
                        openInvoice(invoice),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFFE50914),
                    ),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'View Invoice',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // EMPTY VIEW
  // =====================================================

  Widget emptyView() {
    final isSearching =
        searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFFFEBEE),
                borderRadius:
                    BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color:
                    Color(0xFFE50914),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              isSearching
                  ? 'No Invoices Found'
                  : 'No Invoices Yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF111111),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isSearching
                  ? 'Try a different invoice number or service.'
                  : 'Create your first invoice to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),

      // APP BAR
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Invoices',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              'PS Tax Consultancy',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadInvoices,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // BODY
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFFE50914),
              ),
            )
          : RefreshIndicator(
              color:
                  const Color(0xFFE50914),
              onRefresh: loadInvoices,
              child: CustomScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // HEADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets.all(
                              18,
                            ),
                            decoration:
                                BoxDecoration(
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Color(0xFF111111),
                                  Color(0xFF292929),
                                ],
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        const Color(
                                      0xFFE50914,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      15,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .receipt_long_rounded,
                                    color:
                                        Colors.white,
                                    size: 27,
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      const Text(
                                        'Invoice Management',
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize:
                                              18,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      Text(
                                        '${invoices.length} invoice${invoices.length == 1 ? '' : 's'} in your database',
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white70,
                                          fontSize:
                                              12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          // SEARCH
                          TextField(
                            controller:
                                searchController,
                            decoration:
                                InputDecoration(
                              hintText:
                                  'Search invoice number or service',

                              prefixIcon:
                                  const Icon(
                                Icons.search_rounded,
                              ),

                              suffixIcon:
                                  searchController
                                          .text
                                          .isNotEmpty
                                      ? IconButton(
                                          onPressed:
                                              () {
                                            searchController
                                                .clear();
                                          },
                                          icon:
                                              const Icon(
                                            Icons
                                                .clear_rounded,
                                          ),
                                        )
                                      : null,

                              filled: true,
                              fillColor:
                                  Colors.white,

                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  15,
                                ),
                                borderSide:
                                    BorderSide(
                                  color: Colors
                                      .grey
                                      .shade200,
                                ),
                              ),

                              enabledBorder:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  15,
                                ),
                                borderSide:
                                    BorderSide(
                                  color: Colors
                                      .grey
                                      .shade200,
                                ),
                              ),

                              focusedBorder:
                                  const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(
                                  Radius.circular(
                                    15,
                                  ),
                                ),
                                borderSide:
                                    BorderSide(
                                  color:
                                      Color(0xFFE50914),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // SECTION TITLE
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              Text(
                                searchController
                                        .text
                                        .isEmpty
                                    ? 'All Invoices'
                                    : 'Search Results',
                                style:
                                    const TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      Color(0xFF111111),
                                ),
                              ),
                              Text(
                                '${filteredInvoices.length}',
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      Color(0xFFE50914),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // LIST
                  if (filteredInvoices.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: emptyView(),
                    )
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        100,
                      ),
                      sliver: SliverList(
                        delegate:
                            SliverChildBuilderDelegate(
                          (context, index) {
                            return invoiceCard(
                              filteredInvoices[
                                  index],
                            );
                          },
                          childCount:
                              filteredInvoices.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}