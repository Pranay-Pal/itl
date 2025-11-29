import 'package:itl/src/features/expenses/models/expense.dart';
import 'package:itl/src/features/expenses/models/expense_filters.dart';
import 'package:itl/src/features/expenses/models/expense_totals.dart';

class ExpensesResponse {
  const ExpensesResponse({
    required this.expenses,
    this.meta,
    this.links,
    this.totals,
    this.filters,
  });

  final List<Expense> expenses;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? links;
  final ExpenseTotals? totals;
  final ExpenseFilters? filters;

  bool get isEmpty => expenses.isEmpty;

  ExpensesResponse copyWith({
    List<Expense>? expenses,
    Map<String, dynamic>? meta,
    Map<String, dynamic>? links,
    ExpenseTotals? totals,
    ExpenseFilters? filters,
  }) {
    return ExpensesResponse(
      expenses: expenses ?? this.expenses,
      meta: meta ?? this.meta,
      links: links ?? this.links,
      totals: totals ?? this.totals,
      filters: filters ?? this.filters,
    );
  }
}
