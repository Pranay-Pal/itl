class PendingItem {
  final int id;
  final String? jobOrderNo;
  final String? clientName;
  final String? sampleDescription;
  final String? sampleQuality;
  final String? particulars;
  final String? status;
  final String? receiver;
  final String? uploadLetterUrl;

  PendingItem({
    required this.id,
    this.jobOrderNo,
    this.clientName,
    this.sampleDescription,
    this.sampleQuality,
    this.particulars,
    this.status,
    this.receiver,
    this.uploadLetterUrl,
  });

  factory PendingItem.fromJson(Map<String, dynamic> json) {
    return PendingItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      jobOrderNo: json['job_order_no'],
      clientName: json['client_name'],
      sampleDescription: json['sample_description'],
      sampleQuality: json['sample_quality'],
      particulars: json['particulars'],
      status: json['status'],
      receiver: json['receiver'],
      uploadLetterUrl: json['upload_letter_url'],
    );
  }
}

class PendingBooking {
  final int id;
  final String? clientName;
  final String? referenceNo;
  final int pendingItemsCount;
  final String? uploadLetterUrl;
  final List<PendingItem> pendingItems;

  PendingBooking({
    required this.id,
    this.clientName,
    this.referenceNo,
    required this.pendingItemsCount,
    this.uploadLetterUrl,
    required this.pendingItems,
  });

  factory PendingBooking.fromJson(Map<String, dynamic> json) {
    var itemsList = <PendingItem>[];
    if (json['pending_items'] != null) {
      if (json['pending_items'] is List) {
        for (var v in json['pending_items']) {
          itemsList.add(PendingItem.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    return PendingBooking(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      clientName: json['client_name'],
      referenceNo: json['reference_no'],
      pendingItemsCount:
          int.tryParse(json['pending_items_count']?.toString() ?? '0') ?? 0,
      uploadLetterUrl: json['upload_letter_url'],
      pendingItems: itemsList,
    );
  }
}

class PendingResponse {
  final List<PendingItem> items;
  final List<PendingBooking> bookings;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  PendingResponse({
    this.items = const [],
    this.bookings = const [],
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory PendingResponse.fromJson(Map<String, dynamic> json) {
    List<PendingItem> parsedItems = [];
    List<PendingBooking> parsedBookings = [];
    Map<String, dynamic>? metaSource;

    if (json['items'] != null) {
      var itemsData = json['items'];
      if (itemsData is Map) {
        // Safe cast to Map<String, dynamic>
        metaSource = Map<String, dynamic>.from(itemsData);
        if (itemsData['data'] is List) {
          for (var v in itemsData['data']) {
            parsedItems.add(PendingItem.fromJson(Map<String, dynamic>.from(v)));
          }
        }
      } else if (itemsData is List) {
        for (var v in itemsData) {
          parsedItems.add(PendingItem.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    if (json['bookings'] != null) {
      var bookingsData = json['bookings'];
      if (bookingsData is Map) {
        metaSource = Map<String, dynamic>.from(bookingsData);
        if (bookingsData['data'] is List) {
          for (var v in bookingsData['data']) {
            parsedBookings
                .add(PendingBooking.fromJson(Map<String, dynamic>.from(v)));
          }
        }
      } else if (bookingsData is List) {
        for (var v in bookingsData) {
          parsedBookings
              .add(PendingBooking.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    if (metaSource == null && json['meta'] != null) {
      metaSource = Map<String, dynamic>.from(json['meta']);
    }
    metaSource ??= json;

    return PendingResponse(
      items: parsedItems,
      bookings: parsedBookings,
      total: metaSource['total'] ?? 0,
      perPage: int.tryParse(metaSource['per_page']?.toString() ?? '25') ?? 25,
      currentPage: metaSource['current_page'] ?? 1,
      lastPage: metaSource['last_page'] ?? 1,
    );
  }
}
