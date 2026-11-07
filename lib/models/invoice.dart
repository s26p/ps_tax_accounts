class Invoice {
  final int? id;
  final String invoiceNumber;
  final String invoiceDate;
  final int customerId;
  final String service;
  final num quantity;
  final num rate;
  final num gstPercent;
  final num subtotal;
  final num gstAmount;
  final num total;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerId,
    required this.service,
    required this.quantity,
    required this.rate,
    required this.gstPercent,
    required this.subtotal,
    required this.gstAmount,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'customer_id': customerId,
      'service': service,
      'quantity': quantity,
      'rate': rate,
      'gst_percent': gstPercent,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'total': total,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'] ?? '',
      invoiceDate: map['invoice_date'] ?? '',
      customerId: map['customer_id'] ?? 0,
      service: map['service'] ?? '',
      quantity: map['quantity'] ?? 0,
      rate: map['rate'] ?? 0,
      gstPercent: map['gst_percent'] ?? 0,
      subtotal: map['subtotal'] ?? 0,
      gstAmount: map['gst_amount'] ?? 0,
      total: map['total'] ?? 0,
    );
  }
}