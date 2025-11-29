class ExpenseTotals {
  const ExpenseTotals({
    required this.totalExpenses,
    required this.approved,
    required this.due,
  });

  final double totalExpenses;
  final double approved;
  final double due;

  factory ExpenseTotals.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ExpenseTotals(totalExpenses: 0, approved: 0, due: 0);
    }
    return ExpenseTotals(
      totalExpenses: _parseDouble(map['total_expenses']),
      approved: _parseDouble(map['approved']),
      due: _parseDouble(map['due']),
    );
  }

  ExpenseTotals copyWith(
      {double? totalExpenses, double? approved, double? due}) {
    return ExpenseTotals(
      totalExpenses: totalExpenses ?? this.totalExpenses,
      approved: approved ?? this.approved,
      due: due ?? this.due,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
