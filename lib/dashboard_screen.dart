import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:itl/constants.dart';
import 'package:itl/pusher_service.dart';
import 'chat_list_screen.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PusherService _pusherService = PusherService();
  late StreamSubscription<PusherEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initPusher();
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
      // Add your logic here to handle the message
      // e.g., update a list of messages, show a notification
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
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) => const ChatListScreen(),
                ),
              );
            },
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
                // Navigate to LoginPage and remove all previous routes
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
