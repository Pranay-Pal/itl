class ExpenseFilters {
  const ExpenseFilters({
    this.section,
    this.status,
    this.month,
    this.year,
    this.search,
    this.groupPersonal,
    this.perPage,
    this.page,
  });

  final String? section;
  final String? status;
  final int? month;
  final int? year;
  final String? search;
  final bool? groupPersonal;
  final int? perPage;
  final int? page;

  ExpenseFilters copyWith({
    String? section,
    String? status,
    int? month,
    int? year,
    String? search,
    bool? groupPersonal,
    int? perPage,
    int? page,
  }) {
    return ExpenseFilters(
      section: section ?? this.section,
      status: status ?? this.status,
      month: month ?? this.month,
      year: year ?? this.year,
      search: search ?? this.search,
      groupPersonal: groupPersonal ?? this.groupPersonal,
      perPage: perPage ?? this.perPage,
      page: page ?? this.page,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'section': section,
      'status': status,
      'month': month,
      'year': year,
      'search': search,
      'group_personal': groupPersonal,
      'per_page': perPage,
      'page': page,
    }..removeWhere((key, value) => value == null);
  }

  factory ExpenseFilters.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ExpenseFilters();
    return ExpenseFilters(
      section: map['section']?.toString(),
      status: map['status']?.toString(),
      month: _parseInt(map['month']),
      year: _parseInt(map['year']),
      search: map['search']?.toString(),
      groupPersonal: _parseBool(map['group_personal']),
      perPage: _parseInt(map['per_page']),
      page: _parseInt(map['page']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase();
    if (normalized == '1' || normalized == 'true') return true;
    if (normalized == '0' || normalized == 'false') return false;
    return null;
  }
}
