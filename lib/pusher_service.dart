import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.d';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherService {
  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();

  Future<void> initPusher() async {
    try {
      await pusher.init(
        apiKey: dotenv.env['PUSHER_APP_KEY']!,
        cluster: dotenv.env['PUSHER_APP_CLUSTER']!,
        onConnectionStateChange: onConnectionStateChange,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onDecryptionFailure: onDecryptionFailure,
        onMemberAdded: onMemberAdded,
        onMemberRemoved: onMemberRemoved,
        // authEndpoint: "<Your Authendpoint>",
        // onAuthorizer: onAuthorizer
      );
    } catch (e) {
      if (kDebugMode) {
        print("ERROR: Pusher initialization error: $e");
      }
    }
  }

  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    if (kDebugMode) {
      print(
          "Connection: $currentState, previous: $previousState");
    }
  }

  void onError(String message, int? code, dynamic e) {
    if (kDebugMode) {
      print("onError: $message code: $code e: $e");
    }
  }

  void onEvent(PusherEvent event) {
    if (kDebugMode) {
      print("onEvent: $event");
    }
    // Handle the received event
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    if (kDebugMode) {
      print("onSubscriptionSucceeded: $channelName data: $data");
    }
  }

  void onSubscriptionError(String message, dynamic e) {
    if (kDebugMode) {
      print("onSubscriptionError: $message Exception: $e");
    }
  }

  void onDecryptionFailure(String event, String reason) {
    if (kDebugMode) {
      print("onDecryptionFailure: $event reason: $reason");
    }
  }

  void onMemberAdded(String channelName, PusherMember member) {
    if (kDebugMode) {
      print("onMemberAdded: $channelName user: $member");
    }
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    if (kDebugMode) {
      print("onMemberRemoved: $channelName user: $member");
    }
  }


  Future<void> connectPusher() async {
    await pusher.connect();
  }

  Future<void> subscribeToChannel(String channelName) async {
    await pusher.subscribe(channelName: channelName);
  }

  Future<void> unsubscribeFromChannel(String channelName) async {
    await pusher.unsubscribe(channelName: channelName);
  }

  void disconnectPusher() {
    pusher.disconnect();
  }
}
