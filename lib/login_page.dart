
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

const String baseUrl = 'https://mediumslateblue-hummingbird-258203.hostingersite.com/api';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  String _selectedUserType = 'user'; // Default to 'user'
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String url;
      Map<String, String> body = {};

      if (_selectedUserType == 'admin') {
        url = '$baseUrl/user/login'; // Assuming admin and user login use the same endpoint
        body = {
          'email': _emailController.text,
          'password': _passwordController.text,
        };
      } else {
        url = '$baseUrl/user/login';
        body = {
          'user_code': _userCodeController.text,
          'password': _passwordController.text,
        };
      }

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final accessToken = data['access_token'];

          // Store the token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);

          // Navigate to dashboard
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (BuildContext context) => const DashboardScreen()),
            );
          }
        } else {
          // Handle login error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: ${response.body}')),
            );
          }
        }
      } catch (e) {
        // Handle network or other errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _userCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade200, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24.0),
                  DropdownButtonFormField<String>(
                    value: _selectedUserType,
                    decoration: InputDecoration(
                      labelText: 'Login as',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedUserType = newValue!;
                        // Clear controllers when type changes to avoid confusion
                        _userCodeController.clear();
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    },
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  if (_selectedUserType == 'admin') ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                  ] else ...[
                    TextFormField(
                      controller: _userCodeController,
                      decoration: const InputDecoration(
                        labelText: 'User Code',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your user code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                  ],
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
