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
      if (data is List) {
        return data;
      } else if (data['success'] == true && data['data'] is List) {
        return data['data'];
      }
    }
    return [];
  }

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

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  Future<Map<String, dynamic>> getMessages(int groupId, {int page = 1}) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages?group_id=$groupId&page=$page'
        : '$_baseUrl/chat/messages?group_id=$groupId&page=$page';
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

    Future<Map<String, dynamic>?> getSingleMessage(int messageId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId'
        : '$_baseUrl/chat/messages/$messageId';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<dynamic>> getMessagesSince(int groupId, int afterId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/since?group_id=$groupId&after_id=$afterId'
        : '$_baseUrl/chat/messages/since?group_id=$groupId&after_id=$afterId';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }


  Future<Map<String, dynamic>?> sendMessage(int groupId, String content, {String type = 'text'}) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages'
        : '$_baseUrl/chat/messages';
    final body = {
      'group_id': groupId,
      'type': type,
      'content': content,
    };
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> replyToMessage(int messageId, String content, {String type = 'text'}) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/reply'
        : '$_baseUrl/chat/messages/$messageId/reply';
    final body = {
      'type': type,
      'content': content,
    };
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> uploadFile(int groupId, String filePath, {String type = 'image', int? replyToMessageId}) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/upload'
        : '$_baseUrl/chat/messages/upload';

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $_token';
    request.fields['group_id'] = groupId.toString();
		request.fields['type'] = type;

    final file = await http.MultipartFile.fromPath('file', filePath);
    request.files.add(file);

    if (replyToMessageId != null) {
      request.fields['reply_to_message_id'] = replyToMessageId.toString();
    }

    final response = await request.send();

    if (response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    }
    return null;
  }

  Future<bool> markAsSeen(int groupId, int lastId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/mark-seen'
        : '$_baseUrl/chat/mark-seen';
    final body = {'group_id': groupId, 'last_id': lastId};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    _logResponse(url, response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    }
    return false;
  }

  Future<bool> deleteMessage(int messageId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId'
        : '$_baseUrl/chat/messages/$messageId';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('DELETE', url, headers, null);

    final response = await http.delete(Uri.parse(url), headers: headers);
    _logResponse(url, response);

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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    }
    return false;
  }

    Future<bool> forwardMessage(int messageId, List<int> targetGroupIds) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/forward'
        : '$_baseUrl/chat/messages/$messageId/forward';
    final body = {'target_group_ids': targetGroupIds};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    _logResponse(url, response);

    return response.statusCode == 200;
  }

  Future<bool> setMessageStatus(int messageId, String status) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$messageId/status'
        : '$_baseUrl/chat/messages/$messageId/status';
    final body = {'status': status};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    _logResponse(url, response);

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>?> createDirectMessage(int userId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/direct-with/$userId'
        : '$_baseUrl/chat/direct-with/$userId';
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('GET', url, headers, null);

    final response = await http.get(Uri.parse(url), headers: headers);
    _logResponse(url, response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['id'] != null) {
        return {'id': data['id'], 'name': data['name']};
      }
    }
    return null;
  }

  Future<bool> setChatAdmin(int userId, bool isAdmin) async {
    await _loadToken();
    final url = '$_baseUrl/admin/chat/users/$userId/set-admin';
    final body = {'is_admin': isAdmin};
    final headers = _defaultHeaders(includeAuth: true);
    _logRequest('POST', url, headers, body);

    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    _logResponse(url, response);

    return response.statusCode == 200;
  }

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
      return jsonDecode(response.body);
    }
    return null;
  }

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
