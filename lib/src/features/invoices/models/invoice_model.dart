class Invoice {
  final int id;
  final String invoiceNo;
  final String? referenceNo;
  final String? clientName;
  final num gstAmount;
  final num totalAmount;
  final DateTime? letterDate;
  final List<BookingItem> bookingItems;
  final String? invoiceLetterUrl;
  final bool canGenerate;

  Invoice({
    required this.id,
    required this.invoiceNo,
    this.referenceNo,
    this.clientName,
    required this.gstAmount,
    required this.totalAmount,
    this.letterDate,
    required this.bookingItems,
    this.invoiceLetterUrl,
    required this.canGenerate,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? 0,
      invoiceNo: json['invoice_no'] ?? '',
      referenceNo: json['reference_no'],
      clientName: json['client_name'],
      gstAmount: num.tryParse(json['gst_amount']?.toString() ?? '0') ?? 0,
      totalAmount: num.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      letterDate: json['letter_date'] != null
          ? DateTime.tryParse(json['letter_date'].toString())
          : null,
      bookingItems: (json['booking_items'] as List<dynamic>?)
              ?.map((e) => BookingItem.fromJson(e))
              .toList() ??
          [],
      invoiceLetterUrl: json['invoice_letter_url'],
      canGenerate: json['can_generate'] ?? false,
    );
  }
}

class BookingItem {
  final int id;
  final String? sampleDescription;
  final String? jobOrderNo;
  final int qty;
  final num rate;
  final num amount;

  BookingItem({
    required this.id,
    this.sampleDescription,
    this.jobOrderNo,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json['id'] ?? 0,
      // API response uses 'sample_discription' or 'sample_description', handling both just in case
      sampleDescription:
          json['sample_discription'] ?? json['sample_description'],
      jobOrderNo: json['job_order_no'],
      qty: num.tryParse(json['qty']?.toString() ?? '0')?.toInt() ?? 0,
      rate: num.tryParse(json['rate']?.toString() ?? '0') ?? 0,
      amount: num.tryParse(json['amount']?.toString() ?? '0') ?? 0,
    );
  }
}

class InvoiceResponse {
  final List<Invoice> invoices;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  InvoiceResponse({
    required this.invoices,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory InvoiceResponse.fromJson(Map<String, dynamic> json) {
    // Structure: data -> { invoices: { data: [...], ...meta fields... } }
    // Or sometimes: data -> invoices -> data.
    // Based on "Example invoice object" provided:
    // Envelope: { status: true, message: string, data: { invoices: <paginated>, meta: { ... } } }
    // Wait, the "paginated" object usually contains 'data', 'current_page', etc directly if it's Laravel default.
    // The provided sample response:
    // "data": { "invoices": { "current_page": 1, "data": [...], "total": 7 ... }, "meta": { ... } }
    // So 'invoices' key holds the pagination object directly.

    final invoicesData = json['invoices'];
    final meta = json['meta']; // Redundant if inside invoices, but let's check.

    List<Invoice> list = [];
    if (invoicesData != null && invoicesData['data'] != null) {
      list = (invoicesData['data'] as List<dynamic>)
          .map((e) => Invoice.fromJson(e))
          .toList();
    }

    return InvoiceResponse(
      invoices: list,
      total: invoicesData?['total'] ?? meta?['total'] ?? 0,
      perPage: invoicesData?['per_page'] ?? meta?['per_page'] ?? 25,
      currentPage: invoicesData?['current_page'] ?? meta?['current_page'] ?? 1,
      lastPage: invoicesData?['last_page'] ?? meta?['last_page'] ?? 1,
    );
  }
}
