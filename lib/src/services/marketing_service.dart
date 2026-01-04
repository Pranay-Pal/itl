import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/features/bookings/models/marketing_overview.dart';
import 'package:itl/src/features/reports/models/report_model.dart';
import 'package:itl/src/features/invoices/models/invoice_model.dart';
import 'package:itl/src/features/expenses/models/expense_model.dart';
import 'package:itl/src/features/reports/models/pending_report_model.dart';
import 'package:itl/src/features/expenses/models/checked_in_expense_model.dart';
import 'package:itl/src/features/profile/models/marketing_profile_model.dart';

class MarketingService {
  final ApiService _apiService = ApiService();

  // Helper to get headers with token
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_apiService.token}',
    };
  }

  Future<BookingFlatResponse> getBookings({
    required String userCode,
    int page = 1,
    String? search,
    String? paymentOption,
    int? month,
    int? year,
    int perPage = 25,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    // "Show Booking" uses /bookings/by-letter (Showbookings.txt) - Returns items
    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/bookings/by-letter')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching flat bookings: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      if (page == 1) {
        debugPrint(
            'Bookings API Response (First 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return BookingFlatResponse.fromJson(json['data']);
      }
      return BookingFlatResponse(
          items: [], total: 0, currentPage: 1, lastPage: 1, perPage: perPage);
    } else {
      throw Exception(
          'Failed to load bookings: ${response.statusCode} ${response.body}');
    }
  }

  Future<BookingGroupedResponse> getBookingsByLetter({
    required String userCode,
    int page = 1,
    String? search,
    int? month,
    int? year,
    int perPage = 25,
    int? department,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (department != null) 'department': department.toString(),
    };

    // "By Letter" uses /bookings/showbooking (Bookingsbyletter.txt) - Returns grouped bookings
    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/bookings/showbooking')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching bookings by letter: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return BookingGroupedResponse.fromJson(json['data']);
      }
      return BookingGroupedResponse(
          bookings: [],
          total: 0,
          currentPage: 1,
          lastPage: 1,
          perPage: perPage);
    } else {
      throw Exception(
          'Failed to load letters: ${response.statusCode} ${response.body}');
    }
  }

  Future<MarketingOverview> getOverview({
    required String userCode,
    int? month,
    int? year,
  }) async {
    final queryParams = {
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-dashboard/$userCode/overview')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching marketing overview: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      return MarketingOverview.fromJson(json);
    } else {
      throw Exception(
          'Failed to load overview: ${response.statusCode} ${response.body}');
    }
  }

  Future<MarketingProfileResponse> getProfile(
      {required String userCode}) async {
    final uri =
        Uri.parse('${ApiService.baseUrl}/marketing-person/$userCode/profile');

    debugPrint('Fetching profile: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      return MarketingProfileResponse.fromJson(json);
    } else {
      throw Exception(
          'Failed to load profile: ${response.statusCode} ${response.body}');
    }
  }

  Future<InvoiceResponse> getInvoices({
    required String userCode,
    int page = 1,
    int perPage = 25,
    String? search,
    int? month,
    int? year,
    String? paymentStatus,
    int? clientId,
    String? generatedStatus,
    int? department,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (clientId != null) 'client_id': clientId.toString(),
      if (generatedStatus != null) 'generated_status': generatedStatus,
      if (department != null) 'department': department.toString(),
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/invoices/list')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching invoices: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      if (page == 1) {
        debugPrint(
            'Invoices API Response (First 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return InvoiceResponse.fromJson(json['data']);
      }
      // Fallback empty
      return InvoiceResponse(
          invoices: [],
          total: 0,
          perPage: perPage,
          currentPage: 1,
          lastPage: 1);
    } else {
      throw Exception(
          'Failed to load invoices: ${response.statusCode} ${response.body}');
    }
  }

  Future<BookingGroupedResponse> getPendingInvoices({
    required String userCode,
    int page = 1,
    int perPage = 25,
    String? search,
    int? month,
    int? year,
    int? department,
    int? clientId,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (department != null) 'department': department.toString(),
      if (clientId != null) 'client_id': clientId.toString(),
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/bookings/generate-invoice')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching pending invoices: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return BookingGroupedResponse.fromJson(json['data']);
      }
      return BookingGroupedResponse(
          bookings: [],
          total: 0,
          perPage: perPage,
          currentPage: 1,
          lastPage: 1);
    } else {
      throw Exception(
          'Failed to load pending invoices: ${response.statusCode} ${response.body}');
    }
  }

  Future<ExpenseResponse> getExpenses({
    required String userCode,
    int page = 1,
    int perPage = 25,
    String? search,
    int? month,
    int? year,
    String? section,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (section != null) 'section': section,
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/personal/expenses')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching expenses: $uri');

    final response = await http.get(uri, headers: _headers);

    debugPrint('Expenses API Status: ${response.statusCode}');
    debugPrint('Expenses API Body: ${response.body}');

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      if (json is Map<String, dynamic>) {
        return ExpenseResponse.fromJson(json);
      } else if (json is Map) {
        return ExpenseResponse.fromJson(Map<String, dynamic>.from(json));
      } else {
        throw Exception(
            'Invalid response format: expected object, got ${json.runtimeType}');
      }
    } else {
      throw Exception(
          'Failed to load expenses: ${response.statusCode} ${response.body}');
    }
  }

  Future<ExpenseItem?> createExpense({
    required String userCode,
    required double amount,
    String? section,
    String? fromDate,
    String? description,
    String? filePath,
  }) async {
    final uri = Uri.parse(
        '${ApiService.baseUrl}/marketing-person/$userCode/personal/expenses');

    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_apiService.token}',
    });

    request.fields['amount'] = amount.toString();
    if (section != null) request.fields['section'] = section;
    if (fromDate != null) request.fields['from_date'] = fromDate;
    if (description != null) request.fields['description'] = description;

    if (filePath != null) {
      // API accepts 'file' or 'pdf'
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    debugPrint('Creating expense: $uri');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint(
        'Create Expense Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // Response shape: { success: true, data: {...}, submitted_for_approval: bool }
      if (json['data'] != null) {
        return ExpenseItem.fromJson(json['data']);
      }
      return ExpenseItem.fromJson(json);
    } else {
      throw Exception('Failed to create expense: ${response.body}');
    }
  }

  Future<ReportResponse> getReports({
    required String userCode,
    int page = 1,
    String? search,
    int? month,
    int? year,
    int perPage = 25,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/reports/by-job-order')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching reports: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return ReportResponse.fromJson(json['data']);
      }
      return ReportResponse(
          items: [], total: 0, perPage: perPage, currentPage: 1, lastPage: 1);
    } else {
      throw Exception(
          'Failed to load reports: ${response.statusCode} ${response.body}');
    }
  }

  Future<BookingGroupedResponse> getReportsByLetter({
    required String userCode,
    int page = 1,
    String? search,
    int? month,
    int? year,
    int perPage = 25,
    int? department,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (department != null) 'department': department.toString(),
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/bookings/view-by-letter')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching reports by letter: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return BookingGroupedResponse.fromJson(json['data']);
      }
      return BookingGroupedResponse(
          bookings: [],
          total: 0,
          currentPage: 1,
          lastPage: 1,
          perPage: perPage);
    } else {
      throw Exception(
          'Failed to load reports by letter: ${response.statusCode} ${response.body}');
    }
  }

  Future<PendingResponse> getPendingReports({
    required String userCode,
    String mode = 'job',
    int page = 1,
    int perPage = 25,
    String? search,
    int? month,
    int? year,
    bool overdue = false,
    int? department,
  }) async {
    final queryParams = {
      'mode': mode,
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (overdue) 'overdue': '1',
      if (department != null) 'department': department.toString(),
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/reports/pendings')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching pending reports ($mode): $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      if (json['data'] != null) {
        return PendingResponse.fromJson(json['data']);
      }
      return PendingResponse(
        total: 0,
        perPage: perPage,
        currentPage: 1,
        lastPage: 1,
      );
    } else {
      throw Exception(
          'Failed to load pending reports: ${response.statusCode} ${response.body}');
    }
  }

  Future<CheckedInExpenseResponse> getCheckedInExpenses({
    int page = 1,
    int perPage = 15,
    String? search,
    int? month,
    int? year,
    bool mine = true,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (mine) 'mine': '1',
      if (search != null && search.isNotEmpty) 'search': search,
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
    };

    final uri =
        Uri.parse('${ApiService.baseUrl}/superadmin/personal/checked-in')
            .replace(queryParameters: queryParams);

    debugPrint('Fetching checked-in expenses: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = await _apiService.parseJson(response.body);
      // The API response structure matches CheckedInExpenseResponse.fromJson
      return CheckedInExpenseResponse.fromJson(json);
    } else {
      throw Exception(
          'Failed to load checked-in expenses: ${response.statusCode} ${response.body}');
    }
  }

  Future<ExpenseItem?> updateExpense({
    required int id,
    required double amount,
    String? section,
    String? fromDate,
    String? toDate,
    String? description,
    String? filePath,
  }) async {
    // Laravel often requires POST with _method=PUT for multipart updates
    final uri = Uri.parse('${ApiService.baseUrl}/expenses/$id');

    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_apiService.token}',
    });

    request.fields['_method'] = 'PUT';
    request.fields['amount'] = amount.toString();
    if (toDate != null) request.fields['to_date'] = toDate;
    if (section != null) request.fields['section'] = section;
    if (fromDate != null) request.fields['from_date'] = fromDate;
    if (description != null) request.fields['description'] = description;

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    debugPrint('Updating expense: $uri');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint(
        'Update Expense Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      // final json = jsonDecode(response.body);
      // Response { success: true, data: { expense: {...} } ... } ???
      // Docs say: { success: true, rowHtml, dailyRowHtml, amount, approved_amount ... }
      // It might NOT return the full object in valid structure.
      // We will parse what we can or return null to trigger reload.
      debugPrint('Expense updated successfully');
      return null;
    } else {
      throw Exception('Failed to update expense: ${response.body}');
    }
  }

  Future<void> deleteExpense(int id) async {
    final uri = Uri.parse('${ApiService.baseUrl}/expenses/$id');
    debugPrint('Deleting expense: $uri');

    final response = await http.delete(uri, headers: _headers);

    debugPrint('Delete Expense Response: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      throw Exception('Failed to delete expense: ${response.body}');
    }
  }
}
