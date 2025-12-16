import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/features/bookings/models/marketing_overview.dart';
import 'package:itl/src/features/invoices/models/invoice_model.dart';
import 'package:itl/src/features/expenses/models/expense_model.dart';

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
      final json = jsonDecode(response.body);
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
  }) async {
    final queryParams = {
      'page': page.toString(),
      'perPage': perPage.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      // Docs mention 'marketing' or 'department' query params if needed, ignored for now.
    };

    // "By Letter" uses /bookings/showbooking (Bookingsbyletter.txt) - Returns grouped bookings
    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/bookings/showbooking')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching bookings by letter: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
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

  Future<MarketingOverview> getOverview({required String userCode}) async {
    final uri = Uri.parse(
        '${ApiService.baseUrl}/marketing-dashboard/$userCode/overview');

    debugPrint('Fetching marketing overview: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return MarketingOverview.fromJson(json);
    } else {
      throw Exception(
          'Failed to load overview: ${response.statusCode} ${response.body}');
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
      final json = jsonDecode(response.body);
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
      final json = jsonDecode(response.body);
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
    String? expenseDate,
    String? description,
    String? filePath,
  }) async {
    final uri = Uri.parse(
        '${ApiService.baseUrl}/marketing-person/$userCode/personal/expenses');

    var request = http.MultipartRequest('POST', uri);
    // Headers must include auth, but Content-type for multipart is set automatically by request
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_apiService.token}',
      // Do NOT set Content-Type here, http package handles it with boundary
    });

    request.fields['amount'] = amount.toString();
    if (section != null) request.fields['section'] = section;
    if (expenseDate != null) request.fields['expense_date'] = expenseDate;
    if (description != null) request.fields['description'] = description;

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    debugPrint('Creating expense: $uri');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['data'] != null) {
        return ExpenseItem.fromJson(json['data']);
      }
      return ExpenseItem.fromJson(json);
    } else {
      debugPrint('Failed to create expense: ${response.body}');
      throw Exception('Failed to create expense: ${response.body}');
    }
  }
}
