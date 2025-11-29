import 'dart:convert';

class Expense {
  Expense({
    required this.id,
    required this.section,
    required this.amount,
    required this.approvedAmount,
    required this.dueAmount,
    required this.status,
    this.personName,
    this.marketingPersonCode,
    this.marketingPersonName,
    this.fromDate,
    this.toDate,
    this.createdAt,
    this.updatedAt,
    this.description,
    this.receiptUrl,
    this.receiptUrls = const [],
    this.approvalSummaryUrl,
    this.aggregateIds = const [],
    this.personalPeriodLabel,
    this.raw = const {},
  });

  final int id;
  final String section;
  final String? personName;
  final String? marketingPersonCode;
  final String? marketingPersonName;
  final double amount;
  final double approvedAmount;
  final double dueAmount;
  final String status;
  final DateTime? fromDate;
  final DateTime? toDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? description;
  final String? receiptUrl;
  final List<String> receiptUrls;
  final String? approvalSummaryUrl;
  final List<int> aggregateIds;
  final String? personalPeriodLabel;
  final Map<String, dynamic> raw;

  bool get isPersonal => section == 'personal';
  bool get isPending => status == 'pending';

  Expense copyWith({
    int? id,
    String? section,
    String? personName,
    String? marketingPersonCode,
    String? marketingPersonName,
    double? amount,
    double? approvedAmount,
    double? dueAmount,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? receiptUrl,
    List<String>? receiptUrls,
    String? approvalSummaryUrl,
    List<int>? aggregateIds,
    String? personalPeriodLabel,
    Map<String, dynamic>? raw,
  }) {
    return Expense(
      id: id ?? this.id,
      section: section ?? this.section,
      personName: personName ?? this.personName,
      marketingPersonCode: marketingPersonCode ?? this.marketingPersonCode,
      marketingPersonName: marketingPersonName ?? this.marketingPersonName,
      amount: amount ?? this.amount,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      status: status ?? this.status,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptUrls: receiptUrls ?? this.receiptUrls,
      approvalSummaryUrl: approvalSummaryUrl ?? this.approvalSummaryUrl,
      aggregateIds: aggregateIds ?? this.aggregateIds,
      personalPeriodLabel: personalPeriodLabel ?? this.personalPeriodLabel,
      raw: raw ?? this.raw,
    );
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final receipts = _parseStringList(map['receipt_urls']);
    final aggregateIds = _parseIntList(map['aggregate_ids']);

    return Expense(
      id: _parseInt(map['id']),
      section: (map['section'] ?? 'marketing').toString(),
      personName: map['person_name']?.toString(),
      marketingPersonCode: map['marketing_person_code']?.toString(),
      marketingPersonName: map['marketing_person_name']?.toString(),
      amount: _parseDouble(map['amount']),
      approvedAmount: _parseDouble(map['approved_amount']),
      dueAmount: _parseDouble(map['due_amount']),
      status: (map['status'] ?? 'pending').toString(),
      fromDate: _parseDate(map['from_date']),
      toDate: _parseDate(map['to_date']),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      description: map['description']?.toString(),
      receiptUrl: map['receipt_url']?.toString(),
      receiptUrls: receipts,
      approvalSummaryUrl: map['approval_summary_url']?.toString(),
      aggregateIds: aggregateIds,
      personalPeriodLabel: map['personal_period_label']?.toString(),
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'section': section,
      'person_name': personName,
      'marketing_person_code': marketingPersonCode,
      'marketing_person_name': marketingPersonName,
      'amount': amount,
      'approved_amount': approvedAmount,
      'due_amount': dueAmount,
      'status': status,
      'from_date': fromDate?.toIso8601String(),
      'to_date': toDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'description': description,
      'receipt_url': receiptUrl,
      'receipt_urls': receiptUrls,
      'approval_summary_url': approvalSummaryUrl,
      'aggregate_ids': aggregateIds,
      'personal_period_label': personalPeriodLabel,
    };
  }

  String toJson() => jsonEncode(toMap());

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString();
    if (text.isEmpty) return null;
    try {
      if (text.contains('T')) {
        return DateTime.tryParse(text);
      }
      final parts = text.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return [value];
    }
    return const [];
  }

  static List<int> _parseIntList(dynamic value) {
    if (value is List) {
      return value.map((e) => _parseInt(e)).toList();
    }
    return const [];
  }
}
