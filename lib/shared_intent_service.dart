import 'dart:async';
import 'package:share_handler/share_handler.dart';

/// A service to handle shared files from other apps.
/// This is a singleton class.
class SharedIntentService {
  static final SharedIntentService _instance = SharedIntentService._internal();
  factory SharedIntentService() => _instance;
  SharedIntentService._internal();

  StreamSubscription? _sharedMediaSub;
  final List<SharedAttachment> _pendingAttachments = [];

  /// Starts listening for shared files.
  /// It handles the initial shared file when the app is launched from a share
  /// and subsequent shares while the app is running.
  Future<void> start() async {
    // Ensure any previous subscription is cancelled.
    dispose();

    final handler = ShareHandlerPlatform.instance;

    // Handle the initial shared media when the app is launched from a share action.
    final SharedMedia? initialMedia = await handler.getInitialSharedMedia();
    final initialAttachments =
        initialMedia?.attachments?.whereType<SharedAttachment>().toList();
    if (initialAttachments != null && initialAttachments.isNotEmpty) {
      _pendingAttachments.addAll(initialAttachments);
    }

    // Listen for shared media when the app is already running.
    _sharedMediaSub = handler.sharedMediaStream.listen((SharedMedia media) {
      final items = media.attachments?.whereType<SharedAttachment>().toList();
      if (items != null && items.isNotEmpty) {
        _pendingAttachments.addAll(items);
      }
    });
  }

  /// Retrieves the list of pending shared attachments and clears the queue.
  List<SharedAttachment> takePending() {
    final attachments = List<SharedAttachment>.from(_pendingAttachments);
    _pendingAttachments.clear();
    return attachments;
  }

  /// Disposes the stream subscription.
  void dispose() {
    _sharedMediaSub?.cancel();
    _sharedMediaSub = null;
  }
}
