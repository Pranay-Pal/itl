import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:share_handler/share_handler.dart';

/// A service to handle shared files from other apps.
/// This is a singleton class.
class SharedIntentService {
  static final SharedIntentService _instance = SharedIntentService._internal();
  factory SharedIntentService() => _instance;
  SharedIntentService._internal();

  StreamSubscription? _sharedMediaSub;
  // Internal controller to broadcast received attachments to the app
  final _attachmentsController =
      StreamController<List<SharedAttachment>>.broadcast();
  final List<SharedAttachment> _initialBuffer = [];

  Stream<List<SharedAttachment>> get attachmentsStream =>
      _attachmentsController.stream;

  /// Returns the initial shared attachments if any, and clears the buffer.
  List<SharedAttachment> consumeInitial() {
    final list = List<SharedAttachment>.from(_initialBuffer);
    _initialBuffer.clear();
    return list;
  }

  /// Starts listening for shared files.
  Future<void> start() async {
    // Ensure any previous subscription is cancelled.
    dispose();

    final handler = ShareHandlerPlatform.instance;

    // Handle the initial shared media when the app is launched from a share action.
    try {
      final SharedMedia? initialMedia = await handler.getInitialSharedMedia();
      final initialAttachments =
          initialMedia?.attachments?.whereType<SharedAttachment>().toList();
      if (initialAttachments != null && initialAttachments.isNotEmpty) {
        _initialBuffer.addAll(initialAttachments);
        _attachmentsController.add(initialAttachments);
      }
    } catch (e) {
      debugPrint("Error handling initial share: $e");
    }

    // Listen for shared media when the app is already running.
    _sharedMediaSub = handler.sharedMediaStream.listen((SharedMedia media) {
      final items = media.attachments?.whereType<SharedAttachment>().toList();
      if (items != null && items.isNotEmpty) {
        _attachmentsController.add(items);
      }
    });
  }

  /// Disposes the stream subscription.
  void dispose() {
    _sharedMediaSub?.cancel();
    _sharedMediaSub = null;
    // We don't close _attachmentsController as this is a singleton service
    // that might be restarted or used across lifecycle?
    // Actually, distinct from Dispose pattern, maybe we shouldn't close it if singleton.
  }
}
