import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:itl/src/config/navigation.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/bookings/bookings.dart';
import 'package:itl/src/features/reports/screens/reports_dashboard_screen.dart';
import 'package:itl/src/features/invoices/screens/invoice_list_screen.dart';
import 'package:itl/src/features/expenses/screens/expenses_screen.dart';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  RemoteMessage? _pendingInitialMessage;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            if (data is Map<String, dynamic>) {
              _handleRedirect(data);
            }
          } catch (e) {
            debugPrint("Error parsing notification payload: $e");
          }
        }
      },
    );

    // 2. Setup Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Request Permissions
    await _requestPermissions();

    // 4. Register Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Check for initial message (Terminated state)
    // We don't handle it immediately because Navigator might not be ready.
    // We store it and let the UI (Dashboard) call processInitialMessage().
    try {
      _pendingInitialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
    } catch (e) {
      debugPrint("Error getting initial message: $e");
    }

    // 6. Listen to Background -> Foreground transition (Apps running in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleRedirect(message.data);
    });

    // 7. Listen to Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        AndroidNotificationDetails androidDetails;

        if (android.imageUrl != null) {
          try {
            final http.Response response =
                await http.get(Uri.parse(android.imageUrl!));
            final BigPictureStyleInformation bigPic =
                BigPictureStyleInformation(
              ByteArrayAndroidBitmap.fromBase64String(
                  base64Encode(response.bodyBytes)),
              largeIcon: ByteArrayAndroidBitmap.fromBase64String(
                  base64Encode(response.bodyBytes)),
              contentTitle: notification.title,
              summaryText: notification.body,
            );

            androidDetails = AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              styleInformation: bigPic,
            );
          } catch (e) {
            debugPrint("Failed to download image: $e");
            // Fallback to text only
            androidDetails = AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            );
          }
        } else {
          androidDetails = AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          );
        }

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: androidDetails,
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    final firebaseMessaging = FirebaseMessaging.instance;

    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  // Called from DashboardScreen to handle boot-up notification
  void processInitialMessage() {
    if (_pendingInitialMessage != null) {
      debugPrint(
          "Processing pending initial message: ${_pendingInitialMessage!.data}");
      _handleRedirect(_pendingInitialMessage!.data);
      _pendingInitialMessage = null;
    }
  }

  void _handleRedirect(Map<String, dynamic> data) async {
    if (kDebugMode) {
      print("Handling Notification Redirect. Payload: $data");
    }

    // Ensure API Service is ready (token loaded)
    final apiService = ApiService();
    await apiService.ensureInitialized();
    final userCode = apiService.userCode ?? '';

    // If 'userCode' is empty, user might not be logged in.
    // Navigation shouldn't happen or should go to login (which handles it).
    if (userCode.isEmpty) {
      if (kDebugMode) print("User not logged in, skipping redirect");
      return;
    }

    // Determine type
    // Backend might send 'type', 'screen', 'route', etc.
    // Based on user request: "notification about booking"
    final type = data['type']?.toString().toLowerCase() ??
        data['screen']?.toString().toLowerCase();

    if (type == null) return;

    if (navigatorKey.currentState == null) {
      if (kDebugMode) print("Navigator State is null, cannot redirect");
      return;
    }

    switch (type) {
      case 'booking':
      case 'bookings':
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => BookingDashboardScreen(userCode: userCode),
          ),
        );
        break;

      case 'report':
      case 'reports':
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ReportsDashboardScreen(userCode: userCode),
          ),
        );
        break;

      case 'invoice':
      case 'invoices':
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const InvoiceListScreen(),
          ),
        );
        break;

      case 'expense':
      case 'expenses':
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const ExpensesScreen(),
          ),
        );
        break;

      default:
        if (kDebugMode) print("Unknown notification type: $type");
        break;
    }
  }
}
