import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/services/pusher_service.dart';
import 'package:itl/src/features/chat/screens/chat_list_screen.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/auth/screens/login_page.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/features/bookings/bookings.dart';
import 'package:itl/src/features/expenses/screens/expenses_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final PusherService _pusherService = PusherService();
  late StreamSubscription<PusherEvent> _eventSubscription;
  int _totalUnreadCount = 0;

  bool get _isUser => _apiService.userType == 'user';

  @override
  void initState() {
    super.initState();
    _initPusher();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    if (!mounted) return;
    try {
      // Prefer dedicated unread-counts endpoint if available
      final unread = await _apiService.getUnreadCounts();
      if (!mounted) return;
      int total = 0;
      if (unread != null) {
        total = (unread['total'] is int)
            ? unread['total'] as int
            : int.tryParse(unread['total']?.toString() ?? '0') ?? 0;
      } else {
        // Fallback: compute from groups if endpoint not present
        final dynamic groupsResult = await _apiService.getChatGroups();
        if (groupsResult is List) {
          total = groupsResult.fold<int>(0, (sum, g) {
            final u = (g as Map)['unread'];
            if (u is int) return sum + u;
            if (u is String) return sum + (int.tryParse(u) ?? 0);
            if (u is double) return sum + u.round();
            return sum;
          });
        }
      }
      setState(() => _totalUnreadCount = total);
    } catch (e, s) {
      if (kDebugMode) {
        print('Error in _fetchUnreadCount: $e');
        print(s);
      }
    }
  }

  Future<void> _initPusher() async {
    await _pusherService.connectPusher();
    await _pusherService.subscribeToChannel('chat');

    _eventSubscription = _pusherService.eventStream.listen((event) {
      if (kDebugMode) {
        print(
          "Dashboard received event: ${event.eventName} with data: ${event.data}",
        );
      }
      if (event.channelName == 'chat' &&
          event.eventName == 'ChatMessageBroadcast') {
        try {
          final data = jsonDecode(event.data);
          final msg = data['message'];
          if (msg != null) {
            final currentUserId = _apiService.currentUserId;
            final msgUserId = msg['user_id'] ?? msg['user']?['id'];
            // Only increment if the message is from someone else (not mine)
            if (currentUserId != null && msgUserId != currentUserId) {
              setState(() => _totalUnreadCount = _totalUnreadCount + 1);
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _pusherService.unsubscribeFromChannel('chat');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        leading: Builder(
          builder: (BuildContext innerContext) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () {
                Scaffold.of(innerContext).openDrawer();
              },
            );
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (BuildContext context) =>
                              const ChatListScreen(),
                        ),
                      )
                      .then((_) => _fetchUnreadCount());
                },
              ),
              if (_totalUnreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_totalUnreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(gradient: kBlueGradient),
              child: const Text(
                'ITL Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            const ListTile(leading: Icon(Icons.home), title: Text('Home')),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Bookings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const BookingDashboardScreen(userCode: 'MKT001'),
                    ),
                  );
                },
              ),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Expenses'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ExpensesScreen(),
                    ),
                  );
                },
              ),
            const ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Logout'),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop(); // close drawer
                final service = ApiService();
                await service.logout();
                _pusherService.disconnectPusher();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: const Center(child: Text('Welcome to your dashboard!')),
    );
  }
}
