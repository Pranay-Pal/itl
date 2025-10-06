import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String _baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api";
  String? _token;

  Future<void> _loadToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('chat_token');
    }
  }

  Future<bool> login(String userCode, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_code': userCode,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access_token'] != null) {
        _token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_token', _token!);
        return true;
      }
    }
    return false;
  }
}
