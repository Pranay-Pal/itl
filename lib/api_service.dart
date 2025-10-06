import 'dart:convert';
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
      _token = prefs.getString('chat_token');
      _userType = prefs.getString('user_type');
    }
  }

  Future<bool> login(
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

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access_token'] != null) {
        _token = data['access_token'];
        _userType = userType;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_token', _token!);
        await prefs.setString('user_type', _userType!);
        return true;
      }
    }
    return false;
  }

  Future<List<dynamic>> getChatGroups() async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/groups'
        : '$_baseUrl/chat/groups';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] is List) {
        return data['data'];
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> getMessages(int groupId) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages?group_id=$groupId'
        : '$_baseUrl/chat/messages?group_id=$groupId';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>?> sendMessage(int groupId, String content) async {
    await _loadToken();
    final url = _userType == 'admin'
        ? '$_baseUrl/admin/chat/messages'
        : '$_baseUrl/chat/messages';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'group_id': groupId,
        'type': 'text',
        'content': content,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    return null;
  }
}
