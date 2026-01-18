import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:itl/src/common/animations/scale_button.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/dashboard/screens/dashboard_screen.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/auth/screens/admin_webview_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _selectedUserType = 'user'; // Default to 'user'
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

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
          String msg = _parseError(body);
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

  String _parseError(dynamic body) {
    if (body is Map) {
      if (body['message'] != null) return body['message'].toString();
      if (body['error'] != null) return body['error'].toString();
      if (body['errors'] != null) return body['errors'].toString();
      return jsonEncode(body);
    }
    return body.toString();
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
    final theme = Theme.of(context);

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppLayout.gapL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(AppLayout.gapM),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/images/logo.png'),
                    backgroundColor: Colors.transparent,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(delay: 200.ms, curve: Curves.easeOutBack),

                const SizedBox(height: AppLayout.gapXl),

                // Welcome Text
                Text('Welcome Back', style: AppTypography.displaySmall)
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: AppLayout.gapS),

                Text(
                  'Sign in to continue to ITL',
                  style: AppTypography.bodyMedium.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: AppLayout.gapSection),

                // Glass Login Form
                GlassContainer(
                  isNeon: true, // Subtle glow
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Type Selector
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUserType,
                          decoration: const InputDecoration(
                            labelText: 'Login as',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'user', child: Text('User')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedUserType = val!;
                              _errorMessage = null;
                            });
                          },
                        ),
                        const SizedBox(height: AppLayout.gapL),

                        // Inputs
                        if (_selectedUserType == 'user') ...[
                          TextFormField(
                            controller: _userCodeController,
                            decoration: const InputDecoration(
                              labelText: 'User Code',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Please enter user code' : null,
                          ),
                          const SizedBox(height: AppLayout.gapL),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Please enter password' : null,
                          ),
                        ],

                        const SizedBox(height: AppLayout.gapL),

                        // Error Message
                        if (_errorMessage != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppLayout.gapM),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ).animate().fadeIn().shake(),

                        // Sign In Button
                        ScaleButton(
                          onTap: _selectedUserType == 'admin'
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminWebViewScreen(),
                                    ),
                                  );
                                }
                              : (_isLoading ? null : _login),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius:
                                  BorderRadius.circular(AppLayout.radiusRound),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      theme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _selectedUserType == 'admin'
                                        ? 'Open Admin Portal'
                                        : 'Sign In',
                                    style: AppTypography.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
