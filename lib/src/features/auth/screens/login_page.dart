import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/features/dashboard/screens/dashboard_screen.dart';

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

  String? _errorMessage;

  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  // small scale animation for button press
  double _buttonScale = 1.0;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final identifier = _selectedUserType == 'admin'
          ? _emailController.text
          : _userCodeController.text;
      try {
        final result = await _apiService.login(
          identifier,
          _passwordController.text,
          _selectedUserType,
        );

        final bool success = result['success'] == true;
        final int status = result['statusCode'] ?? 0;
        final dynamic body = result['body'];

        if (success) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (BuildContext context) => const DashboardScreen(),
              ),
            );
          }
        } else {
          String msg = 'Unknown error';
          if (body is Map) {
            if (body['message'] != null) {
              msg = body['message'].toString();
            } else if (body['error'] != null) {
              msg = body['error'].toString();
            } else if (body['errors'] != null) {
              try {
                msg = jsonEncode(body['errors']);
              } catch (_) {
                msg = body['errors'].toString();
              }
            } else {
              try {
                msg = jsonEncode(body);
              } catch (_) {
                msg = body.toString();
              }
            }
          } else if (body is String) {
            msg = body;
          }

          if (mounted) {
            setState(() {
              _errorMessage = 'Login failed ($status): $msg';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Login error: ${e.toString()}';
          });
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

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0B141A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final inputFillColor =
        isDark ? const Color(0xFF2A3942) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: isDark
            ? null
            : BoxDecoration(
                gradient:
                    kBlueGradient), // Keep gradient for light mode only if desired, or remove
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand/logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 44,
                    backgroundImage: AssetImage('assets/images/logo.png'),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: isDark
                            ? Colors.white
                            : Colors
                                .white, // In light mode, background is gradient so white is correct
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue to ITL',
                  style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.white70),
                ),
                const SizedBox(height: 20),

                // Card with inputs
                Card(
                  color: cardColor,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedUserType,
                            dropdownColor: cardColor,
                            style: TextStyle(color: textColor, fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Login as',
                              labelStyle: TextStyle(color: hintColor),
                              prefixIcon: Icon(Icons.person, color: hintColor),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedUserType = newValue!;
                                _userCodeController.clear();
                                _emailController.clear();
                                _passwordController.clear();
                                _errorMessage = null;
                              });
                            },
                            items: [
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('User',
                                    style: TextStyle(color: textColor)),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin',
                                    style: TextStyle(color: textColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          if (_selectedUserType == 'admin') ...[
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(color: hintColor),
                                prefixIcon: Icon(Icons.email, color: hintColor),
                                filled: true,
                                fillColor: inputFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                              onChanged: (_) => _clearError(),
                            ),
                            const SizedBox(height: 12.0),
                          ] else ...[
                            TextFormField(
                              controller: _userCodeController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'User Code',
                                labelStyle: TextStyle(color: hintColor),
                                prefixIcon: Icon(Icons.badge, color: hintColor),
                                filled: true,
                                fillColor: inputFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.text,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your user code';
                                }
                                return null;
                              },
                              onChanged: (_) => _clearError(),
                            ),
                            const SizedBox(height: 12.0),
                          ],
                          TextFormField(
                            controller: _passwordController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: hintColor),
                              prefixIcon: Icon(Icons.lock, color: hintColor),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 18.0),

                          // Inline error message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8.0),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8.0),
                          ],

                          // Animated gradient button
                          GestureDetector(
                            onTapDown: (_) {
                              setState(() => _buttonScale = 0.98);
                            },
                            onTapUp: (_) {
                              setState(() => _buttonScale = 1.0);
                            },
                            onTapCancel: () {
                              setState(() => _buttonScale = 1.0);
                            },
                            child: AnimatedScale(
                              scale: _buttonScale,
                              duration: const Duration(milliseconds: 120),
                              child: SizedBox(
                                width: double.infinity,
                                child: InkWell(
                                  onTap: _isLoading ? null : _login,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [
                                                const Color(0xFF00A884),
                                                const Color(0xFF008F6F)
                                              ] // WhatsApp Green for Dark
                                            : [
                                                const Color(0xFF3A8DFF),
                                                const Color(0xFF1466FF)
                                              ], // Blue for Light
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
