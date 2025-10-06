
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'dashboard_screen.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITL',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Define other theme properties here if needed
      ),
      home: FutureBuilder<String?>( // Use FutureBuilder to check token asynchronously
        future: _getAccessToken(),
        builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While waiting for the token, show the SplashScreen
            return const SplashScreen();
          } else {
            // If token is available and not empty, navigate to Dashboard
            if (snapshot.data != null && snapshot.data!.isNotEmpty) {
              return const DashboardScreen();
            } else {
              // Otherwise, navigate to LoginPage
              return const LoginPage();
            }
          }
        },
      ),
    );
  }

  // Helper function to get the access token from SharedPreferences
  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}
