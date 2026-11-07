import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

const Color _primaryRed = Color(0xFFE50914);
const Color _darkBlack = Color(0xFF111111);
const Color _background = Color(0xFFF6F7F9);
const PdfColor _pdfRed = PdfColor(0.898, 0.035, 0.078);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  bool _isLoading = true;
  bool _isExporting = false;

  String _selectedReport = 'Monthly Billing';

  DateTime _selectedMonth = DateTime.now();

  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _toDate = DateTime.now();

  double _totalBilling = 0;
  double _totalCollected = 0;
  double _totalOutstanding = 0;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  String _money(num value) => '₹${value.toStringAsFixed(2)}';

  String _pdfMoney(num value) => 'Rs. ${value.toStringAsFixed(2)}';

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final parts = text.split(RegExp(r'[-/]'));

    if (parts.length == 3) {
      try {
        if (parts[0].length == 4) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }

        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _date(dynamic value) {
    final parsed = _parseDate(value);
    if (parsed == null) return value?.toString() ?? '-';

    return '${parsed.day.toString().padLeft(2, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.year}';
  }

  String _customerName(dynamic customerId) {
    for (final customer in _customers) {
      if (customer['id'].toString() == customerId.toString()) {
        return (customer['name'] ??
                customer['customer_name'] ??
                'Customer ${customer['id']}')
            .toString();
      }
    }

    return 'Customer $customerId';
  }

  String _customerDisplayName(Map<String, dynamic> customer) {
    final id = customer['id'];

    return (customer['name'] ??
            customer['customer_name'] ??
            'Customer $id')
        .toString();
  }

  String get _monthLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  String get _dateRangeLabel =>
      '${_date(_fromDate)}  to  ${_date(_toDate)}';

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final billing = await _database.getTotalInvoiceAmount();
      final collected = await _database.getTotalPaidAmount();
      final outstanding = await _database.getTotalOutstandingAmount();
      final customers = await _database.getCustomers();
      final payments = await _database.getAllPayments();
      final invoices = await _database.getInvoices();

      if (!mounted) return;

      setState(() {
        _totalBilling = billing;
        _totalCollected = collected;
        _totalOutstanding = outstanding;
        _customers = customers;
        _payments = payments;
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load reports: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _monthlyInvoices {
    return _invoices.where((invoice) {
      final date = _parseDate(invoice['invoice_date']);

      return date != null &&
          date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList();
  }

  List<Map<String, dynamic>> get _rangePayments {
    final from = _dateOnly(_fromDate);
    final to = _dateOnly(_toDate);

    return _payments.where((payment) {
      final date = _parseDate(payment['payment_date']);
      if (date == null) return false;

      final day = _dateOnly(date);
      return !day.isBefore(from) && !day.isAfter(to);
    }).toList();
  }

  Future<void> _chooseMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select any date in the required month',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
  }

  Future<void> _chooseFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select payment report start date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _fromDate = _dateOnly(picked);

      if (_fromDate.isAfter(_toDate)) {
        _toDate = _fromDate;
      }
    });
  }

  Future<void> _chooseToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2100),
      helpText: 'Select payment report end date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _toDate = _dateOnly(picked);
    });
  }

  // CUSTOMER TOTALS

  double _customerBilling(dynamic customerId) {
    return _invoices.where((invoice) {
      return invoice['customer_id'].toString() == customerId.toString();
    }).fold<double>(
      0,
      (sum, invoice) => sum + _number(invoice['total']),
    );
  }

  double _customerPaid(dynamic customerId) {
    return _payments.where((payment) {
      return payment['customer_id'].toString() == customerId.toString();
    }).fold<double>(
      0,
      (sum, payment) => sum + _number(payment['amount']),
    );
  }

  double _customerOutstanding(dynamic customerId) {
    return (_customerBilling(customerId) - _customerPaid(customerId))
        .clamp(0.0, double.infinity);
  }

  // REPORT DATA

  List<String> get _pdfHeaders {
    switch (_selectedReport) {
      case 'Monthly Billing':
        return ['Invoice No.', 'Customer', 'Date', 'Amount'];

      case 'Payment Collection':
        return [
          'Customer',
          'Date',
          'Payment Method',
          'Notes',
          'Amount',
        ];

      case 'Customer-wise':
        return ['Customer', 'Billing', 'Paid', 'Outstanding'];

      case 'Outstanding':
        return ['Customer', 'Outstanding'];

      default:
        return ['Details'];
    }
  }

  List<List<String>> _buildPdfRows() {
    switch (_selectedReport) {
      case 'Monthly Billing':
        return _monthlyInvoices.map((invoice) {
          return [
            (invoice['invoice_number'] ?? 'Invoice').toString(),
            _customerName(invoice['customer_id']),
            _date(invoice['invoice_date']),
            _pdfMoney(_number(invoice['total'])),
          ];
        }).toList();

      case 'Payment Collection':
        return _rangePayments.map((payment) {
          final notes = (payment['notes'] ?? '').toString().trim();

          return [
            _customerName(payment['customer_id']),
            _date(payment['payment_date']),
            (payment['payment_mode'] ?? '-').toString(),
            notes.isEmpty ? '-' : notes,
            _pdfMoney(_number(payment['amount'])),
          ];
        }).toList();

      case 'Customer-wise':
        return _customers.map((customer) {
          final id = customer['id'];

          return [
            _customerDisplayName(customer),
            _pdfMoney(_customerBilling(id)),
            _pdfMoney(_customerPaid(id)),
            _pdfMoney(_customerOutstanding(id)),
          ];
        }).toList();

      case 'Outstanding':
        final rows = <Map<String, dynamic>>[];

        for (final customer in _customers) {
          final outstanding = _customerOutstanding(customer['id']);

          if (outstanding > 0.009) {
            rows.add({
              'name': _customerDisplayName(customer),
              'outstanding': outstanding,
            });
          }
        }

        rows.sort(
          (a, b) => (b['outstanding'] as double)
              .compareTo(a['outstanding'] as double),
        );

        return rows.map((row) {
          return [
            row['name'].toString(),
            _pdfMoney(row['outstanding'] as double),
          ];
        }).toList();

      default:
        return [];
    }
  }

  double get _selectedReportTotal {
    switch (_selectedReport) {
      case 'Monthly Billing':
        return _monthlyInvoices.fold<double>(
          0,
          (sum, invoice) => sum + _number(invoice['total']),
        );

      case 'Payment Collection':
        return _rangePayments.fold<double>(
          0,
          (sum, payment) => sum + _number(payment['amount']),
        );

      case 'Customer-wise':
        return _customers.fold<double>(
          0,
          (sum, customer) => sum + _customerBilling(customer['id']),
        );

      case 'Outstanding':
        return _customers.fold<double>(
          0,
          (sum, customer) => sum + _customerOutstanding(customer['id']),
        );

      default:
        return 0;
    }
  }

  String get _pdfPeriod {
    switch (_selectedReport) {
      case 'Monthly Billing':
        return _monthLabel;

      case 'Payment Collection':
        return _dateRangeLabel;

      default:
        return 'All available records';
    }
  }

  String _makeFileName() {
    final report = _selectedReport
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');

    return 'PS_Tax_${report}_$timestamp.pdf';
  }

  // CREATE PDF

  Future<Uint8List> _generatePdfBytes() async {
    final pdf = pw.Document();

    final headers = _pdfHeaders;
    final rows = _buildPdfRows();

    if (rows.isEmpty) {
      rows.add(List<String>.filled(headers.length, ''));
      rows[0][0] = 'No records found';
    }

    final reportTotal = _selectedReportTotal;
    final reportName = _selectedReport;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: reportName == 'Payment Collection'
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pdfContext) {
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: _pdfRed,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PS TAX CONSULTANCY',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'GST  |  INCOME TAX  |  ACCOUNTS',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              reportName,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _pdfRed,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Period: $_pdfPeriod',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Generated: ${_date(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _pdfRed),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Report Total',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.Text(
                    _pdfMoney(reportTotal),
                    style: pw.TextStyle(
                      color: _pdfRed,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: _pdfRed,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              'This report is generated from the records '
              'currently available in PS Tax Consultancy.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // SAVE PDF

  Future<void> _savePdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      final bytes = await _generatePdfBytes();
      final fileName = _makeFileName();

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save PS Tax Consultancy Report',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (!mounted) return;

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF save cancelled.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF save completed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save PDF: $e'),
          backgroundColor: _primaryRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // SHARE PDF - ANDROID SHARE MENU / WHATSAPP

  Future<void> _sharePdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    Directory? temporaryDirectory;

    try {
      final bytes = await _generatePdfBytes();
      final fileName = _makeFileName();

      temporaryDirectory = await Directory.systemTemp.createTemp(
        'pstc_report_',
      );

      final file = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}$fileName',
      );

      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          title: 'PS Tax Consultancy - $_selectedReport',
          text: 'PS Tax Consultancy Report\n'
              'Report: $_selectedReport\n'
              'Period: $_pdfPeriod',
          files: [
            XFile(file.path, mimeType: 'application/pdf'),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share PDF: $e'),
            backgroundColor: _primaryRed,
          ),
        );
      }
    } finally {
      if (temporaryDirectory != null) {
        try {
          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        } catch (_) {
          // Ignore temporary-file cleanup errors.
        }
      }

      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // PDF PREVIEW / PRINT

  Future<void> _exportPdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      final bytes = await _generatePdfBytes();
      final fileName = _makeFileName();

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: _primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // SUMMARY CARD

  Widget _summaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _money(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MONTHLY BILLING UI

  Widget _buildMonthlyBilling() {
    final invoices = _monthlyInvoices;

    final total = invoices.fold<double>(
      0,
      (sum, invoice) => sum + _number(invoice['total']),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          'Monthly Billing',
          total,
          Icons.receipt_long,
          _primaryRed,
        ),
        const SizedBox(height: 12),
        Text(
          'Invoices: ${invoices.length}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (invoices.isEmpty)
          const _EmptyReport(
            message: 'No invoices in this month.',
          )
        else
          ...invoices.map((invoice) {
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: _primaryRed,
                ),
                title: Text(
                  (invoice['invoice_number'] ?? 'Invoice').toString(),
                ),
                subtitle: Text(
                  '${_customerName(invoice['customer_id'])}\n'
                  '${_date(invoice['invoice_date'])}',
                ),
                isThreeLine: true,
                trailing: Text(
                  _money(_number(invoice['total'])),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  // PAYMENT COLLECTION UI

  Widget _buildPaymentReport() {
    final payments = _rangePayments;

    final total = payments.fold<double>(
      0,
      (sum, payment) => sum + _number(payment['amount']),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          'Payments Received',
          total,
          Icons.payments_outlined,
          Colors.green,
        ),
        const SizedBox(height: 12),
        Text(
          'Payment Records: ${payments.length}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (payments.isEmpty)
          const _EmptyReport(
            message: 'No payments found in the selected date range.',
          )
        else
          ...payments.map((payment) {
            final notes = (payment['notes'] ?? '').toString().trim();
            final method =
                (payment['payment_mode'] ?? '-').toString();

            return Card(
              color: Colors.white,
              child: ListTile(
                isThreeLine: true,
                leading: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.green,
                ),
                title: Text(
                  _customerName(payment['customer_id']),
                ),
                subtitle: Text(
                  '${_date(payment['payment_date'])}\n'
                  'Method: $method'
                  '${notes.isNotEmpty ? '\nNotes: $notes' : ''}',
                ),
                trailing: Text(
                  _money(_number(payment['amount'])),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  // CUSTOMER-WISE UI

  Widget _buildCustomerReport() {
    if (_customers.isEmpty) {
      return const _EmptyReport(
        message: 'No customers found.',
      );
    }

    return Column(
      children: _customers.map((customer) {
        final id = customer['id'];
        final invoiced = _customerBilling(id);
        final paid = _customerPaid(id);
        final outstanding = _customerOutstanding(id);

        return Card(
          color: Colors.white,
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person_outline),
            ),
            title: Text(_customerDisplayName(customer)),
            subtitle: Text(
              'Billing: ${_money(invoiced)}\n'
              'Paid: ${_money(paid)}\n'
              'Outstanding: ${_money(outstanding)}',
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }

  // OUTSTANDING UI

  Widget _buildOutstandingReport() {
    final rows = <Map<String, dynamic>>[];

    for (final customer in _customers) {
      final outstanding = _customerOutstanding(customer['id']);

      if (outstanding > 0.009) {
        rows.add({
          'name': _customerDisplayName(customer),
          'outstanding': outstanding,
        });
      }
    }

    rows.sort(
      (a, b) => (b['outstanding'] as double)
          .compareTo(a['outstanding'] as double),
    );

    final total = rows.fold<double>(
      0,
      (sum, row) => sum + (row['outstanding'] as double),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          'Total Outstanding',
          total,
          Icons.pending_actions,
          _primaryRed,
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyReport(
            message: 'No outstanding customers.',
          )
        else
          ...rows.map((row) {
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: _primaryRed,
                ),
                title: Text(row['name'] as String),
                trailing: Text(
                  _money(row['outstanding'] as double),
                  style: const TextStyle(
                    color: _primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSelectedReport() {
    switch (_selectedReport) {
      case 'Monthly Billing':
        return _buildMonthlyBilling();

      case 'Payment Collection':
        return _buildPaymentReport();

      case 'Customer-wise':
        return _buildCustomerReport();

      case 'Outstanding':
        return _buildOutstandingReport();

      default:
        return const SizedBox.shrink();
    }
  }

  // MAIN SCREEN

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _darkBlack,
        foregroundColor: Colors.white,
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh Reports',
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(
                    'Total Billing',
                    _totalBilling,
                    Icons.receipt_long,
                    _primaryRed,
                  ),
                  _summaryCard(
                    'Total Collected',
                    _totalCollected,
                    Icons.payments,
                    Colors.green,
                  ),
                  _summaryCard(
                    'Outstanding',
                    _totalOutstanding,
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Report',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedReport,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Report Type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Monthly Billing',
                                child: Text('Monthly Billing'),
                              ),
                              DropdownMenuItem(
                                value: 'Payment Collection',
                                child: Text('Payment Collection'),
                              ),
                              DropdownMenuItem(
                                value: 'Customer-wise',
                                child: Text('Customer-wise'),
                              ),
                              DropdownMenuItem(
                                value: 'Outstanding',
                                child: Text('Outstanding'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedReport = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          if (_selectedReport == 'Monthly Billing')
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _chooseMonth,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(_monthLabel),
                              ),
                            ),

                          if (_selectedReport == 'Payment Collection') ...[
                            const Text(
                              'Payment Date Range',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _chooseFromDate,
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      'From\n${_date(_fromDate)}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _chooseToDate,
                                    icon: const Icon(Icons.event),
                                    label: Text(
                                      'To\n${_date(_toDate)}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Selected: $_dateRangeLabel',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _savePdf,
                              icon: const Icon(Icons.save_alt),
                              label: const Text('Save PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _darkBlack,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _sharePdf,
                              icon: const Icon(Icons.share),
                              label: const Text('Share PDF / WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isExporting ? null : _exportPdf,
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.print),
                              label: Text(
                                _isExporting
                                    ? 'Preparing PDF...'
                                    : 'Preview PDF / Print',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSelectedReport(),
                  const SizedBox(height: 24),
                  const Text(
                    'Note: Reports use the current invoice and '
                    'payment records. Payment Collection uses the '
                    'selected date range.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final String message;

  const _EmptyReport({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
