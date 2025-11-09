import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String _baseUrl =
      "https://mediumslateblue-hummingbird-258203.hostingersite.com/api";
  String? _token;
  String? _userType;
  int? _userId;

  Future<void> _loadToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('access_token');
      _userType = prefs.getString('user_type');
      _userId = prefs.getInt('user_id');
    }
  }

  int? get currentUserId => _userId;
  String? get userType => _userType;

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
    debugPrint('--- API REQUEST ---');
    debugPrint('Method: $method');
    debugPrint('URL: $url');
    debugPrint('Headers: ${jsonEncode(headers)}');
    debugPrint('Body: ${body == null ? 'null' : jsonEncode(body)}');
    debugPrint('-------------------');
  }

  void _logResponse(String url, http.Response response) {
    if (!kDebugMode) return;
    debugPrint('--- API RESPONSE ---');
    debugPrint('URL: $url');
    debugPrint('Status: ${response.statusCode}');
    try {
      debugPrint('Body: ${response.body}');
    } catch (e) {
      debugPrint('Body: <unprintable>');
    }
    debugPrint('--------------------');
  }

  // Returns the expiry DateTime of the JWT if present, otherwise null.
  DateTime? _getTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      if (payloadMap is Map<String, dynamic> && payloadMap.containsKey('exp')) {
        final exp = payloadMap['exp'];
        if (exp is int) {
          return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
              .toLocal();
        } else if (exp is String) {
          final v = int.tryParse(exp);
          if (v != null) {
            return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true)
                .toLocal();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error decoding token expiry: $e');
    }
    return null;
  }

  // If token is present and expiring soon, attempt a refresh.
  // Returns true if token is valid after this call (either unchanged or refreshed).
  Future<bool> _ensureTokenValid() async {
    if (_token == null) return false;
    final expiry = _getTokenExpiry(_token!);
    // If expiry unknown, don't try to proactively refresh.
    if (expiry == null) return true;

    final now = DateTime.now();
    // Refresh if token is already expired or will expire within 5 minutes.
    const refreshBefore = Duration(minutes: 5);
    if (expiry.isBefore(now) || expiry.difference(now) <= refreshBefore) {
      if (kDebugMode) {
        debugPrint('Token is expired or expiring soon, attempting refresh...');
      }
      final refreshed = await refreshToken();
      return refreshed;
    }
    return true;
  }

  // Send an HTTP request with Authorization header and automatically retry once after a successful refresh if a 401 is received.
  Future<http.Response> _sendHttpWithAuthAndRetry(
    String method,
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    await _loadToken();
    await _ensureTokenValid();

    Map<String, String> reqHeaders = _defaultHeaders(includeAuth: true);
    if (headers != null) reqHeaders.addAll(headers);

    Future<http.Response> doRequest(Map<String, String> useHeaders) async {
      _logRequest(method, url, useHeaders, body);
      switch (method.toUpperCase()) {
        case 'GET':
          return await http.get(Uri.parse(url), headers: useHeaders);
        case 'POST':
          return await http.post(Uri.parse(url),
              headers: useHeaders,
              body: body == null ? null : jsonEncode(body));
        case 'DELETE':
          return await http.delete(Uri.parse(url), headers: useHeaders);
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }
    }

    var response = await doRequest(reqHeaders);
    _logResponse(url, response);

    if (response.statusCode == 401) {
      final didRefresh = await refreshToken();
      if (didRefresh) {
        final retryHeaders = _defaultHeaders(includeAuth: true);
        if (headers != null) retryHeaders.addAll(headers);
        response = await doRequest(retryHeaders);
        _logResponse(url, response);
      }
    }
    return response;
  }

  int? _getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);

      if (payloadMap is Map<String, dynamic> && payloadMap.containsKey('sub')) {
        return int.tryParse(payloadMap['sub'].toString());
      }
    } catch (e) {
      debugPrint("Error decoding token: $e");
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>> login(
    String identifier,
    String password,
    String userType,
  ) async {
    final String url =
        userType == 'admin' ? '$_baseUrl/admin/login' : '$_baseUrl/user/login';
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

      if (parsedBody.containsKey('user') && parsedBody['user']['id'] != null) {
        _userId = parsedBody['user']['id'];
      } else {
        _userId = _getUserIdFromToken(_token!);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _token!);
      await prefs.setString('user_type', _userType!);
      if (_userId != null) {
        await prefs.setInt('user_id', _userId!);
      } else {
        await prefs.remove('user_id');
      }

      return {'success': true, 'statusCode': status, 'body': parsedBody};
    }

    return {'success': false, 'statusCode': status, 'body': parsedBody};
  }

  Future<List<dynamic>> getChatGroups() async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/groups'
        : '$_baseUrl/chat/groups';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      } else if (data['success'] == true && data['data'] is List) {
        return data['data'];
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> createGroup(String name) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/groups'
        : '$_baseUrl/chat/groups';
    final body = {'name': name};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  Future<Map<String, dynamic>> getMessages(int groupId, {int page = 1}) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages?group_id=$groupId&page=$page'
        : '$_baseUrl/chat/messages?group_id=$groupId&page=$page';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>?> getSingleMessage(int messageId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId'
        : '$_baseUrl/chat/messages/$messageId';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<dynamic>> getMessagesSince(int groupId, int afterId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/since?group_id=$groupId&after_id=$afterId'
        : '$_baseUrl/chat/messages/since?group_id=$groupId&after_id=$afterId';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>?> sendMessage(int groupId, String content,
      {String type = 'text'}) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages'
        : '$_baseUrl/chat/messages';
    final body = {
      'group_id': groupId,
      'type': type,
      'content': content,
    };

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> replyToMessage(int messageId, String content,
      {String type = 'text'}) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/reply'
        : '$_baseUrl/chat/messages/$messageId/reply';
    final body = {
      'type': type,
      'content': content,
    };

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> uploadFile(int groupId, String filePath,
      {String type = 'image', int? replyToMessageId}) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/upload'
        : '$_baseUrl/chat/messages/upload';

    Future<http.StreamedResponse> makeRequest() async {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['group_id'] = groupId.toString();
      request.fields['type'] = type;

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      if (replyToMessageId != null) {
        request.fields['reply_to_message_id'] = replyToMessageId.toString();
      }

      return await request.send();
    }

    await _ensureTokenValid();

    var response = await makeRequest();

    // If unauthorized, try refreshing and retry once.
    if (response.statusCode == 401) {
      final didRefresh = await refreshToken();
      if (didRefresh) {
        response = await makeRequest();
      }
    }

    if (response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    }
    return null;
  }

  Future<bool> markAsSeen(int groupId, int lastId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/mark-seen'
        : '$_baseUrl/chat/mark-seen';
    final body = {'group_id': groupId, 'last_id': lastId};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    }
    return false;
  }

  Future<bool> deleteMessage(int messageId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId'
        : '$_baseUrl/chat/messages/$messageId';

    final response = await _sendHttpWithAuthAndRetry('DELETE', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'deleted';
    }
    return false;
  }

  Future<bool> reactToMessage(
    int messageId,
    String type,
  ) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/reactions'
        : '$_baseUrl/chat/messages/$messageId/reactions';
    final body = {'type': type};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    }
    return false;
  }

  Future<bool> forwardMessage(int messageId, List<int> targetGroupIds) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/forward'
        : '$_baseUrl/chat/messages/$messageId/forward';
    final body = {'target_group_ids': targetGroupIds};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    return response.statusCode == 200;
  }

  Future<bool> setMessageStatus(int messageId, String status) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/status'
        : '$_baseUrl/chat/messages/$messageId/status';
    final body = {'status': status};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>?> createDirectMessage(int userId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/direct-with/$userId'
        : '$_baseUrl/chat/direct-with/$userId';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['id'] != null) {
        return {'id': data['id'], 'name': data['name']};
      }
    }
    return null;
  }

  Future<bool> setChatAdmin(int userId, bool isAdmin) async {
    final url = '$_baseUrl/admin/chat/users/$userId/set-admin';
    final body = {'is_admin': isAdmin};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>?> getUnreadCounts() async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/unread-counts'
        : '$_baseUrl/chat/unread-counts';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Refresh the current access token using the appropriate guard endpoint.
  ///
  /// Returns true if refresh succeeded and the new token was saved.
  Future<bool> refreshToken() async {
    await _loadToken();
    if (_token == null) return false;

    final url = _userType == 'admin'
        ? '$_baseUrl/admin/refresh'
        : '$_baseUrl/user/refresh';
    // _defaultHeaders(includeAuth: true) will include Authorization: Bearer <token>
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, null);

    final response = await http.post(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['access_token'] != null) {
          _token = data['access_token'];

          // Try to obtain user id from returned body if provided, otherwise decode token
          if (data.containsKey('user') && data['user']?['id'] != null) {
            _userId = data['user']['id'];
          } else {
            final id = _getUserIdFromToken(_token!);
            if (id != null) _userId = id;
          }

          // Persist updated token & user info
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', _token!);
          if (_userType != null) await prefs.setString('user_type', _userType!);
          if (_userId != null) {
            await prefs.setInt('user_id', _userId!);
          } else {
            await prefs.remove('user_id');
          }

          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error parsing refresh response: $e');
      }
    }

    return false;
  }

  Future<List<dynamic>> searchUsers(String q) async {
    final encoded = Uri.encodeQueryComponent(q);
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/users/search?q=$encoded'
        : '$_baseUrl/chat/users/search?q=$encoded';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] is List) {
        return data['data'];
      }
    }
    return [];
  }

  Future<void> logout() async {
    _token = null;
    _userType = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_type');
    await prefs.remove('user_id');
  }
}
