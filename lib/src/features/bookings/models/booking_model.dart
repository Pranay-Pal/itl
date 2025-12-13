// Models for the new Booking system based on API response

class BookingParent {
  final int id;
  final String? clientName;
  final String? referenceNo;
  final String? letterDate;
  final String? paymentOption;
  final String? uploadLetterPath;
  final int? itemsCount; // Helper for UI
  final List<BookingItem> items;

  BookingParent({
    required this.id,
    this.clientName,
    this.referenceNo,
    this.letterDate,
    this.paymentOption,
    this.uploadLetterPath,
    this.itemsCount,
    this.items = const [],
  });

  factory BookingParent.fromJson(Map<String, dynamic> json) {
    var itemsList = <BookingItem>[];
    if (json['items'] != null) {
      json['items'].forEach((v) {
        itemsList.add(BookingItem.fromJson(v));
      });
    }

    return BookingParent(
      id: json['id'],
      clientName: json['client_name'],
      referenceNo: json['reference_no'],
      letterDate: json['letter_date'],
      paymentOption: json['payment_option'],
      uploadLetterPath: json['upload_letter_path'],
      itemsCount: itemsList.length, // Derived
      items: itemsList,
    );
  }
}

class BookingItem {
  final int id;
  final String? jobOrderNo;
  final String? sampleQuality;
  final String? particulars;
  final String? sampleDescription;
  final String? status; // Inferred or mapped
  final String? amount;
  final String? labExpectedDate;
  final int? isCanceled;

  BookingItem({
    required this.id,
    this.jobOrderNo,
    this.sampleQuality,
    this.particulars,
    this.sampleDescription,
    this.status,
    this.amount,
    this.labExpectedDate,
    this.isCanceled,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json['id'],
      jobOrderNo: json['job_order_no'],
      sampleQuality: json['sample_quality'],
      particulars: json['particulars'],
      sampleDescription: json['sample_description'],
      // Logic for status based on flags? For now using a placeholder or hold_status if available
      // In big JSON: "hold_status": false (on parent), item has "is_canceled"
      status: (json['is_canceled'] == 1) ? 'Canceled' : 'Pending',
      amount: json['amount'],
      labExpectedDate: json['lab_expected_date'],
      isCanceled: json['is_canceled'],
    );
  }
}

class BookingResponse {
  final List<BookingParent> data;
  final int currentPage;
  final int lastPage;

  BookingResponse(
      {required this.data, required this.currentPage, required this.lastPage});

  // Expects the PAGINATOR object (containing 'data', 'current_page', etc.)
  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    var dataList = <BookingParent>[];
    if (json['data'] != null) {
      json['data'].forEach((v) {
        dataList.add(BookingParent.fromJson(v));
      });
    }

    return BookingResponse(
      data: dataList,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }
}
