import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itl/src/config/base_url.dart' as config;
import 'package:itl/src/features/chat/models/chat_models.dart';

class ApiService {
  // Make ApiService a singleton so token/state is shared across the app
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = "${config.baseUrl}/api";
  final String _baseUrl = baseUrl;
  String? _token;
  String? _userType;
  int? _userId;
  String? _userCode;
  String? _userName;

  // Public method to load persisted token/state; can be awaited at app startup
  Future<void> ensureInitialized() async {
    await _loadToken();
  }

  /// Helper to offload JSON decoding to a background isolate.
  /// Useful for large API responses to avoid jank.
  Future<dynamic> parseJson(String responseBody) {
    return compute(_parseAndDecode, responseBody);
  }

  Future<void> _loadToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('access_token');
      _userType = prefs.getString('user_type');
      _userId = prefs.getInt('user_id');
      _userCode = prefs.getString('user_code');
      _userName = prefs.getString('user_name');
    }
  }

  int? get currentUserId => _userId;
  String? get userType => _userType;
  String? get userCode => _userCode;
  String? get userName => _userName;
  String? get token => _token;

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

  String _formatDateParam(DateTime date) {
    final iso = date.toIso8601String();
    final separatorIndex = iso.indexOf('T');
    return separatorIndex == -1 ? iso : iso.substring(0, separatorIndex);
  }

  Future<Map<String, dynamic>?> _sendExpenseMultipart(
    String method,
    String url,
    Map<String, String> fields, {
    String? receiptFilePath,
  }) async {
    await _loadToken();
    await _ensureTokenValid();

    Future<http.StreamedResponse> makeRequest() async {
      final request = http.MultipartRequest(method, Uri.parse(url));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.fields.addAll(fields);
      if (receiptFilePath != null && receiptFilePath.isNotEmpty) {
        final file = await http.MultipartFile.fromPath('pdf', receiptFilePath);
        request.files.add(file);
      }
      return request.send();
    }

    var response = await makeRequest();

    if (response.statusCode == 401) {
      final didRefresh = await refreshToken();
      if (didRefresh) {
        response = await makeRequest();
      }
    }

    final responseBody = await response.stream.bytesToString();
    Map<String, dynamic>? decoded;
    try {
      final jsonMap = jsonDecode(responseBody);
      if (jsonMap is Map<String, dynamic>) {
        decoded = jsonMap;
      }
    } catch (_) {}

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }
    return decoded;
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

      Map<String, dynamic>? userMap;
      if (parsedBody.containsKey('user') && parsedBody['user'] is Map) {
        userMap = Map<String, dynamic>.from(parsedBody['user']);
      }

      if (userMap != null && userMap['id'] != null) {
        _userId = userMap['id'];
        _userName = _extractUserName(userMap);
        // Capture user_code/marketing code for normal users if present
        if (userType == 'user') {
          _userCode = (userMap['user_code'] ?? userMap['code'] ?? identifier)
              .toString();
        } else {
          _userCode = null;
        }
      } else {
        _userId = _getUserIdFromToken(_token!);
        _userCode = userType == 'user' ? identifier : null;
        _userName = null;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _token!);
      await prefs.setString('user_type', _userType!);
      if (_userId != null) {
        await prefs.setInt('user_id', _userId!);
      } else {
        await prefs.remove('user_id');
      }
      if (_userCode != null && userType == 'user') {
        await prefs.setString('user_code', _userCode!);
      } else {
        await prefs.remove('user_code');
      }
      if (_userName != null) {
        await prefs.setString('user_name', _userName!);
      } else {
        await prefs.remove('user_name');
      }

      // After successful login, get and send the device token.
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          if (kDebugMode) {
            print("========================================================");
            print("==  LOGGED IN: SENDING DEVICE TOKEN TO BACKEND   ==");
            print("========================================================");
            print("FCM Token: $fcmToken");
            print("========================================================");
          }
          await updateDeviceToken(fcmToken);
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error getting or sending FCM token: $e");
        }
      }

      return {'success': true, 'statusCode': status, 'body': parsedBody};
    }

    return {'success': false, 'statusCode': status, 'body': parsedBody};
  }

  Future<List<ChatContact>> getChatContacts() async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/contacts'
        : '$_baseUrl/chat/contacts';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((e) => ChatContact.fromJson(e)).toList();
      } else if (data['data'] is List) {
        return (data['data'] as List)
            .map((e) => ChatContact.fromJson(e))
            .toList();
      }
    }
    return [];
  }

  // Deprecated: use getChatContacts
  Future<List<dynamic>> getChatGroups() async {
    return await getChatContacts();
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

  Future<List<ChatMessage>> getMessages(String contactId,
      {int page = 1}) async {
    // contactId formatting handled by caller or we can enforce here
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/$contactId?page=$page'
        : '$_baseUrl/chat/messages/$contactId?page=$page';

    // Note: If API query param for mark read is needed, append &mark_read=1
    // e.g. '$_baseUrl/chat/messages/$contactId?page=$page&mark_read=1';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Determine if we have {data: [...], ...} or just [...]
      List<dynamic> listData = [];
      if (data is List) {
        listData = data;
      } else if (data['data'] is List) {
        listData = data['data'];
      }

      // If fetched Messages is wrapped in a pagination object
      // it might be data['data'] -> List

      return listData
          .map((e) => ChatMessage.fromJson(e, currentUserId: _userId))
          .toList();
    }
    return [];
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

  Future<ChatMessage?> sendMessage(String receiverId, String content,
      {String? receiverType, int? replyToId}) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages'
        : '$_baseUrl/chat/messages';

    // receiverType defaults to 'user' if not known, or caller should provide
    // The API seems to require receiver_id and receiver_type
    // If receiverId is like "user:1", we might not need type if API parses it,
    // BUT docs say: "receiver_id": "user:36", "receiver_type": "user"

    final Map<String, dynamic> body = {
      'receiver_id': receiverId,
      'receiver_type': receiverType ?? 'user', // Basic fallback
      'content': content,
    };
    if (replyToId != null) {
      body['reply_to'] = replyToId;
    }

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Return Message object
      return ChatMessage.fromJson(data, currentUserId: _userId);
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

  Future<ChatMessage?> uploadChatFile(
    String receiverId,
    String receiverType,
    String filePath, {
    int? replyToId,
    String? content,
  }) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages'
        : '$_baseUrl/chat/messages';

    Future<http.StreamedResponse> makeRequest() async {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $_token';

      request.fields['receiver_id'] = receiverId;
      request.fields['receiver_type'] = receiverType;

      if (content != null) {
        request.fields['content'] = content;
      }
      if (replyToId != null) {
        request.fields['reply_to'] = replyToId.toString();
      }

      // Detect if audio or generic file
      final isAudio = ['mp3', 'wav', 'm4a', 'aac', 'ogg']
          .contains(filePath.split('.').last.toLowerCase());

      final fieldName =
          isAudio ? 'audio' : 'files[]'; // API docs say files[] for generic

      final file = await http.MultipartFile.fromPath(fieldName, filePath);
      request.files.add(file);

      return await request.send();
    }

    await _ensureTokenValid();
    var response = await makeRequest();

    if (response.statusCode == 401) {
      final didRefresh = await refreshToken();
      if (didRefresh) response = await makeRequest();
    }

    if (response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      return ChatMessage.fromJson(data, currentUserId: _userId);
    }
    return null;
  }

  // Deprecated shim
  Future<Map<String, dynamic>?> uploadFile(int groupId, String filePath,
      {String type = 'file', int? replyToMessageId, String? content}) async {
    // Shim to new method: assume group
    await uploadChatFile(
      'group:$groupId',
      'group',
      filePath,
      replyToId: replyToMessageId,
      content: content,
    );
    // Return map to attempt backward compat or null
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

  Future<bool> toggleReaction(int messageId, String emoji) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages/reaction'
        : '$_baseUrl/chat/messages/reaction';
    final body = {'message_id': messageId, 'emoji': emoji};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['acted'] == true;
    }
    return false;
  }

  // Deprecated OLD way
  Future<bool> reactToMessage(
    int messageId,
    String type,
  ) async {
    return await toggleReaction(messageId, type);
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

  Future<bool> sendTyping(String contactId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/typing'
        : '$_baseUrl/chat/typing';

    // We need to send receiver_id and receiver_type
    // If contactId is "user:123" or "group:456"
    String receiverId = contactId;
    String receiverType = 'user';

    if (contactId.contains(':')) {
      // e.g. group:123
      final parts = contactId.split(':');
      receiverType = parts[0];
      // receiverId usually expects just the ID if type is separate, OR the full string?
      // Based on sendMessage using receiver_id and receiver_type separately:
      receiverId = contactId; // Or parts[1]?
      // Docs: "receiver_id": "user:36", "receiver_type": "user"
      // So receiver_id includes prefix if following that pattern?
      // Wait, sendMessage uses:
      // 'receiver_id': receiverId, (passed as arg)
      // 'receiver_type': receiverType
      // Let's assume receiverId is the full string "user:123" based on current usage.
    }

    final body = {
      'receiver_id': receiverId,
      'receiver_type': receiverType,
    };

    // Fire and forget, don't retry heavily
    try {
      final headers = _defaultHeaders(includeAuth: true);
      http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> createDirectMessage(int userId) async {
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/direct'
        : '$_baseUrl/chat/direct';

    final body = {'user_id': userId};

    final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);

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
          if (data.containsKey('user') && data['user'] is Map) {
            final userMap = Map<String, dynamic>.from(data['user']);
            if (userMap['id'] != null) {
              _userId = userMap['id'];
            }
            if (_userType == 'user') {
              _userCode = (userMap['user_code'] ?? userMap['code'] ?? _userCode)
                  .toString();
            }
            _userName = _extractUserName(userMap) ?? _userName;
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
          if (_userCode != null && _userType == 'user') {
            await prefs.setString('user_code', _userCode!);
          }
          if (_userName != null) {
            await prefs.setString('user_name', _userName!);
          }

          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error parsing refresh response: $e');
      }
    }

    return false;
  }

  Future<List<ChatContact>> searchContacts(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/search?q=$encoded'
        : '$_baseUrl/chat/search?q=$encoded';

    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // "Returns matches with same contacts shape"
      if (data is List) {
        return data.map((e) => ChatContact.fromJson(e)).toList();
      } else if (data['data'] is List) {
        return (data['data'] as List)
            .map((e) => ChatContact.fromJson(e))
            .toList();
      }
    }
    return [];
  }

  // Deprecated old search
  Future<List<dynamic>> searchUsers(String q) async {
    // Map to dynamics
    final results = await searchContacts(q);
    return results
        .map((c) => {'id': c.id, 'name': c.name, 'avatar': c.avatar})
        .toList();
  }

  Future<void> updateDeviceToken(String deviceToken) async {
    // Only update if logged in and user ID is available
    if (_token == null || _userId == null) {
      if (kDebugMode) {
        print(
            "updateDeviceToken skipped: User not logged in or user ID is missing.");
      }
      return;
    }

    final url = _userType == 'admin'
        ? '$_baseUrl/admin/device-token'
        : '$_baseUrl/user/device-token';

    final body = {
      'user_id': _userId,
      'device_token': deviceToken,
    };

    try {
      final response = await _sendHttpWithAuthAndRetry('POST', url, body: body);
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Successfully updated device token.');
        }
      } else {
        if (kDebugMode) {
          print('Failed to update device token: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating device token: $e');
      }
    }
  }

  Future<void> logout() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        if (kDebugMode) {
          print("Logging out: Invalidating device token on backend.");
        }
        final url = _userType == 'admin'
            ? '$_baseUrl/admin/logout'
            : '$_baseUrl/user/logout';
        final body = {'device_token': fcmToken};
        // No need to await, fire and forget
        _sendHttpWithAuthAndRetry('POST', url, body: body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error sending device token to logout endpoint: $e");
      }
    } finally {
      // Always clear local data to complete logout on the client.
      _token = null;
      _userType = null;
      _userId = null;
      _userCode = null;
      _userName = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_type');
      await prefs.remove('user_id');
      await prefs.remove('user_code');
      await prefs.remove('user_name');
    }
  }

  String? _extractUserName(Map<String, dynamic> userMap) {
    const keys = ['name', 'full_name', 'marketing_person_name', 'person_name'];
    for (final key in keys) {
      final value = userMap[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  // ===== Marketing person bookings/invoices endpoints =====

  /// Helper to build marketing-person scoped URL using the current user's marketing user_code.
  /// Only valid for non-admin users.

  String _marketingPersonPath(String path) {
    if (_userType != 'user' || _userCode == null) {
      throw StateError('Marketing-person endpoints are only for user logins');
    }
    final code = _userCode!;
    return '$_baseUrl/marketing-person/$code$path';
  }

  /// Fetch all bookings with optional filters.
  /// Mirrors: GET /marketing-person/{user_code}/bookings
  Future<Map<String, dynamic>> fetchBookings({
    String? paymentOption, // without_bill / with_bill
    String? invoiceStatus, // not_generated
    int? year,
    int? month,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (paymentOption != null) query['payment_option'] = paymentOption;
    if (invoiceStatus != null) query['invoice_status'] = invoiceStatus;
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString().padLeft(2, '0');

    final uri = Uri.parse(_marketingPersonPath('/bookings'))
        .replace(queryParameters: query);
    final response = await _sendHttpWithAuthAndRetry('GET', uri.toString());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return {};
  }

  /// Fetch bookings without bill / cash status.
  /// Mirrors: GET /marketing-person/{user_code}/bookings/without-bill
  Future<Map<String, dynamic>> fetchWithoutBillBookings({
    int? withPayment, // 1 -> with cash payment
    int? transactionStatus, // 0 / 1
    int? year,
    int? month,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (withPayment != null) query['with_payment'] = withPayment.toString();
    if (transactionStatus != null) {
      query['transaction_status'] = transactionStatus.toString();
    }
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString().padLeft(2, '0');

    final uri = Uri.parse(_marketingPersonPath('/bookings/without-bill'))
        .replace(queryParameters: query);
    final response = await _sendHttpWithAuthAndRetry('GET', uri.toString());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return {};
  }

  /// Fetch invoices generated for marketing person's bookings.
  /// Mirrors: GET /marketing-person/{user_code}/invoices
  Future<Map<String, dynamic>> fetchInvoices({
    String? status, // paid / unpaid / pending
    String? type, // tax_invoice / other
    int? year,
    int? month,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (status != null) query['status'] = status;
    if (type != null) query['type'] = type;
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString().padLeft(2, '0');

    final uri = Uri.parse(_marketingPersonPath('/invoices'))
        .replace(queryParameters: query);
    final response = await _sendHttpWithAuthAndRetry('GET', uri.toString());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return {};
  }

  /// Fetch all invoice payment transactions.
  /// Mirrors: GET /marketing-person/{user_code}/invoice-transactions
  Future<Map<String, dynamic>> fetchInvoiceTransactions({
    int? year,
    int? month,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString().padLeft(2, '0');

    final uri = Uri.parse(_marketingPersonPath('/invoice-transactions'))
        .replace(queryParameters: query);
    final response = await _sendHttpWithAuthAndRetry('GET', uri.toString());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return {};
  }

  /// Fetch all cash transactions deposited by the marketing person.
  /// Mirrors: GET /marketing-person/{user_code}/cash-transactions
  Future<Map<String, dynamic>> fetchCashTransactions({
    int? transactionStatus, // 0 / 1
    int? year,
    int? month,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (transactionStatus != null) {
      query['transaction_status'] = transactionStatus.toString();
    }
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString().padLeft(2, '0');

    final uri = Uri.parse(_marketingPersonPath('/cash-transactions'))
        .replace(queryParameters: query);
    final response = await _sendHttpWithAuthAndRetry('GET', uri.toString());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return {};
  }

  // ===== Expenses endpoints =====

  Future<Map<String, dynamic>> fetchExpenses({
    String? section,
    String? status,
    int? month,
    int? year,
    String? search,
    bool? groupPersonal,
    int page = 1,
    int? perPage,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (section != null && section.isNotEmpty) query['section'] = section;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (month != null) query['month'] = month.toString();
    if (year != null) query['year'] = year.toString();
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (groupPersonal != null) {
      query['group_personal'] = groupPersonal ? '1' : '0';
    }
    if (perPage != null) query['per_page'] = perPage.toString();

    final uri = Uri.parse('$_baseUrl/expenses').replace(queryParameters: query);
    final response = await _sendHttpWithAuthAndRetry('GET', uri.toString());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return {};
  }

  Future<Map<String, dynamic>?> getExpense(int expenseId) async {
    final url = '$_baseUrl/expenses/$expenseId';
    final response = await _sendHttpWithAuthAndRetry('GET', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }

  Future<Map<String, dynamic>?> createExpense({
    String? section,
    String? marketingPersonCode,
    String? marketingPersonName,
    String? personName,
    required double amount,
    required DateTime fromDate,
    required DateTime toDate,
    String? description,
    String? receiptFilePath,
  }) async {
    final fields = <String, String>{
      'amount': amount.toStringAsFixed(2),
      'from_date': _formatDateParam(fromDate),
      'to_date': _formatDateParam(toDate),
    };
    if (section != null && section.isNotEmpty) {
      fields['section'] = section;
    }
    if (marketingPersonCode != null && marketingPersonCode.isNotEmpty) {
      fields['marketing_person_code'] = marketingPersonCode;
    }
    if (marketingPersonName != null && marketingPersonName.isNotEmpty) {
      fields['marketing_person_name'] = marketingPersonName;
      fields['person_name'] = marketingPersonName;
    }
    if (personName != null && personName.isNotEmpty) {
      fields['person_name'] = personName;
      fields['marketing_person_name'] =
          fields['marketing_person_name'] ?? personName;
    }
    if (description != null && description.isNotEmpty) {
      fields['description'] = description;
    }

    return _sendExpenseMultipart(
      'POST',
      '$_baseUrl/expenses',
      fields,
      receiptFilePath: receiptFilePath,
    );
  }

  Future<Map<String, dynamic>?> updatePersonalExpense({
    required int expenseId,
    required double amount,
    required DateTime fromDate,
    required DateTime toDate,
    String? marketingPersonName,
    String? personName,
    String? description,
    String? receiptFilePath,
  }) async {
    final fields = <String, String>{
      'amount': amount.toStringAsFixed(2),
      'from_date': _formatDateParam(fromDate),
      'to_date': _formatDateParam(toDate),
      'section': 'personal',
    };
    if (marketingPersonName != null && marketingPersonName.isNotEmpty) {
      fields['marketing_person_name'] = marketingPersonName;
      fields['person_name'] = marketingPersonName;
    }
    if (personName != null && personName.isNotEmpty) {
      fields['person_name'] = personName;
      fields['marketing_person_name'] =
          fields['marketing_person_name'] ?? personName;
    }
    if (description != null && description.isNotEmpty) {
      fields['description'] = description;
    }

    return _sendExpenseMultipart(
      'POST',
      '$_baseUrl/expenses/$expenseId',
      {
        ...fields,
        '_method': 'PUT',
      },
      receiptFilePath: receiptFilePath,
    );
  }

  Future<bool> deletePersonalExpense(int expenseId) async {
    final url = '$_baseUrl/expenses/$expenseId';
    final response = await _sendHttpWithAuthAndRetry('DELETE', url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['success'] == true) return true;
      }
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> sendPersonalExpensesForApproval({
    int? month,
    int? year,
  }) async {
    final body = <String, dynamic>{};
    if (month != null) body['month'] = month;
    if (year != null) body['year'] = year;

    final response = await _sendHttpWithAuthAndRetry(
      'POST',
      '$_baseUrl/expenses/personal/send-for-approval',
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }
}

/// Standalone function for [compute].
dynamic _parseAndDecode(String responseBody) {
  return jsonDecode(responseBody);
}
