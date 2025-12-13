import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/bookings/models/booking_model.dart';

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

  Future<BookingResponse> getBookings({
    required String userCode,
    int page = 1,
    String? search,
    String? paymentOption,
    int? month,
    int? year,
  }) async {
    // Determine query params
    // API docs: /bookings?month=&year=&page=
    // For search, assuming API handles it or we might need to filter client side if not supported?
    // Docs say: "Filters: payment_option, invoice_status, month, year, page."
    // Docs don't explicitly list 'search' or 'q'. The user mentioned "there is also a search feature so keep a search box".
    // I will try adding 'search' param, if it fails I'll mention it.

    final queryParams = {
      'page': page.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (paymentOption != null) 'payment_option': paymentOption,
    };

    final uri =
        Uri.parse('${ApiService.baseUrl}/marketing-person/$userCode/bookings')
            .replace(queryParameters: queryParams);

    // Using http directly for more control or reuse apiService? ApiService doesn't expose generic get helper well (it has specific methods).
    // I'll make a direct call using the token from ApiService.

    debugPrint('Fetching bookings: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      // Log first response for debugging fields
      if (page == 1) {
        debugPrint(
            'Bookings API Response (First 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }
      final json = jsonDecode(response.body);
      // /bookings structure: data -> data (paginator)
      if (json['data'] != null) {
        return BookingResponse.fromJson(json['data']);
      }
      return BookingResponse(data: [], currentPage: 1, lastPage: 1);
    } else {
      throw Exception(
          'Failed to load bookings: ${response.statusCode} ${response.body}');
    }
  }

  Future<BookingResponse> getBookingsByLetter({
    required String userCode,
    int page = 1,
    String? search,
    int? month,
    int? year,
  }) async {
    final queryParams = {
      'page': page.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      // For "Booking By Letter", docs say: /bookings/without-bill
      // "Bookings with WITHOUT_BILL payment option."
    };

    final uri = Uri.parse(
            '${ApiService.baseUrl}/marketing-person/$userCode/bookings/without-bill')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching bookings by letter: $uri');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // /bookings/without-bill structure: data -> bookings -> data
      if (json['data'] != null && json['data']['bookings'] != null) {
        return BookingResponse.fromJson(json['data']['bookings']);
      }
      // Fallback
      return BookingResponse(data: [], currentPage: 1, lastPage: 1);
    } else {
      throw Exception(
          'Failed to load letters: ${response.statusCode} ${response.body}');
    }
  }
}
