class ExpenseItem {
  final int id;
  final String section;
  final String? expenseDate;
  final double amount;
  final String? description;
  final String? fileUrl;
  final int status; // 0: pending, 1: approved, 2: rejected

  ExpenseItem({
    required this.id,
    required this.section,
    this.expenseDate,
    required this.amount,
    this.description,
    this.fileUrl,
    required this.status,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      section: json['section']?.toString() ?? 'personal',
      expenseDate: json['expense_date']?.toString(),
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      description: json['description']?.toString(),
      fileUrl: json['file_url']?.toString(),
      status: json['status'] is int
          ? json['status']
          : (int.tryParse(json['status']?.toString() ?? '0') ?? 0),
    );
  }

  String get statusLabel {
    switch (status) {
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      case 0:
      default:
        return 'Pending';
    }
  }

  String get statusClass {
    switch (status) {
      case 1:
        return 'success';
      case 2:
        return 'danger';
      case 0:
      default:
        return 'warning';
    }
  }
}

class ExpenseResponse {
  final List<ExpenseItem> items;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  ExpenseResponse({
    required this.items,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory ExpenseResponse.fromJson(Map<String, dynamic> json) {
    var itemsList = <ExpenseItem>[];
    // Docs say: "JSON with data.items[] and data.meta (pagination)."

    var dataRoot = json['data'];
    if (dataRoot is Map) {
      if (dataRoot['items'] != null) {
        var rawItems = dataRoot['items'];

        // Handle nested Laravel paginator: data.items.data
        if (rawItems is Map &&
            rawItems.containsKey('data') &&
            rawItems['data'] is List) {
          print(
              'ExpenseResponse: Detected nested paginator in items. Extracting items["data"].');
          rawItems = rawItems['data'];
        }

        print(
            'ExpenseResponse: Processing items of type ${rawItems.runtimeType}');

        if (rawItems is List) {
          for (var e in rawItems) {
            if (e is Map<String, dynamic>) {
              itemsList.add(ExpenseItem.fromJson(e));
            } else if (e is Map) {
              itemsList.add(ExpenseItem.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        } else if (rawItems is Map) {
          // Fallback for Map-based list (rare but possible)
          print(
              'ExpenseResponse: rawItems is Map (non-standard list structure).');
          for (var v in rawItems.values) {
            if (v is Map<String, dynamic>) {
              itemsList.add(ExpenseItem.fromJson(v));
            } else if (v is Map) {
              itemsList.add(ExpenseItem.fromJson(Map<String, dynamic>.from(v)));
            }
          }
        }
      }
    }

    // Pagination
    var meta = dataRoot != null && dataRoot is Map && dataRoot['meta'] != null
        ? dataRoot['meta']
        : json['meta'];

    int total = 0;
    int perPage = 25;
    int currentPage = 1;
    int lastPage = 1;

    if (meta != null && meta is Map) {
      total = meta['total'] ?? 0;
      perPage = int.tryParse(meta['per_page']?.toString() ?? '25') ?? 25;
      currentPage = meta['current_page'] ?? 1;
      lastPage = meta['last_page'] ?? 1;
    }

    return ExpenseResponse(
      items: itemsList,
      total: total,
      perPage: perPage,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }
}
