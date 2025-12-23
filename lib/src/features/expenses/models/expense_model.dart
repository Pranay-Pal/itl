import 'package:flutter/foundation.dart';

class ExpenseItem {
  final int id;
  final String section;
  final String? expenseDate;
  final double amount;
  final double approvedAmount;
  final double dueAmount;
  final bool submittedForApproval;
  final String? description;
  final String? fileUrl;
  final String? receiptFilename;
  final String status; // "approved", "rejected", "pending"

  ExpenseItem({
    required this.id,
    required this.section,
    this.expenseDate,
    required this.amount,
    this.approvedAmount = 0.0,
    this.dueAmount = 0.0,
    this.submittedForApproval = false,
    this.description,
    this.fileUrl,
    this.receiptFilename,
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
      approvedAmount:
          double.tryParse(json['approved_amount']?.toString() ?? '0') ?? 0.0,
      dueAmount: double.tryParse(json['due_amount']?.toString() ?? '0') ?? 0.0,
      submittedForApproval: json['submitted_for_approval'] == true ||
          json['submitted_for_approval'] == 1,
      description: json['description']?.toString(),
      fileUrl: json['receipt_url']?.toString() ??
          json['file_url']?.toString() ??
          json['file_path']?.toString(), // Added file_path just in case
      receiptFilename: json['receipt_filename']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }

  String get statusLabel {
    final s = status.toLowerCase();
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    return 'Pending';
  }

  String get statusClass {
    final s = status.toLowerCase();
    if (s == 'approved') return 'success';
    if (s == 'rejected') return 'danger';
    return 'warning';
  }
}

class ExpenseTotals {
  final double totalAmount;
  final double approvedAmount;
  final double pendingAmount;

  ExpenseTotals({
    required this.totalAmount,
    required this.approvedAmount,
    required this.pendingAmount,
  });

  factory ExpenseTotals.fromJson(Map<String, dynamic> json) {
    return ExpenseTotals(
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      approvedAmount:
          double.tryParse(json['approved_amount']?.toString() ?? '0') ?? 0.0,
      pendingAmount:
          double.tryParse(json['pending_amount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class ExpenseResponse {
  final List<ExpenseItem> items;
  final ExpenseTotals? totals;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  ExpenseResponse({
    required this.items,
    this.totals,
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
          debugPrint(
              'ExpenseResponse: Detected nested paginator in items. Extracting items["data"].');
          rawItems = rawItems['data'];
        }

        debugPrint(
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
          debugPrint(
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

    // Parse Totals
    ExpenseTotals? totals;
    // According to docs: data.totals
    if (dataRoot is Map && dataRoot['totals'] != null) {
      totals =
          ExpenseTotals.fromJson(Map<String, dynamic>.from(dataRoot['totals']));
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
      totals: totals,
      total: total,
      perPage: perPage,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }
}
