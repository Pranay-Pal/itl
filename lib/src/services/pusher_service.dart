import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/config/base_url.dart' as config;

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;
  PusherService._internal();

  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  bool _connected = false;
  final Set<String> _subscribed = <String>{};
  final Set<String> _pendingSubscriptions = <String>{};

  final _eventStreamController = StreamController<PusherEvent>.broadcast();
  Stream<PusherEvent> get eventStream => _eventStreamController.stream;

  Future<void> initPusher() async {
    // Need to get token for auth
    final apiService = ApiService();
    await apiService.ensureInitialized();
    final token = apiService.token;

    // Using headers for auth params
    final authParams = {
      'headers': {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }
    };

    try {
      await pusher.init(
        apiKey: dotenv.env['PUSHER_APP_KEY']!,
        cluster: dotenv.env['PUSHER_APP_CLUSTER']!,
        authEndpoint: "${config.baseUrl}/api/broadcasting/auth",
        authParams: authParams,
        onConnectionStateChange: onConnectionStateChange,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onDecryptionFailure: onDecryptionFailure,
        onMemberAdded: onMemberAdded,
        onMemberRemoved: onMemberRemoved,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("ERROR: Pusher initialization error: $e");
      }
    }
  }

  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    if (kDebugMode) {
      debugPrint("Connection: $currentState, previous: $previousState");
    }
  }

  void onError(String message, int? code, dynamic e) {
    if (kDebugMode) {
      debugPrint("onError: $message code: $code e: $e");
    }
  }

  void onEvent(PusherEvent event) {
    if (kDebugMode) {
      debugPrint("onEvent: $event");
    }
    _eventStreamController.add(event);
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    if (kDebugMode) {
      debugPrint("onSubscriptionSucceeded: $channelName data: $data");
    }
  }

  void onSubscriptionError(String message, dynamic e) {
    if (kDebugMode) {
      debugPrint("onSubscriptionError: $message Exception: $e");
    }
  }

  void onDecryptionFailure(String event, String reason) {
    if (kDebugMode) {
      debugPrint("onDecryptionFailure: $event reason: $reason");
    }
  }

  void onMemberAdded(String channelName, PusherMember member) {
    if (kDebugMode) {
      debugPrint("onMemberAdded: $channelName user: $member");
    }
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    if (kDebugMode) {
      debugPrint("onMemberRemoved: $channelName user: $member");
    }
  }

  Future<void> connectPusher() async {
    if (_connected) {
      return;
    }
    await pusher.connect();
    _connected = true;
  }

  Future<void> subscribeToChannel(String channelName) async {
    // ensure connected first
    if (!_connected) {
      await connectPusher();
    }
    if (_subscribed.contains(channelName) ||
        _pendingSubscriptions.contains(channelName)) {
      return;
    }

    _pendingSubscriptions.add(channelName);
    try {
      await pusher.subscribe(channelName: channelName);
      _subscribed.add(channelName);
    } catch (e) {
      // Ignore duplicate subscription errors gracefully
      if (kDebugMode) {
        debugPrint('Pusher subscribe error for "$channelName": $e');
      }
    } finally {
      _pendingSubscriptions.remove(channelName);
    }
  }

  Future<void> unsubscribeFromChannel(String channelName) async {
    if (!_subscribed.contains(channelName)) {
      return;
    }
    try {
      await pusher.unsubscribe(channelName: channelName);
    } finally {
      _subscribed.remove(channelName);
    }
  }

  void disconnectPusher() {
    pusher.disconnect();
    _connected = false;
    _subscribed.clear();
  }

  void dispose() {
    _eventStreamController.close();
  }
}
