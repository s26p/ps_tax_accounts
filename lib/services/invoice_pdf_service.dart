import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

class InvoicePdfService {
  // ============================================================
  // COLORS
  // ============================================================

  static const PdfColor black = PdfColor.fromInt(0xFF111827);

  static const PdfColor red = PdfColor.fromInt(0xFFB91C1C);

  static const PdfColor darkRed = PdfColor.fromInt(0xFF991B1B);

  static const PdfColor darkGrey = PdfColor.fromInt(0xFF374151);

  static const PdfColor grey = PdfColor.fromInt(0xFF6B7280);

  static const PdfColor lightGrey = PdfColor.fromInt(0xFFD1D5DB);

  static const PdfColor veryLightGrey = PdfColor.fromInt(0xFFF3F4F6);

  static const PdfColor paleRed = PdfColor.fromInt(0xFFFEF2F2);

  static const PdfColor white = PdfColors.white;

  // ============================================================
  // CREATE PDF
  // ============================================================

  static Future<Uint8List> createPdf(
    Map<String, dynamic> invoice,
    Map<String, dynamic> customer,
  ) async {
    final pdf = pw.Document();

    final preferences = await SharedPreferences.getInstance();

    // ==========================================================
    // PDF DESIGN SETTINGS
    // ==========================================================

    final showLogo = preferences.getBool('invoice_pdf_show_logo') ?? true;

    final showBusinessDetails =
        preferences.getBool('invoice_pdf_show_business_details') ?? true;

    final showGstDetails =
        preferences.getBool('invoice_pdf_show_gst_details') ?? true;

    final showBankDetails =
        preferences.getBool('invoice_pdf_show_bank_details') ?? true;

    final showSignature =
        preferences.getBool('invoice_pdf_show_signature') ?? true;

    // Load the authorized signatory signature image.
    pw.MemoryImage? signatureImage;
    if (showSignature) {
      try {
        final signatureData =
            await rootBundle.load('assets/images/signature.png');
        signatureImage = pw.MemoryImage(
          signatureData.buffer.asUint8List(),
        );
      } catch (_) {
        signatureImage = null;
      }
    }

    final showFooter = preferences.getBool('invoice_pdf_show_footer') ?? true;

    final customFooter = safeText(
      preferences.getString('invoice_pdf_footer_text'),
      fallback: 'Thank you for your business.',
    );

    // ==========================================================
    // BUSINESS PROFILE
    // ==========================================================

    final businessName = safeText(
      preferences.getString('business_name'),
      fallback: 'PS TAX CONSULTANCY',
    );

    final ownerName = safeText(preferences.getString('owner_name'));

    final businessMobile = safeText(preferences.getString('business_mobile'));

    final businessWhatsapp = safeText(
      preferences.getString('business_whatsapp'),
    );

    final businessEmail = safeText(
      preferences.getString('business_email'),
      fallback: 'pstaxconsultancyoffice@gmail.com',
    );

    final businessAddress = safeText(preferences.getString('business_address'));

    final businessGstin = safeText(preferences.getString('business_gstin'));

    final businessPan = safeText(preferences.getString('business_pan'));

    final businessLlpin = safeText(preferences.getString('business_llpin'));

    final businessWebsite = safeText(preferences.getString('business_website'));

    final businessTagline = safeText(
      preferences.getString('business_tagline'),
      fallback: 'GST • INCOME TAX • ACCOUNTS',
    );

    // ==========================================================
    // BANK DETAILS
    // ==========================================================

    final bankName = safeText(preferences.getString('bank_name'));

    final bankAccountHolder = safeText(
      preferences.getString('bank_account_holder'),
    );

    final savedBankAccountNumber = safeText(
      preferences.getString('bank_account_number'),
    );
    final accountNumber = savedBankAccountNumber.isNotEmpty
        ? savedBankAccountNumber
        : safeText(preferences.getString('account_number'));

    final savedBankIfsc = safeText(preferences.getString('bank_ifsc'));
    final ifscCode = savedBankIfsc.isNotEmpty
        ? savedBankIfsc
        : safeText(preferences.getString('ifsc_code'));

    final bankBranch = safeText(preferences.getString('bank_branch'));

    final swiftCode = safeText(preferences.getString('swift_code'));

    final savedBankUpi = safeText(preferences.getString('bank_upi'));
    final upiId = savedBankUpi.isNotEmpty
        ? savedBankUpi
        : safeText(preferences.getString('upi_id'));

    // ==========================================================
    // LOGO
    // ==========================================================

    pw.MemoryImage? logoImage;

    if (showLogo) {
      try {
        final logoData = await rootBundle.load('assets/images/logo.png');

        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }
    }

    // ==========================================================
    // FONTS
    // ==========================================================

    final regularFontData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );

    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSans-Bold.ttf',
    );

    final regularFont = pw.Font.ttf(regularFontData);

    final boldFont = pw.Font.ttf(boldFontData);

    // ==========================================================
    // INVOICE INFORMATION
    // ==========================================================

    final invoiceNumber = firstNonEmpty([
      invoice['invoice_number'],
      invoice['invoice_no'],
    ], fallback: '-');

    final invoiceDate = formatDate(invoice['invoice_date']);

    final dueDate = firstNonEmpty([
      invoice['due_date'],
      invoice['payment_due_date'],
    ]);

    final paymentTerms = firstNonEmpty([
      invoice['payment_terms'],
      invoice['terms'],
    ], fallback: dueDate.isNotEmpty ? 'Due $dueDate' : 'As per agreed terms');

    final placeOfSupply = firstNonEmpty([invoice['place_of_supply']]);

    final clientPoNumber = firstNonEmpty([
      invoice['client_po_number'],
      invoice['po_number'],
      invoice['purchase_order_number'],
    ]);

    // ==========================================================
    // CUSTOMER INFORMATION
    // ==========================================================

    final customerName = firstNonEmpty([
      invoice['customer_name'],
      customer['name'],
    ], fallback: '-');

    final customerBusinessName = firstNonEmpty([
      invoice['customer_business_name'],
      customer['business_name'],
    ]);

    final customerAddress = firstNonEmpty([
      invoice['customer_address'],
      customer['address'],
    ]);

    final customerMobile = firstNonEmpty([
      invoice['customer_mobile'],
      customer['mobile'],
    ]);

    final customerEmail = firstNonEmpty([
      invoice['customer_email'],
      customer['email'],
    ]);

    final customerGstin = firstNonEmpty([
      invoice['customer_gstin'],
      customer['gstin'],
    ]);

    final customerPan = firstNonEmpty([
      invoice['customer_pan'],
      customer['pan'],
    ]);

    final billingContact = firstNonEmpty([
      invoice['billing_contact'],
      invoice['kind_attention'],
      invoice['kind_attn'],
    ]);

    // ==========================================================
    // ENGAGEMENT INFORMATION
    // ==========================================================

    final engagementTitle = firstNonEmpty([
      invoice['engagement_title'],
      invoice['engagement_type'],
    ]);

    final masterAgreement = firstNonEmpty([
      invoice['master_agreement'],
      invoice['agreement_reference'],
    ]);

    final serviceScope = firstNonEmpty([invoice['service_scope']]);

    final engagementPartner = firstNonEmpty([
      invoice['engagement_partner'],
      invoice['consultant_assigned'],
    ]);

    final billingCycle = firstNonEmpty([
      invoice['billing_cycle'],
      invoice['service_period'],
    ]);

    final engagementReference = firstNonEmpty([
      invoice['engagement_reference'],
      invoice['contract_reference'],
    ]);

    final hasEngagementInformation =
        engagementTitle.isNotEmpty ||
        masterAgreement.isNotEmpty ||
        serviceScope.isNotEmpty ||
        engagementPartner.isNotEmpty ||
        billingCycle.isNotEmpty ||
        engagementReference.isNotEmpty;

    // ==========================================================
    // AMOUNTS
    // ==========================================================

    final quantity = toDouble(invoice['quantity']);

    final rate = toDouble(invoice['rate']);

    final subtotal = toDouble(invoice['subtotal']);

    final cgst = toDouble(invoice['cgst']);

    final sgst = toDouble(invoice['sgst']);

    final igst = toDouble(invoice['igst']);

    final total = toDouble(invoice['total']);

    final gstPercent = toDouble(invoice['gst_percent']);

    final gstType = safeText(
      invoice['gst_type'],
      fallback: 'NO_GST',
    ).toUpperCase();

    // ==========================================================
    // SERVICE / ITEMS
    // ==========================================================

    final List<Map<String, dynamic>> items = [];

    final invoiceId = _invoiceId(invoice);

    if (invoiceId != null && invoiceId > 0) {
      try {
        final databaseItems = await DatabaseHelper.instance.getInvoiceItems(
          invoiceId,
        );

        for (final item in databaseItems) {
          items.add(Map<String, dynamic>.from(item));
        }
      } catch (_) {
        // Continue with fallback.
      }
    }

    if (items.isEmpty) {
      final rawItems = invoice['items'];

      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }

    if (items.isEmpty) {
      items.add({
        'service': firstNonEmpty([
          invoice['service'],
        ], fallback: 'Professional Tax & Compliance Services'),
        'description': firstNonEmpty([
          invoice['service_description'],
          invoice['description'],
        ]),
        'sac_code': firstNonEmpty([invoice['sac_code'], invoice['sac']]),
        'quantity': quantity,
        'unit': firstNonEmpty([
          invoice['unit'],
        ], fallback: formatQuantity(quantity)),
        'rate': rate,
        'amount': subtotal,
      });
    }

    // ==========================================================
    // TOTAL IN WORDS
    // ==========================================================

    final amountInWords = amountToWords(total.round());

    // ==========================================================
    // PDF PAGE
    // ==========================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 25),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),

        // ======================================================
        // HEADER
        // ======================================================
        header: (context) {
          return _buildHeader(
            showLogo: showLogo,
            showBusinessDetails: showBusinessDetails,
            showGstDetails: showGstDetails,
            logoImage: logoImage,
            businessName: businessName,
            ownerName: ownerName,
            businessAddress: businessAddress,
            businessMobile: businessMobile,
            businessWhatsapp: businessWhatsapp,
            businessEmail: businessEmail,
            businessGstin: businessGstin,
            businessPan: businessPan,
            businessLlpin: businessLlpin,
            businessWebsite: businessWebsite,
            businessTagline: businessTagline,
            invoiceNumber: invoiceNumber,
            invoiceDate: invoiceDate,
            paymentTerms: paymentTerms,
            clientPoNumber: clientPoNumber,
            placeOfSupply: placeOfSupply,
            boldFont: boldFont,
            regularFont: regularFont,
          );
        },

        // ======================================================
        // FOOTER
        // ======================================================
        footer: (context) {
          if (!showFooter) {
            return pw.SizedBox(height: 1);
          }

          return _buildFooter(
            footerText: customFooter,
            regularFont: regularFont,
            boldFont: boldFont,
            pageNumber: context.pageNumber,
            totalPages: context.pagesCount,
          );
        },

        // ======================================================
        // BODY
        // ======================================================
        build: (context) {
          final List<pw.Widget> content = [];

          content.add(pw.SizedBox(height: 8));

          // ----------------------------------------------------
          // BILLED TO + ENGAGEMENT
          // ----------------------------------------------------

          content.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildBilledToBox(
                    customerName: customerName,
                    customerBusinessName: customerBusinessName,
                    customerAddress: customerAddress,
                    customerGstin: customerGstin,
                    customerPan: customerPan,
                    customerMobile: customerMobile,
                    customerEmail: customerEmail,
                    billingContact: billingContact,
                    showGstDetails: showGstDetails,
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),
                ),
                if (hasEngagementInformation) pw.SizedBox(width: 12),
                if (hasEngagementInformation)
                  pw.Expanded(
                    child: _buildEngagementBox(
                      engagementTitle: engagementTitle,
                      masterAgreement: masterAgreement,
                      serviceScope: serviceScope,
                      engagementPartner: engagementPartner,
                      billingCycle: billingCycle,
                      engagementReference: engagementReference,
                      boldFont: boldFont,
                      regularFont: regularFont,
                    ),
                  ),
              ],
            ),
          );

          content.add(pw.SizedBox(height: 12));

          // ----------------------------------------------------
          // SERVICE TABLE
          // ----------------------------------------------------

          content.add(
            _buildServiceTable(
              items: items,
              boldFont: boldFont,
              regularFont: regularFont,
            ),
          );

          content.add(pw.SizedBox(height: 8));

          // ----------------------------------------------------
          // TOTAL IN WORDS
          // ----------------------------------------------------

          content.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              decoration: const pw.BoxDecoration(
                color: paleRed,
                border: pw.Border(left: pw.BorderSide(color: red, width: 3)),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Total Invoice Value (in words): ',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 7.2,
                        color: darkRed,
                      ),
                    ),
                    pw.TextSpan(
                      text: 'Indian Rupees $amountInWords Only.',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 7.2,
                        color: darkGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          content.add(pw.SizedBox(height: 9));

          // ----------------------------------------------------
          // BANK + TAX SUMMARY
          // ----------------------------------------------------

          if (showBankDetails) {
            content.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: _buildBankDetails(
                      businessName: businessName,
                      accountTitle: bankAccountHolder,
                      bankName: bankName,
                      accountNumber: accountNumber,
                      ifscCode: ifscCode,
                      bankBranch: bankBranch,
                      swiftCode: swiftCode,
                      upiId: upiId,
                      boldFont: boldFont,
                      regularFont: regularFont,
                    ),
                  ),
                  pw.SizedBox(width: 18),
                  pw.Expanded(
                    flex: 4,
                    child: _buildTaxSummary(
                      showGstDetails: showGstDetails,
                      subtotal: subtotal,
                      cgst: cgst,
                      sgst: sgst,
                      igst: igst,
                      gstPercent: gstPercent,
                      total: total,
                      gstType: gstType,
                      boldFont: boldFont,
                      regularFont: regularFont,
                    ),
                  ),
                ],
              ),
            );
          } else {
            content.add(
              _buildTaxSummary(
                showGstDetails: showGstDetails,
                subtotal: subtotal,
                cgst: cgst,
                sgst: sgst,
                igst: igst,
                gstPercent: gstPercent,
                total: total,
                gstType: gstType,
                boldFont: boldFont,
                regularFont: regularFont,
              ),
            );
          }

          content.add(pw.SizedBox(height: 10));

          // ----------------------------------------------------
          // TERMS
          // ----------------------------------------------------

          final includeTermsInInvoice =
              preferences.getBool('invoice_include_terms_conditions') ?? true;

          if (includeTermsInInvoice) {
            final savedTerms =
                preferences.getStringList('invoice_terms_conditions') ??
                <String>[];

            final invoiceForTerms = Map<String, dynamic>.from(invoice);

            if (savedTerms.isNotEmpty) {
              invoiceForTerms['terms_conditions'] = savedTerms;
            }

            final terms = _getTerms(
              invoiceForTerms,
              invoiceNumber,
              businessEmail,
            );

            content.add(
              _buildTerms(
                terms: terms,
                boldFont: boldFont,
                regularFont: regularFont,
              ),
            );
          }

          // ----------------------------------------------------
          // SIGNATURE
          // ----------------------------------------------------

          if (showSignature) {
            content.add(pw.SizedBox(height: 10));

            content.add(
              _buildSignature(
                businessName: businessName,
                ownerName: ownerName,
                signatureImage: signatureImage,
                boldFont: boldFont,
                regularFont: regularFont,
              ),
            );
          }

          return content;
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // INVOICE ID
  // ============================================================

  static int? _invoiceId(Map<String, dynamic> invoice) {
    final value = invoice['id'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(safeText(value));
  }

  // ============================================================
  // HEADER
  // ============================================================

  static pw.Widget _buildHeader({
    required bool showLogo,
    required bool showBusinessDetails,
    required bool showGstDetails,
    required pw.MemoryImage? logoImage,
    required String businessName,
    required String ownerName,
    required String businessAddress,
    required String businessMobile,
    required String businessWhatsapp,
    required String businessEmail,
    required String businessGstin,
    required String businessPan,
    required String businessLlpin,
    required String businessWebsite,
    required String businessTagline,
    required String invoiceNumber,
    required String invoiceDate,
    required String paymentTerms,
    required String clientPoNumber,
    required String placeOfSupply,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final contactLine = _contactText(
      mobile: businessMobile,
      whatsapp: businessWhatsapp,
    );

    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Expanded(child: pw.Container(height: 3, color: black)),
            pw.Container(width: 95, height: 3, color: red),
          ],
        ),
        pw.SizedBox(height: 7),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 7,
              child: _buildBusinessHeaderArea(
                showLogo: showLogo,
                showBusinessDetails: showBusinessDetails,
                showGstDetails: showGstDetails,
                logoImage: logoImage,
                businessName: businessName,
                ownerName: ownerName,
                businessAddress: businessAddress,
                businessEmail: businessEmail,
                businessMobile: contactLine,
                businessGstin: businessGstin,
                businessPan: businessPan,
                businessLlpin: businessLlpin,
                businessWebsite: businessWebsite,
                businessTagline: businessTagline,
                boldFont: boldFont,
                regularFont: regularFont,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 4,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: black,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 9,
                        color: white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  _headerMetaLine(
                    'Invoice Number',
                    invoiceNumber,
                    boldFont,
                    regularFont,
                  ),
                  _headerMetaLine(
                    'Invoice Date',
                    invoiceDate,
                    boldFont,
                    regularFont,
                  ),
                  _headerMetaLine(
                    'Payment Terms',
                    paymentTerms,
                    boldFont,
                    regularFont,
                  ),
                  if (clientPoNumber.isNotEmpty)
                    _headerMetaLine(
                      'Client PO Number',
                      clientPoNumber,
                      boldFont,
                      regularFont,
                    ),
                  if (placeOfSupply.isNotEmpty)
                    _headerMetaLine(
                      'Place of Supply',
                      placeOfSupply,
                      boldFont,
                      regularFont,
                    ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 1.2, color: black),
      ],
    );
  }

  // ============================================================
  // BUSINESS HEADER AREA
  // ============================================================

  static pw.Widget _buildBusinessHeaderArea({
    required bool showLogo,
    required bool showBusinessDetails,
    required bool showGstDetails,
    required pw.MemoryImage? logoImage,
    required String businessName,
    required String ownerName,
    required String businessAddress,
    required String businessEmail,
    required String businessMobile,
    required String businessGstin,
    required String businessPan,
    required String businessLlpin,
    required String businessWebsite,
    required String businessTagline,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final registration = _registrationLine(
      llpin: businessLlpin,
      gstin: businessGstin,
      pan: businessPan,
    );

    final contact = _headerContactLine(
      email: businessEmail,
      contact: businessMobile,
      website: businessWebsite,
    );

    // ----------------------------------------------------------
    // LOGO WIDGET
    // ----------------------------------------------------------

    final pw.Widget logo = showLogo && logoImage != null
        ? pw.Container(
            width: 58,
            height: 58,
            margin: const pw.EdgeInsets.only(right: 10),
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          )
        : pw.SizedBox(width: 0, height: 0);

    // ----------------------------------------------------------
    // BUSINESS DETAILS OFF
    // ----------------------------------------------------------

    if (!showBusinessDetails) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (showLogo && logoImage != null) logo,
          pw.Text(
            businessName.isNotEmpty
                ? businessName.toUpperCase()
                : 'PS TAX CONSULTANCY',
            style: pw.TextStyle(font: boldFont, fontSize: 14, color: black),
          ),
        ],
      );
    }

    // ----------------------------------------------------------
    // BUSINESS DETAILS ON
    // ----------------------------------------------------------

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (showLogo && logoImage != null) logo,
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: _businessNameSpans(businessName, boldFont),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                businessTagline,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 6.2,
                  color: red,
                  letterSpacing: 0.35,
                ),
              ),
              if (ownerName.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    ownerName,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 6.2,
                      color: darkGrey,
                    ),
                  ),
                ),
              if (businessAddress.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    businessAddress,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 6.1,
                      color: darkGrey,
                    ),
                  ),
                ),
              if (showGstDetails && registration.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    registration,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 6.1,
                      color: darkGrey,
                    ),
                  ),
                ),
              if (contact.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    contact,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 6.1,
                      color: darkGrey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUSINESS NAME
  // ============================================================

  static List<pw.TextSpan> _businessNameSpans(String name, pw.Font boldFont) {
    final upper = name.toUpperCase();

    final index = upper.indexOf('CONSULTANCY');

    if (index > 0) {
      final first = upper.substring(0, index);

      final second = upper.substring(index);

      return [
        pw.TextSpan(
          text: first,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 17,
            color: black,
            letterSpacing: 0.2,
          ),
        ),
        pw.TextSpan(
          text: second,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 17,
            color: red,
            letterSpacing: 0.2,
          ),
        ),
      ];
    }

    return [
      pw.TextSpan(
        text: upper,
        style: pw.TextStyle(font: boldFont, fontSize: 17, color: black),
      ),
    ];
  }

  // ============================================================
  // HEADER META LINE
  // ============================================================

  static pw.Widget _headerMetaLine(
    String title,
    String value,
    pw.Font boldFont,
    pw.Font regularFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text(
              '$title:',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 5.8,
                color: grey,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 5.9,
                color: darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BILLED TO BOX
  // ============================================================

  static pw.Widget _buildBilledToBox({
    required String customerName,
    required String customerBusinessName,
    required String customerAddress,
    required String customerGstin,
    required String customerPan,
    required String customerMobile,
    required String customerEmail,
    required String billingContact,
    required bool showGstDetails,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final displayName = customerBusinessName.isNotEmpty
        ? customerBusinessName
        : customerName;

    final customerRegistration = _customerRegistrationLine(
      gstin: customerGstin,
      pan: customerPan,
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(
        color: veryLightGrey,
        border: pw.Border.all(color: lightGrey, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BILLED TO (CLIENT ENTERPRISE)',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 7,
              color: red,
              letterSpacing: 0.35,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            displayName,
            style: pw.TextStyle(font: boldFont, fontSize: 8.2, color: black),
          ),
          if (customerBusinessName.isNotEmpty &&
              customerName.isNotEmpty &&
              customerName != customerBusinessName)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                customerName,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 6.5,
                  color: darkGrey,
                ),
              ),
            ),
          if (customerAddress.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                customerAddress,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 6.3,
                  color: darkGrey,
                ),
              ),
            ),
          if (showGstDetails && customerRegistration.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                customerRegistration,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 6.2,
                  color: darkGrey,
                ),
              ),
            ),
          if (billingContact.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                'Kind Attn: $billingContact',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 6.2,
                  color: darkGrey,
                ),
              ),
            ),
          if (customerMobile.isNotEmpty || customerEmail.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                _customerContactLine(
                  mobile: customerMobile,
                  email: customerEmail,
                ),
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 6.1,
                  color: grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ENGAGEMENT BOX
  // ============================================================

  static pw.Widget _buildEngagementBox({
    required String engagementTitle,
    required String masterAgreement,
    required String serviceScope,
    required String engagementPartner,
    required String billingCycle,
    required String engagementReference,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(
        color: veryLightGrey,
        border: pw.Border.all(color: lightGrey, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ENGAGEMENT & CONTRACT REFERENCE',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 7,
              color: red,
              letterSpacing: 0.3,
            ),
          ),
          pw.SizedBox(height: 6),
          if (engagementTitle.isNotEmpty)
            _engagementLine(
              'Engagement',
              engagementTitle,
              boldFont,
              regularFont,
            ),
          if (masterAgreement.isNotEmpty)
            _engagementLine(
              'Master Agreement',
              masterAgreement,
              boldFont,
              regularFont,
            ),
          if (serviceScope.isNotEmpty)
            _engagementLine(
              'Service Scope',
              serviceScope,
              boldFont,
              regularFont,
            ),
          if (engagementPartner.isNotEmpty)
            _engagementLine(
              'Engagement Partner',
              engagementPartner,
              boldFont,
              regularFont,
            ),
          if (billingCycle.isNotEmpty)
            _engagementLine(
              'Billing Cycle',
              billingCycle,
              boldFont,
              regularFont,
            ),
          if (engagementReference.isNotEmpty)
            _engagementLine(
              'Reference',
              engagementReference,
              boldFont,
              regularFont,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ENGAGEMENT LINE
  // ============================================================

  static pw.Widget _engagementLine(
    String title,
    String value,
    pw.Font boldFont,
    pw.Font regularFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$title: ',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 6.1,
                color: darkGrey,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 6.1,
                color: darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SERVICE TABLE
  // ============================================================

  static pw.Widget _buildServiceTable({
    required List<Map<String, dynamic>> items,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: black),
        children: [
          _tableHeader(
            'S.NO',
            boldFont,
            alignment: pw.Alignment.center,
            width: 25,
          ),
          _tableHeader(
            'SERVICE DESCRIPTION & DELIVERABLES',
            boldFont,
            alignment: pw.Alignment.center,
          ),
          _tableHeader(
            'SAC\nCODE',
            boldFont,
            alignment: pw.Alignment.center,
            width: 48,
          ),
          _tableHeader(
            'QTY',
            boldFont,
            alignment: pw.Alignment.center,
            width: 60,
          ),
          _tableHeader(
            'UNIT RATE\n(₹)',
            boldFont,
            alignment: pw.Alignment.center,
            width: 65,
          ),
          _tableHeader(
            'TAXABLE AMT\n(₹)',
            boldFont,
            alignment: pw.Alignment.center,
            width: 75,
          ),
        ],
      ),
    );

    for (int index = 0; index < items.length; index++) {
      final item = items[index];

      final service = firstNonEmpty([
        item['service'],
        item['name'],
        item['description'],
      ], fallback: '-');

      final description = firstNonEmpty([
        item['description'],
        item['deliverables'],
        item['details'],
      ]);

      final sacCode = firstNonEmpty([
        item['sac_code'],
        item['sac'],
        item['sacCode'],
      ]);

      final itemQuantity = toDouble(item['quantity']);

      final itemRate = toDouble(item['rate']);

      final directAmount = toDouble(item['amount']);

      final itemAmount = directAmount != 0
          ? directAmount
          : toDouble(item['subtotal']);

      rows.add(
        pw.TableRow(
          children: [
            _tableCell(
              (index + 1).toString().padLeft(2, '0'),
              regularFont,
              alignment: pw.Alignment.center,
            ),
            _serviceDescriptionCell(
              service: service,
              description: description,
              boldFont: boldFont,
              regularFont: regularFont,
            ),
            _tableCell(sacCode, regularFont, alignment: pw.Alignment.center),
            _tableCell(
              formatQuantity(itemQuantity),
              regularFont,
              alignment: pw.Alignment.center,
            ),
            _tableCell(
              money(itemRate),
              regularFont,
              alignment: pw.Alignment.centerRight,
            ),
            _tableCell(
              money(itemAmount),
              boldFont,
              alignment: pw.Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: lightGrey, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FlexColumnWidth(4.6),
        2: pw.FixedColumnWidth(48),
        3: pw.FixedColumnWidth(60),
        4: pw.FixedColumnWidth(65),
        5: pw.FixedColumnWidth(75),
      },
      children: rows,
    );
  }

  // ============================================================
  // SERVICE DESCRIPTION CELL
  // ============================================================

  static pw.Widget _serviceDescriptionCell({
    required String service,
    required String description,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            service,
            style: pw.TextStyle(font: boldFont, fontSize: 6.7, color: black),
          ),
          if (description.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                description,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 5.9,
                  color: grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  static pw.Widget _tableHeader(
    String text,
    pw.Font font, {
    required pw.Alignment alignment,
    double? width,
  }) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      alignment: alignment,
      child: pw.Text(
        text,
        textAlign: alignment == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.left,
        style: pw.TextStyle(
          font: font,
          fontSize: 5.7,
          color: white,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  // ============================================================
  // TABLE CELL
  // ============================================================

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    required pw.Alignment alignment,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      alignment: alignment,
      child: pw.Text(
        text,
        textAlign: alignment == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.left,
        style: pw.TextStyle(font: font, fontSize: 6.2, color: darkGrey),
      ),
    );
  }

  // ============================================================
  // BANK DETAILS
  // ============================================================

  static pw.Widget _buildBankDetails({
    required String businessName,
    required String accountTitle,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String bankBranch,
    required String swiftCode,
    required String upiId,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final hasBankDetails =
        bankName.isNotEmpty ||
        accountNumber.isNotEmpty ||
        ifscCode.isNotEmpty ||
        bankBranch.isNotEmpty ||
        swiftCode.isNotEmpty ||
        upiId.isNotEmpty;

    if (!hasBankDetails) {
      return pw.Container(height: 95);
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: lightGrey, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CORPORATE WIRE REMITTANCE INSTRUCTIONS',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 7.2,
              color: black,
              letterSpacing: 0.25,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Container(height: 1.2, width: 145, color: red),
          pw.SizedBox(height: 5),
          if ((accountTitle.isNotEmpty ? accountTitle : businessName)
              .isNotEmpty)
            _bankLine(
              'Account Title',
              accountTitle.isNotEmpty ? accountTitle : businessName,
              boldFont,
              regularFont,
            ),
          if (bankName.isNotEmpty)
            _bankLine('Bank', bankName, boldFont, regularFont),
          if (accountNumber.isNotEmpty)
            _bankLine('Account Number', accountNumber, boldFont, regularFont),
          if (ifscCode.isNotEmpty || bankBranch.isNotEmpty)
            _bankLine(
              'IFSC / Branch',
              _combineIfscBranch(ifscCode, bankBranch),
              boldFont,
              regularFont,
            ),
          if (swiftCode.isNotEmpty || upiId.isNotEmpty)
            _bankLine(
              'SWIFT / UPI',
              _combineSwiftUpi(swiftCode, upiId),
              boldFont,
              regularFont,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TAX SUMMARY
  // ============================================================

  static pw.Widget _buildTaxSummary({
    required bool showGstDetails,
    required double subtotal,
    required double cgst,
    required double sgst,
    required double igst,
    required double gstPercent,
    required double total,
    required String gstType,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    if (!showGstDetails) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _taxSummaryLine('Invoice Amount:', subtotal, boldFont, regularFont),
          pw.SizedBox(height: 3),
          _grandTotalBox(total: total, boldFont: boldFont),
        ],
      );
    }

    final cgstPercent = gstPercent > 0 ? gstPercent / 2 : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _taxSummaryLine('Taxable Subtotal:', subtotal, boldFont, regularFont),
        if (gstType == 'LOCAL') ...[
          _taxSummaryLine(
            'CGST (${formatPercent(cgstPercent)}%):',
            cgst,
            boldFont,
            regularFont,
          ),
          _taxSummaryLine(
            'SGST (${formatPercent(cgstPercent)}%):',
            sgst,
            boldFont,
            regularFont,
          ),
          _taxSummaryLine('IGST (0.0%):', igst, boldFont, regularFont),
        ] else if (gstType == 'INTERSTATE') ...[
          _taxSummaryLine('CGST (0.0%):', cgst, boldFont, regularFont),
          _taxSummaryLine('SGST (0.0%):', sgst, boldFont, regularFont),
          _taxSummaryLine(
            'IGST (${formatPercent(gstPercent)}%):',
            igst,
            boldFont,
            regularFont,
          ),
        ] else ...[
          _taxSummaryLine('CGST (0.0%):', cgst, boldFont, regularFont),
          _taxSummaryLine('SGST (0.0%):', sgst, boldFont, regularFont),
          _taxSummaryLine('IGST (0.0%):', igst, boldFont, regularFont),
        ],
        pw.SizedBox(height: 3),
        _grandTotalBox(total: total, boldFont: boldFont),
      ],
    );
  }

  // ============================================================
  // GRAND TOTAL BOX
  // ============================================================

  static pw.Widget _grandTotalBox({
    required double total,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 7),
      decoration: const pw.BoxDecoration(color: black),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Grand Total (INR):',
            style: pw.TextStyle(font: boldFont, fontSize: 7.4, color: white),
          ),
          pw.Text(
            money(total),
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
              color: PdfColor.fromInt(0xFFFCA5A5),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAX SUMMARY LINE
  // ============================================================

  static pw.Widget _taxSummaryLine(
    String title,
    double value,
    pw.Font boldFont,
    pw.Font regularFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: regularFont, fontSize: 6.5, color: grey),
          ),
          pw.Text(
            money(value),
            style: pw.TextStyle(font: boldFont, fontSize: 6.5, color: darkGrey),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TERMS
  // ============================================================

  static pw.Widget _buildTerms({
    required List<String> terms,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'STANDARD TERMS & PAYMENT CONDITIONS:',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 7,
            color: red,
            letterSpacing: 0.2,
          ),
        ),
        pw.SizedBox(height: 4),
        for (int i = 0; i < terms.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '${i + 1}. ${terms[i]}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 6.1,
                color: darkGrey,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // SIGNATURE
  // ============================================================

  static pw.Widget _buildSignature({
    required String businessName,
    required String ownerName,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required pw.MemoryImage? signatureImage,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 155,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'For $businessName',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 6.8,
                  color: black,
                ),
              ),
              pw.SizedBox(height: 3),
              if (signatureImage != null)
                pw.SizedBox(
                  width: 95,
                  height: 28,
                  child: pw.Image(
                    signatureImage,
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.SizedBox(height: 28),
              pw.Container(width: 135, height: 0.8, color: black),
              pw.SizedBox(height: 4),
              pw.Text(
                'Authorized Signatory',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 6.8,
                  color: black,
                ),
              ),
              pw.SizedBox(height: 2),
              if (ownerName.isNotEmpty)
                pw.Text(
                  ownerName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 5.8,
                    color: grey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  // ============================================================
  // FOOTER
  // ============================================================

  static pw.Widget _buildFooter({
    required String footerText,
    required pw.Font regularFont,
    required pw.Font boldFont,
    required int pageNumber,
    required int totalPages,
  }) {
    final text = footerText.trim().isEmpty
        ? 'Thank you for your business.'
        : footerText.trim();

    return pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: double.infinity,
            child: pw.Text(
              text,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 5.8,
                color: grey,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.SizedBox(
            width: double.infinity,
            child: pw.Text(
              'Page $pageNumber of $totalPages',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 5.5,
                color: grey,
              ),
            ),
          ),
        ],
      ),
    );  }

  // ============================================================
  // TERMS DATA
  // ============================================================

  static List<String> _getTerms(
    Map<String, dynamic> invoice,
    String invoiceNumber,
    String businessEmail,
  ) {
    final terms = <String>[];

    final paymentInstruction = firstNonEmpty([
      invoice['payment_narration'],
      invoice['payment_instruction'],
    ]);

    final tdsNote = firstNonEmpty([invoice['tds_note']]);

    final customTerms = invoice['terms_conditions'];

    if (customTerms is List) {
      for (final term in customTerms) {
        final text = safeText(term);

        if (text.isNotEmpty) {
          terms.add(text);
        }
      }
    }

    if (terms.isEmpty) {
      terms.add('Payment terms are as agreed from date of invoice generation.');

      terms.add(
        'Please mention invoice number $invoiceNumber in transaction advice.',
      );

      if (tdsNote.isNotEmpty) {
        terms.add(tdsNote);
      } else {
        terms.add(
          'Any applicable statutory deductions or TDS shall be dealt with as per applicable requirements.',
        );
      }

      if (paymentInstruction.isNotEmpty) {
        terms.add(paymentInstruction);
      } else if (businessEmail.isNotEmpty) {
        terms.add(
          'For billing clarification or remittance advice, contact $businessEmail.',
        );
      }
    }

    return terms;
  }

  // ============================================================
  // BANK LINE
  // ============================================================

  static pw.Widget _bankLine(
    String title,
    String value,
    pw.Font boldFont,
    pw.Font regularFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$title: ',
              style: pw.TextStyle(font: boldFont, fontSize: 6, color: darkGrey),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 6,
                color: darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTACT
  // ============================================================

  static String _contactText({
    required String mobile,
    required String whatsapp,
  }) {
    if (mobile.isNotEmpty && whatsapp.isNotEmpty && mobile != whatsapp) {
      return 'Phone: $mobile • WhatsApp: $whatsapp';
    }

    if (mobile.isNotEmpty) {
      return 'Phone: $mobile';
    }

    if (whatsapp.isNotEmpty) {
      return 'WhatsApp: $whatsapp';
    }

    return '';
  }

  static String _headerContactLine({
    required String email,
    required String contact,
    required String website,
  }) {
    final parts = <String>[];

    if (email.isNotEmpty) {
      parts.add('Email: $email');
    }

    if (contact.isNotEmpty) {
      parts.add(contact);
    }

    if (website.isNotEmpty) {
      parts.add('Web: $website');
    }

    return parts.join('  |  ');
  }

  // ============================================================
  // REGISTRATION LINE
  // ============================================================

  static String _registrationLine({
    required String llpin,
    required String gstin,
    required String pan,
  }) {
    final parts = <String>[];

    if (llpin.isNotEmpty) {
      parts.add('LLPIN: $llpin');
    }

    if (gstin.isNotEmpty) {
      parts.add('GSTIN: $gstin');
    }

    if (pan.isNotEmpty) {
      parts.add('PAN: $pan');
    }

    return parts.join('  |  ');
  }

  static String _customerRegistrationLine({
    required String gstin,
    required String pan,
  }) {
    final parts = <String>[];

    if (gstin.isNotEmpty) {
      parts.add('GSTIN: $gstin');
    }

    if (pan.isNotEmpty) {
      parts.add('PAN: $pan');
    }

    return parts.join('  |  ');
  }

  // ============================================================
  // CUSTOMER CONTACT
  // ============================================================

  static String _customerContactLine({
    required String mobile,
    required String email,
  }) {
    final parts = <String>[];

    if (mobile.isNotEmpty) {
      parts.add('Mobile: $mobile');
    }

    if (email.isNotEmpty) {
      parts.add('Email: $email');
    }

    return parts.join('  |  ');
  }

  // ============================================================
  // IFSC / BRANCH
  // ============================================================

  static String _combineIfscBranch(String ifsc, String branch) {
    if (ifsc.isNotEmpty && branch.isNotEmpty) {
      return '$ifsc  |  Branch: $branch';
    }

    if (ifsc.isNotEmpty) {
      return ifsc;
    }

    return branch;
  }

  // ============================================================
  // SWIFT / UPI
  // ============================================================

  static String _combineSwiftUpi(String swift, String upi) {
    if (swift.isNotEmpty && upi.isNotEmpty) {
      return '$swift  |  UPI: $upi';
    }

    if (swift.isNotEmpty) {
      return 'SWIFT: $swift';
    }

    return 'UPI: $upi';
  }

  // ============================================================
  // MONEY
  // ============================================================

  static String money(double value) {
    return '\u20B9 ${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // QUANTITY
  // ============================================================

  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // PERCENTAGE
  // ============================================================

  static String formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // SAFE TEXT
  // ============================================================

  static String safeText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  // ============================================================
  // FIRST NON EMPTY
  // ============================================================

  static String firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = safeText(value);

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  static double toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  // ============================================================
  // DATE
  // ============================================================

  static String formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    DateTime? date;

    try {
      date = DateTime.tryParse(text);
    } catch (_) {
      date = null;
    }

    if (date == null) {
      return text;
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = _monthName(date.month);

    final year = date.year.toString();

    return '$day-$month-$year';
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return months[month - 1];
  }

  // ============================================================
  // AMOUNT TO WORDS
  // ============================================================

  static String amountToWords(int number) {
    if (number == 0) {
      return 'Zero Rupees';
    }

    if (number < 0) {
      return 'Minus ${amountToWords(number.abs())}';
    }

    final parts = <String>[];

    final crore = number ~/ 10000000;

    final afterCrore = number % 10000000;

    final lakh = afterCrore ~/ 100000;

    final afterLakh = afterCrore % 100000;

    final thousand = afterLakh ~/ 1000;

    final remainder = afterLakh % 1000;

    if (crore > 0) {
      parts.add('${_numberBelowThousand(crore)} Crore');
    }

    if (lakh > 0) {
      parts.add('${_numberBelowThousand(lakh)} Lakh');
    }

    if (thousand > 0) {
      parts.add('${_numberBelowThousand(thousand)} Thousand');
    }

    if (remainder > 0) {
      parts.add(_numberBelowThousand(remainder));
    }

    return parts.join('');
  }

  // ============================================================
  // NUMBER BELOW THOUSAND
  // ============================================================

  static String _numberBelowThousand(int number) {
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];

    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number == 0) {
      return '';
    }

    if (number < 20) {
      return ones[number];
    }

    if (number < 100) {
      final ten = number ~/ 10;

      final one = number % 10;

      if (one == 0) {
        return tens[ten];
      }

      return '${tens[ten]} ${ones[one]}';
    }

    final hundred = number ~/ 100;

    final remainder = number % 100;

    if (remainder == 0) {
      return '${ones[hundred]} Hundred';
    }

    return '${ones[hundred]} Hundred ${_numberBelowThousand(remainder)}';
  }
}







