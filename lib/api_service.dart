import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String _baseUrl =
      "https://mediumslateblue-hummingbird-258203.hostingersite.com/api";
  String? _token;
  String? _userType;

  Future<void> _loadToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      // Strictly read the canonical key 'access_token'
      _token = prefs.getString('access_token');
      _userType = prefs.getString('user_type');
    }
  }

  Map<String, String> _defaultHeaders({bool includeAuth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  void _logRequest(
    String method,
    String url,
    Map<String, String> headers,
    dynamic body,
  ) {
    if (!kDebugMode) return;
    print('--- API REQUEST ---');
    print('Method: $method');
    print('URL: $url');
    print('Headers: ${jsonEncode(headers)}');
    print('Body: ${body == null ? 'null' : jsonEncode(body)}');
    print('-------------------');
  }

  void _logResponse(String url, http.Response response) {
    if (!kDebugMode) return;
    print('--- API RESPONSE ---');
    print('URL: $url');
    print('Status: ${response.statusCode}');
    try {
      print('Body: ${response.body}');
    } catch (e) {
      print('Body: <unprintable>');
    }
    print('--------------------');
  }

  // Login for user or admin
  Future<Map<String, dynamic>> login(
    String identifier,
    String password,
    String userType,
  ) async {
    final String url = userType == 'admin'
        ? '$_baseUrl/admin/login'
        : '$_baseUrl/user/login';
    final Map<String, String> body = userType == 'admin'
        ? {'email': identifier, 'password': password}
        : {'user_code': identifier, 'password': password};

    final headers = _defaultHeaders();
    _logRequest('POST', url, headers, body);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response);

    final int status = response.statusCode;
    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(response.body);
    } catch (e) {
      parsedBody = response.body;
    }

    if (status == 200 &&
        parsedBody is Map &&
        parsedBody['access_token'] != null) {
      _token = parsedBody['access_token'];
      _userType = userType;
      final prefs = await SharedPreferences.getInstance();
      // Save under the canonical key only
      await prefs.setString('access_token', _token!);
      await prefs.setString('user_type', _userType!);
      return {'success': true, 'statusCode': status, 'body': parsedBody};
    }

    return {'success': false, 'statusCode': status, 'body': parsedBody};
  }

  // Get chat groups
  Future<List<dynamic>> getChatGroups() async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/groups'
        : '$_baseUrl/chat/groups';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] is List) {
        return data['data'];
      }
    }
    return [];
  }

  // Create chat group
  Future<Map<String, dynamic>?> createGroup(String name) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/groups'
        : '$_baseUrl/chat/groups';
    final body = {'name': name};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  // Get messages for a group (supports pagination via query params if needed)
  Future<Map<String, dynamic>> getMessages(int groupId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages?group_id=$groupId'
        : '$_baseUrl/chat/messages?group_id=$groupId';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data;
      }
    }
    return {};
  }

  // Send message
  Future<Map<String, dynamic>?> sendMessage(int groupId, String content) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages'
        : '$_baseUrl/chat/messages';
    final body = {'group_id': groupId, 'type': 'text', 'content': content};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  // React to a message
  Future<Map<String, dynamic>?> reactToMessage(
    int messageId,
    String type,
  ) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/reactions'
        : '$_baseUrl/chat/messages/$messageId/reactions';
    final body = {'type': type};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  // Get unread counts
  Future<Map<String, dynamic>?> getUnreadCounts() async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/unread-counts'
        : '$_baseUrl/chat/unread-counts';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  // Search users
  Future<List<dynamic>> searchUsers(String q) async {
    await _loadToken();
    final encoded = Uri.encodeQueryComponent(q);
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/users/search?q=$encoded'
        : '$_baseUrl/chat/users/search?q=$encoded';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] is List) return data['data'];
    }
    return [];
  }

  // Logout: clear stored tokens and user type
  Future<void> logout() async {
    _token = null;
    _userType = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_type');
  }
}
