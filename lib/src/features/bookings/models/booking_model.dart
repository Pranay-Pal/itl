// Models for the new Booking system based on API response

// 1. Flat Item for "Show Booking" (/bookings/by-letter endpoint in docs, but logic is flat list)
class BookingItemFlat {
  final int id;
  final String? jobOrderNo;
  final String? referenceNo;
  final String? clientName;
  final String? sampleQuality;
  final String? particulars;
  final String? status;
  final String? statusClass;
  final String? statusDetail;
  final String? letterUrl;
  final String? receivedAt;
  final String? issueDate;
  final double? amount;
  final String? labExpectedDate;
  final String? jobOrderDate;

  BookingItemFlat({
    required this.id,
    this.jobOrderNo,
    this.referenceNo,
    this.clientName,
    this.sampleQuality,
    this.particulars,
    this.status,
    this.statusClass,
    this.statusDetail,
    this.letterUrl,
    this.receivedAt,
    this.issueDate,
    this.amount,
    this.labExpectedDate,
    this.jobOrderDate,
  });

  factory BookingItemFlat.fromJson(Map<String, dynamic> json) {
    return BookingItemFlat(
      id: json['id'],
      jobOrderNo: json['job_order_no'],
      referenceNo: json['reference_no'],
      clientName: json['client_name'],
      sampleQuality: json['sample_quality'],
      particulars: json['particulars'],
      status: json['status'],
      statusClass: json['status_class'],
      statusDetail: json['status_detail'],
      letterUrl:
          json['upload_letter_url'] ?? json['letter_url'], // Handle both keys
      receivedAt: json['received_at'],
      issueDate: json['issue_date'],
      amount: json['amount'] != null
          ? double.tryParse(json['amount'].toString())
          : null,
      labExpectedDate: json['lab_expected_date'],
      jobOrderDate: json['job_order_date'],
    );
  }
}

class BookingFlatResponse {
  final List<BookingItemFlat> items;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  BookingFlatResponse({
    required this.items,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory BookingFlatResponse.fromJson(Map<String, dynamic> json) {
    var itemsList = <BookingItemFlat>[];
    Map<String, dynamic>? paginator;

    // The log shows: "items": { "current_page": 1, "data": [...] }
    if (json['items'] != null) {
      if (json['items'] is Map && json['items'].containsKey('data')) {
        // 'items' is the Paginator object
        paginator = json['items'];
        var rawData = paginator!['data'];

        if (rawData is List) {
          for (var v in rawData) {
            itemsList.add(BookingItemFlat.fromJson(v));
          }
        } else if (rawData is Map) {
          for (var v in rawData.values) {
            itemsList.add(BookingItemFlat.fromJson(v));
          }
        }
      } else {
        // Fallback: 'items' is the list directly (as per old docs)
        if (json['items'] is List) {
          for (var v in json['items']) {
            itemsList.add(BookingItemFlat.fromJson(v));
          }
        } else if (json['items'] is Map) {
          for (var v in json['items'].values) {
            itemsList.add(BookingItemFlat.fromJson(v));
          }
        }
      }
    }

    // Try to find pagination data either in the 'items' paginator or 'meta'
    final metaSource = paginator ?? json['meta'] ?? json;

    return BookingFlatResponse(
      items: itemsList,
      total: metaSource['total'] ?? 0,
      perPage: int.tryParse(metaSource['per_page']?.toString() ?? '25') ?? 25,
      currentPage: metaSource['current_page'] ?? 1,
      lastPage: metaSource['last_page'] ?? 1,
    );
  }
}

// 2. Grouped Item for "By Letter" (/bookings/showbooking endpoint in docs, grouped by parent)
class BookingGrouped {
  final int id;
  final String? clientName;
  final String? referenceNo;
  final int? itemsCount;
  final List<BookingItemNested> items;
  final List<ReportFile> reportFiles;
  final String? uploadLetterUrl;
  final String? invoiceUrl;

  BookingGrouped({
    required this.id,
    this.clientName,
    this.referenceNo,
    this.itemsCount,
    this.items = const [],
    this.reportFiles = const [],
    this.uploadLetterUrl,
    this.invoiceUrl,
  });

  factory BookingGrouped.fromJson(Map<String, dynamic> json) {
    var itemsList = <BookingItemNested>[];
    if (json['items'] != null) {
      if (json['items'] is List) {
        for (var v in json['items']) {
          itemsList.add(BookingItemNested.fromJson(v));
        }
      } else if (json['items'] is Map) {
        for (var v in json['items'].values) {
          itemsList.add(BookingItemNested.fromJson(v));
        }
      }
    }

    var reportList = <ReportFile>[];

    if (json['report_files'] != null) {
      if (json['report_files'] is List) {
        for (var v in json['report_files']) {
          reportList.add(ReportFile.fromJson(v));
        }
      } else if (json['report_files'] is Map) {
        for (var v in json['report_files'].values) {
          reportList.add(ReportFile.fromJson(v));
        }
      }
    }

    return BookingGrouped(
      id: json['id'],
      clientName: json['client_name'],
      referenceNo: json['reference_no'],
      itemsCount: json['items_count'],
      items: itemsList,
      reportFiles: reportList,
      uploadLetterUrl: json['upload_letter_url'],
      invoiceUrl: json['invoice_url'],
    );
  }
}

class BookingItemNested {
  final int id;
  final String? jobOrderNo;
  final String? sampleDescription;
  final String? sampleQuality;
  final String? status;
  final String? particulars;
  final String? labExpectedDate;
  final String? amount;

  BookingItemNested({
    required this.id,
    this.jobOrderNo,
    this.sampleDescription,
    this.sampleQuality,
    this.status,
    this.particulars,
    this.labExpectedDate,
    this.amount,
  });

  factory BookingItemNested.fromJson(Map<String, dynamic> json) {
    return BookingItemNested(
      id: json['id'],
      jobOrderNo: json['job_order_no'],
      sampleDescription: json['sample_description'],
      sampleQuality: json['sample_quality'],
      status: json['status'],
      particulars: json['particulars'],
      labExpectedDate: json['lab_expected_date'],
      amount: json['amount'],
    );
  }
}

class ReportFile {
  final String? name;
  final String? url;

  ReportFile({this.name, this.url});

  factory ReportFile.fromJson(Map<String, dynamic> json) {
    return ReportFile(
      name: json['name'],
      url: json['url'],
    );
  }
}

class BookingGroupedResponse {
  final List<BookingGrouped> bookings;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  BookingGroupedResponse({
    required this.bookings,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory BookingGroupedResponse.fromJson(Map<String, dynamic> json) {
    var bookingsList = <BookingGrouped>[];
    Map<String, dynamic>? paginator;

    // Check if 'bookings' is a paginator
    if (json['bookings'] != null) {
      if (json['bookings'] is Map && json['bookings'].containsKey('data')) {
        paginator = json['bookings'];
        var rawData = paginator!['data'];

        if (rawData is List) {
          for (var v in rawData) {
            bookingsList.add(BookingGrouped.fromJson(v));
          }
        } else if (rawData is Map) {
          for (var v in rawData.values) {
            bookingsList.add(BookingGrouped.fromJson(v));
          }
        }
      } else {
        // Fallback direct list
        if (json['bookings'] is List) {
          for (var v in json['bookings']) {
            bookingsList.add(BookingGrouped.fromJson(v));
          }
        } else if (json['bookings'] is Map) {
          for (var v in json['bookings'].values) {
            bookingsList.add(BookingGrouped.fromJson(v));
          }
        }
      }
    }

    final metaSource = paginator ?? json['meta'] ?? json;

    return BookingGroupedResponse(
      bookings: bookingsList,
      total: metaSource['total'] ?? 0,
      perPage: int.tryParse(metaSource['per_page']?.toString() ?? '25') ?? 25,
      currentPage: metaSource['current_page'] ?? 1,
      lastPage: metaSource['last_page'] ?? 1,
    );
  }
}
