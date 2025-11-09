import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:itl/src/services/pusher_service.dart';
import 'package:itl/src/common/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the .env file
  await dotenv.load(fileName: "Envs/.env");

  // Add this block to check if the values are loaded
  if (kDebugMode) {
    print("PUSHER_APP_KEY: ${dotenv.env['PUSHER_APP_KEY']}");
    print("PUSHER_APP_CLUSTER: ${dotenv.env['PUSHER_APP_CLUSTER']}");
  }

  await PusherService().initPusher();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ITL',
      home: SplashScreen(),
    );
  }
}
