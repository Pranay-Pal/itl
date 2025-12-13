import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:itl/src/common/screens/splash_screen.dart';
import 'package:itl/src/config/theme.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/pusher_service.dart';
import 'package:itl/src/services/shared_intent_service.dart';
import 'package:itl/src/services/theme_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the .env file
  await dotenv.load(fileName: "Envs/.env");

  // Add this block to check if the values are loaded
  if (kDebugMode) {
    print("PUSHER_APP_KEY: ${dotenv.env['PUSHER_APP_KEY']}");
    print("PUSHER_APP_CLUSTER: ${dotenv.env['PUSHER_APP_CLUSTER']}");
  }

  // Initialize Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (kDebugMode) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
    }
    if (message.notification != null) {
      if (kDebugMode) {
        print('Message also contained a notification: ${message.notification}');
      }
    }
  });

  // Ensure ApiService loads persisted token/userType before starting services that may depend on it
  final apiService = ApiService();
  await apiService.ensureInitialized();

  // Start handling shared intents (e.g. Receive Share from other apps)
  await SharedIntentService().start();

  await PusherService().initPusher();
  await ThemeService().loadTheme();

  // Request notification permission early
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        return MaterialApp(
          title: 'ITL',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeService().themeMode,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
