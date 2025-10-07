import 'dart:async';
import 'package:flutter/material.dart';
import 'package:itl/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // Keep splash visible briefly
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final prefs = await SharedPreferences.getInstance();
      // Strictly require the canonical key 'access_token'
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (BuildContext context) => const DashboardScreen(),
            ),
          );
          return;
        }
      }
    } catch (e) {
      // ignore and fall through to login
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (BuildContext context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: kBlueGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 125,
                backgroundColor: Colors.white.withOpacity(0.06),
                child: CircleAvatar(
                  radius: 120,
                  backgroundImage: const AssetImage('assets/images/logo.png'),
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 50),
              const Text(
                'Indian Testing Laboratory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
