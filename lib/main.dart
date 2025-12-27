import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:itl/src/common/screens/splash_screen.dart';
import 'package:itl/src/config/theme.dart';
import 'package:itl/src/services/notification_service.dart';
import 'package:itl/src/services/shared_intent_service.dart';
import 'package:itl/src/services/theme_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: "Envs/.env");
  } catch (e) {
    debugPrint("Error loading .env: $e");
  }

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
  }

  // Initialize Notification Service
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("NotificationService init failed: $e");
  }

  // Initialize Flutter Downloader (Non-blocking)
  FlutterDownloader.initialize(debug: true, ignoreSsl: true).then((_) {
    debugPrint("FlutterDownloader initialized");
  }).catchError((e) {
    debugPrint("FlutterDownloader init failed: $e");
  });

  // Handle Shared Intents - Do NOT await this to prevent blocking startup
  final sharedIntentService = SharedIntentService();
  sharedIntentService.start().catchError((e) {
    debugPrint("SharedIntentService start failed: $e");
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'ITL',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeService.themeMode,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
