import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/meter/models/meter_reading_model.dart';
import 'dart:convert';

class MeterService {
  final ApiService _apiService = ApiService();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${_apiService.token}',
      };

  Future<MeterResponse> getReadings({
    int page = 1,
    int perPage = 25,
    String? search,
    int? month,
    int? year,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
    };

    final uri = Uri.parse('${ApiService.baseUrl}/meter-reading')
        .replace(queryParameters: queryParams);

    debugPrint('Fetching meter readings: $uri');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response
          .body); // Using direct jsonDecode for custom structure validation if needed
      return MeterResponse.fromJson(json);
    } else {
      throw Exception('Failed to load meter readings: ${response.statusCode}');
    }
  }

  Future<void> uploadReading({
    required double currentReading,
    String? description,
    String? filePath,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/meter-reading/upload');

    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_apiService.token}',
    });

    request.fields['current_reading'] = currentReading.toString();
    if (description != null) request.fields['description'] = description;

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('image', filePath));
    }

    debugPrint('Uploading meter reading (Start/Stop): $uri');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint(
        'Upload Reading Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Success
      return;
    } else {
      final json = jsonDecode(response.body);
      final message = json['message'] ?? response.body;
      throw Exception('Failed to upload reading: $message');
    }
  }
}
