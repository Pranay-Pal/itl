import 'package:itl/src/features/expenses/models/expense.dart';
import 'package:itl/src/features/expenses/models/expense_filters.dart';
import 'package:itl/src/features/expenses/models/expense_totals.dart';
import 'package:itl/src/features/expenses/models/expenses_response.dart';
import 'package:itl/src/services/api_service.dart';

class ExpensesRepository {
  ExpensesRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<ExpensesResponse> fetchExpenses({
    String? section,
    String? status,
    int? month,
    int? year,
    String? search,
    bool? groupPersonal,
    int page = 1,
    int? perPage,
  }) async {
    final payload = await _apiService.fetchExpenses(
      section: section,
      status: status,
      month: month,
      year: year,
      search: search,
      groupPersonal: groupPersonal,
      page: page,
      perPage: perPage,
    );

    final expenses = _parseExpenses(payload['data']);
    final meta = _asMap(payload['meta']);
    final links = _asMap(payload['links']);
    final totals = ExpenseTotals.fromMap(_asMap(payload['totals']));
    final filters = ExpenseFilters.fromMap(_asMap(payload['filters']));

    return ExpensesResponse(
      expenses: expenses,
      meta: meta,
      links: links,
      totals: totals,
      filters: filters,
    );
  }

  Future<Expense?> fetchExpenseDetail(int expenseId) async {
    final payload = await _apiService.getExpense(expenseId);
    if (payload == null) return null;
    final expenseMap = _asMap(payload['data']) ??
        _asMap(payload['expense']) ??
        (payload.containsKey('id') ? payload : null);
    if (expenseMap == null) return null;
    return Expense.fromMap(expenseMap);
  }

  Future<Expense?> createExpense({
    String? section,
    String? marketingPersonCode,
    String? marketingPersonName,
    required double amount,
    required DateTime fromDate,
    required DateTime toDate,
    String? description,
    String? receiptFilePath,
  }) async {
    final payload = await _apiService.createExpense(
      section: section,
      marketingPersonCode: marketingPersonCode,
      marketingPersonName: marketingPersonName,
      amount: amount,
      fromDate: fromDate,
      toDate: toDate,
      description: description,
      receiptFilePath: receiptFilePath,
    );
    if (payload == null) return null;
    final data = _asMap(payload['data']) ?? _asMap(payload['expense']);
    if (data == null && payload['id'] != null) {
      return Expense.fromMap(payload);
    }
    return data == null ? null : Expense.fromMap(data);
  }

  Future<Expense?> updatePersonalExpense({
    required int expenseId,
    required double amount,
    required DateTime fromDate,
    required DateTime toDate,
    String? marketingPersonName,
    String? description,
    String? receiptFilePath,
  }) async {
    final payload = await _apiService.updatePersonalExpense(
      expenseId: expenseId,
      amount: amount,
      fromDate: fromDate,
      toDate: toDate,
      marketingPersonName: marketingPersonName,
      description: description,
      receiptFilePath: receiptFilePath,
    );
    if (payload == null) return null;
    final data = _asMap(payload['data']) ?? _asMap(payload['expense']);
    if (data == null && payload['id'] != null) {
      return Expense.fromMap(payload);
    }
    return data == null ? null : Expense.fromMap(data);
  }

  Future<bool> deletePersonalExpense(int expenseId) {
    return _apiService.deletePersonalExpense(expenseId);
  }

  Future<Map<String, dynamic>?> sendPersonalExpensesForApproval({
    int? month,
    int? year,
  }) {
    return _apiService.sendPersonalExpensesForApproval(
        month: month, year: year);
  }

  List<Expense> _parseExpenses(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Expense.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (raw is Map && raw['data'] is List) {
      return _parseExpenses(raw['data']);
    }
    return const [];
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
