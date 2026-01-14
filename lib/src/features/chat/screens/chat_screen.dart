import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:itl/src/config/app_palette.dart';
import 'package:file_picker/file_picker.dart';

import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import 'package:itl/src/config/constants.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/chat/models/chat_models.dart';
import 'package:itl/src/services/download_util.dart' as download_util;
import 'package:itl/src/services/pusher_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/common/animations/scale_button.dart';
import 'package:itl/src/config/typography.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itl/src/common/utils/image_compression_service.dart';

class ChatScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String contactType; // 'user', 'group', 'admin'

  const ChatScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.contactType = 'user',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PusherService _pusherService = PusherService();
  final AudioRecorder _recorder = AudioRecorder();
  late StreamSubscription<PusherEvent> _eventSubscription;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _hasMoreMessages = true;
  int _currentPage = 1;

  // If replying to a message, store its ID
  int? _replyToMessageId;

  // Voice recording
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Typing indicators
  Timer? _typingDebounce;
  bool _isPartnerTyping = false;
  Timer? _partnerTypingTimer;

  // Quick lookup for reply previews
  final Map<int, ChatMessage> _messageById = {};

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToPusher();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.minScrollExtent &&
          _hasMoreMessages) {
        _fetchMoreMessages();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToPusher() async {
    // Channel name convention needs check.
    // Assuming 'private-chat-{user_id}' for user and listening for incoming?
    // Or 'private-count-group.{id}'?
    // Legacy code used 'private-chat-group.{groupId}'.
    // API 2.0 Docs: "The server broadcasts events... via Echo/Pusher"
    // Usually 'private-user.{id}' is best for receiving.
    // For now, let's just listen to the global 'chat' channel or user-specific if we knew how.
    // Keeping it simple: Listen to channel 'chat' (public) or maybe 'private-user.{myId}'

    // NOTE: Old code used group channel. New code might push to user.
    // Let's assume user channel is `private-user.{currentUserId}` based on Laravel conventions
    final myId = _apiService.currentUserId;
    if (myId != null) {
      // We might not have permission/auth for this without backend change,
      // but let's try or fallback to periodic poll slightly.
      // Actually, the docs say: "Mobile clients may... Poll" as option 2.
      // Let's stick to polling for simplicity if Pusher details are vague,
      // OR keep the 'chat' channel if it was broadcasting globally (unlikely for privacy).

      // Reverting to legacy 'chat' global channel listening for now as in ChatListScreen
      await _pusherService.subscribeToChannel('chat'); // risky if noisy

      _eventSubscription = _pusherService.eventStream.listen((event) {
        final data = jsonDecode(event.data);

        if (['ChatMessageSent', 'ChatMessageBroadcast']
            .contains(event.eventName)) {
          _onNewMessage(data);
        } else if (event.eventName == 'ChatTyping') {
          _onPartnerTyping(data);
        } else if (event.eventName == 'ChatMessageRead') {
          // data should contain message_ids array or single ID
          // implementation needed
          if (mounted) {
            // Basic refresh for now or iterate
            // Ideally we find the message and update 'read_at'
            // If we just re-fetch, it might be heavy.
            // Let's iterate if we have explicit IDs, else fetch.
            // Docs say: event data has 'ids' (List<int>)
            if (data['ids'] != null) {
              final ids = List<int>.from(data['ids']);
              setState(() {
                for (var msg in _messages) {
                  if (ids.contains(msg.id)) {
                    msg.readAt = DateTime.now(); // approximate
                  }
                }
              });
            }
          }
        }
      });
    }
  }

  void _onPartnerTyping(dynamic data) {
    // Check if the typing event comes from the current contact context
    // data: { sender_id, receiver_id, receiver_type }
    final senderId = data['sender_id'];
    if (senderId == _apiService.currentUserId) {
      return; // Don't show my own typing
    }

    final type = data['receiver_type'] ?? 'user';
    final recId = data['receiver_id'];

    bool matches = false;

    if (type == 'group') {
      // If we are in this group
      if (widget.contactType == 'group' && widget.contactId == 'group:$recId') {
        matches = true;
      }
    } else {
      // One-to-one: sender must be the person we are chatting with
      // AND receiver must be us (implied if we get the event)
      if (widget.contactType == 'user') {
        // contactId might be "user:123" or just "123" if legacy
        final currentContactIdStr = widget.contactId.contains(':')
            ? widget.contactId.split(':').last
            : widget.contactId;
        final currentContactId = int.tryParse(currentContactIdStr);

        if (senderId == currentContactId) {
          matches = true;
        }
      }
    }

    if (matches) {
      if (mounted) {
        setState(() {
          _isPartnerTyping = true;
        });
      }

      _partnerTypingTimer?.cancel();
      _partnerTypingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isPartnerTyping = false;
          });
        }
      });
    }
  }

  void _onNewMessage(dynamic data) {
    if (!mounted) return;
    try {
      if (data['message'] != null) {
        final msgData = data['message'];
        final msg = ChatMessage.fromJson(msgData,
            currentUserId: _apiService.currentUserId);

        // Check if the message is relevant to the current chat screen
        // This logic needs to be robust based on your backend's message routing
        bool isRelevant = false;
        final contactIdInt = int.tryParse(widget.contactId.contains(':')
                ? widget.contactId.split(':').last
                : widget.contactId) ??
            0;

        if (msg.senderId == contactIdInt ||
            msg.receiverId == widget.contactId) {
          isRelevant = true;
        }

        if (isRelevant) {
          setState(() {
            _messages.insert(0, msg);
            _messageById[msg.id] = msg;
          });
          // _markMessagesRead([msg]);
          _scrollToBottomDelayed();
        }
      }
    } catch (e) {
      debugPrint('Error parsing new message: $e');
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _apiService.getMessages(widget.contactId, page: 1);

      if (mounted) {
        setState(() {
          _messages = messages;

          for (var m in _messages) {
            _messageById[m.id] = m;
          }
          _hasMoreMessages = messages.isNotEmpty; // Rough check
          _isLoading = false;
        });
        // _markMessagesRead(_messages); // API might mark read via param if we add it
        _scrollToBottomDelayed();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreMessages() async {
    if (!_hasMoreMessages || _isLoading) return;
    try {
      // Pagination logical update needed if API supports it standardly
      // For now, assume page++ works
      final nextPage = _currentPage + 1;
      final messages =
          await _apiService.getMessages(widget.contactId, page: nextPage);

      if (mounted) {
        setState(() {
          if (messages.isEmpty) {
            _hasMoreMessages = false;
          } else {
            _currentPage = nextPage;
            // _messages is reversed for UI?
            // If we append to bottom of list (which is top of UI in reverse listview), we add to end.
            // If messages are [newest...oldest], we add them to end of _messages.
            _messages.addAll(messages);
            for (var m in messages) {
              _messageById[m.id] = m;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hasMoreMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final sentMessage = await _apiService.sendMessage(
        widget.contactId,
        text,
        receiverType: widget.contactType,
        replyToId: _replyToMessageId,
      );

      if (sentMessage != null && mounted) {
        setState(() {
          _messages.insert(0, sentMessage); // Assume new message at top
          _replyToMessageId = null;
        });
        _scrollToBottomDelayed();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'pdf',
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg'
      ],
    );

    if (result != null) {
      final path = result.files.single.path!;

      final sentMessage = await _apiService.uploadChatFile(
        widget.contactId,
        widget.contactType,
        path,
        replyToId: _replyToMessageId,
      );

      if (sentMessage != null && mounted) {
        setState(() {
          _messages.insert(0, sentMessage);
          _replyToMessageId = null;
        });
        _scrollToBottomDelayed();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload file')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final compressed = await ImageCompressionService.compressImage(photo);
        final path = compressed.path;

        final sentMessage = await _apiService.uploadChatFile(
          widget.contactId,
          widget.contactType,
          path,
          replyToId: _replyToMessageId,
        );

        if (sentMessage != null && mounted) {
          setState(() {
            _messages.insert(0, sentMessage);
            _replyToMessageId = null;
          });
          _scrollToBottomDelayed();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send photo')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  // Legacy methods removed

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt.toLocal());
  }

  Widget _buildMessageItem(ChatMessage message) {
    if (message.isMine) {
      return _buildMyMessage(message);
    } else {
      return _buildOtherMessage(message);
    }
  }

  Widget _buildMyMessage(ChatMessage message) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.electricBlue, AppPalette.neonCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: const Radius.circular(0),
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.neonCyan.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.replyTo != null)
                _buildReplyPreview(message.replyTo!, isMine: true),
              if (message.attachments.isNotEmpty)
                ...message.attachments
                    .map((a) => _buildAttachment(a, isMine: true)),
              if (message.content != null && message.content!.isNotEmpty)
                Text(
                  message.content!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  if (message.readAt != null)
                    const Icon(Icons.done_all,
                        size: 16, color: AppPalette.neonCyan)
                  else if (message.readAt ==
                      null) // Add delivered check if API supports
                    const Icon(Icons.done, size: 16, color: Colors.white70)
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherMessage(ChatMessage message) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(0),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppPalette.neonCyan,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              if (message.replyTo != null)
                _buildReplyPreview(message.replyTo!, isMine: false),
              if (message.attachments.isNotEmpty)
                ...message.attachments
                    .map((a) => _buildAttachment(a, isMine: false)),
              if (message.content != null && message.content!.isNotEmpty)
                Text(
                  message.content!,
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 15),
                ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for reply preview
  Widget _buildReplyPreview(ChatMessage original, {required bool isMine}) {
    final theme = Theme.of(context);
    final borderColor = isMine
        ? Colors.white
        : (theme.brightness == Brightness.light
            ? theme.primaryColor
            : AppPalette.neonCyan);
    final senderColor = isMine
        ? Colors.white70
        : (theme.brightness == Brightness.light
            ? theme.primaryColor
            : AppPalette.neonCyan);
    final contentColor = isMine
        ? Colors.white70
        : theme.textTheme.bodySmall?.color ?? Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.black.withValues(alpha: 0.1)
            : theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            original.senderName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: senderColor,
            ),
          ),
          Text(
            original.content ??
                (original.attachments.isNotEmpty ? '[Attachment]' : ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(ChatAttachment attachment, {required bool isMine}) {
    final textColor = isMine
        ? Colors.white
        : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    // Basic attachment handler for now, can be improved with better glass UI
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(attachment.type)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _ImageViewerPage(
                  url: attachment.url,
                  heroTag: 'img_${attachment.url}',
                ),
              ),
            );
          },
          child: Hero(
            tag: 'img_${attachment.url}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                attachment.url,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.black12
            : Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file,
              size: 20,
              color: isMine
                  ? Colors.white
                  : Theme.of(context).iconTheme.color ?? Colors.black54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottomDelayed() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showForwardDialog(int messageId) async {
    final groups = await _apiService.getChatGroups();
    if (!mounted) return;
    final selectedGroupIds = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        final selected = <int>{};
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Forward to...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final contact = groups[index];
                    return CheckboxListTile(
                      activeColor: kPrimaryBlue,
                      title: Text(contact.name, style: TextStyle()),
                      value: selected.contains(
                          int.tryParse(contact.id.split(':').last) ?? 0),
                      onChanged: (isSelected) {
                        final cid =
                            int.tryParse(contact.id.split(':').last) ?? 0;
                        setState(() {
                          if (isSelected == true) {
                            selected.add(cid);
                          } else {
                            selected.remove(cid);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selected.toList()),
                  child: Text('Forward',
                      style: TextStyle(
                          color: kPrimaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedGroupIds != null && selectedGroupIds.isNotEmpty) {
      await _apiService.forwardMessage(messageId, selectedGroupIds);
    }
  }

  void _showStatusDialog(int messageId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Status', style: TextStyle()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Hold', style: TextStyle()),
                onTap: () {
                  _apiService.setMessageStatus(messageId, 'hold');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Booked', style: TextStyle()),
                onTap: () {
                  _apiService.setMessageStatus(messageId, 'booked');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Cancel', style: TextStyle()),
                onTap: () {
                  _apiService.setMessageStatus(messageId, 'cancel');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteMessage(int messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message', style: TextStyle()),
        content: Text('Are you sure you want to delete this message?',
            style: TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteMessage(messageId);
      if (success && mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg.id == messageId);
        });
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSeconds++);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
    } catch (e) {
      debugPrint("Recording error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      if (mounted) setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        final sentMessage = await _apiService.uploadChatFile(
          widget.contactId,
          widget.contactType,
          path,
          replyToId: _replyToMessageId,
        );

        if (sentMessage != null && mounted) {
          setState(() {
            _messages.insert(0, sentMessage);
            _replyToMessageId = null;
          });
          _scrollToBottomDelayed();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send voice message')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending voice: $e')),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AuroraBackground(
        child: Column(
          children: [
            // Custom Glass Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      ScaleButton(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor:
                            AppPalette.neonCyan.withValues(alpha: 0.2),
                        child: Text(
                          widget.contactName.isNotEmpty
                              ? widget.contactName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppPalette.neonCyan,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.contactName,
                              style: AppTypography.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_isPartnerTyping)
                              Text(
                                'Typing...',
                                style: AppTypography.bodySmall.copyWith(
                                    color: AppPalette.neonCyan,
                                    fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                      _buildHeaderAction(Icons.phone, () {}),
                      _buildHeaderAction(Icons.videocam, () {}),
                      _buildHeaderAction(Icons.more_vert, () {
                        showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.block,
                                            color: Colors.red),
                                        title: const Text('Block User',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          // Implement block logic
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete,
                                            color: Colors.white),
                                        title: const Text('Clear Chat',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          // Implement clear logic
                                        },
                                      ),
                                    ],
                                  ),
                                ));
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Message List
            Expanded(
              child: _buildMessageList(),
            ),

            // Reply Preview Bar
            _buildReplyPreviewBar(),

            // Input Area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppPalette.neonCyan));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(EvaIcons.message_circle_outline,
                  size: 48, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation with\n${widget.contactName}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      reverse: true,
      itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppPalette.neonCyan)),
            ),
          );
        }
        final msg = _messages[index];
        return _buildMessageItem(msg);
      },
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _replyToMessageId = message.id;
                  });
                },
              ),
              if (message.type == 'text')
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(
                        ClipboardData(text: message.content ?? ''));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                ),

              ListTile(
                leading: Icon(EvaIcons.share, color: kPrimaryBlue),
                title: Text('Share', style: TextStyle()),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final type = message.type;
                  try {
                    if (type == 'text') {
                      final text = message.content ?? '';
                      if (text.isNotEmpty) {
                        await SharePlus.instance.share(ShareParams(text: text));
                      }
                    } else if (message.attachments.isNotEmpty) {
                      final attachment = message.attachments.first;
                      if (attachment.url.isNotEmpty) {
                        await download_util.shareFileFromUrl(
                          attachment.url,
                          text: attachment.name,
                        );
                      }
                    }
                  } catch (_) {}
                  if (mounted) navigator.pop();
                },
              ),
              ListTile(
                leading: Icon(EvaIcons.arrow_forward, color: kPrimaryBlue),
                title: Text('Forward', style: TextStyle()),
                onTap: () {
                  Navigator.of(context).pop();
                  _showForwardDialog(message.id);
                },
              ),
              if (_apiService.userType == 'admin')
                ListTile(
                  leading: Icon(EvaIcons.bookmark, color: kPrimaryBlue),
                  title: Text('Set Status', style: TextStyle()),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showStatusDialog(message.id);
                  },
                ),

              // Reactions
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((e) {
                    return IconButton(
                      icon: Text(e, style: const TextStyle(fontSize: 24)),
                      onPressed: () async {
                        Navigator.pop(context);
                        final success =
                            await _apiService.toggleReaction(message.id, e);
                        if (success && mounted) {
                          setState(() {
                            final currentReactions = message.reactions[e] ?? [];
                            final myId = _apiService.currentUserId?.toString();
                            if (myId != null) {
                              if (currentReactions.contains(myId)) {
                                currentReactions.remove(myId);
                              } else {
                                currentReactions.add(myId);
                              }
                              message.reactions[e] = currentReactions;
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              if (message.isMine)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessage(message.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreviewBar() {
    if (_replyToMessageId == null) return const SizedBox.shrink();

    final replyMsg = _messageById[_replyToMessageId];
    if (replyMsg == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: AppPalette.neonCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${replyMsg.senderName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppPalette.neonCyan),
                ),
                Text(
                  replyMsg.content ?? 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ),
          ScaleButton(
            onTap: () {
              setState(() {
                _replyToMessageId = null;
              });
            },
            child: Icon(Icons.close,
                size: 20, color: isDark ? Colors.white70 : Colors.black54),
          )
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Reply Indicator is handled via _buildReplyPreviewBar call in build()
            // but we might want it sticky above input?
            // The build method puts it above _buildInputArea.

            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(24),
                    hasBorder: false,
                    color: Colors.black
                        .withValues(alpha: 0.1), // Very subtle shade
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: iconColor),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Message",
                              hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black38),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            onChanged: (val) {
                              setState(() {});
                              if (_typingDebounce?.isActive ?? false) return;
                              _typingDebounce =
                                  Timer(const Duration(seconds: 2), () {
                                _apiService.sendTyping(widget.contactId);
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.attach_file, color: iconColor),
                          onPressed: _uploadFile,
                        ),
                        if (_messageController.text.isEmpty)
                          IconButton(
                            icon: Icon(Icons.camera_alt, color: iconColor),
                            onPressed: _takePhoto,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Mic / Send Button
                ScaleButton(
                  onTap: () => _isRecording
                      ? _stopRecordingAndSend()
                      : (_messageController.text.isNotEmpty
                          ? _sendMessage()
                          : null),
                  onLongPress: _startRecording,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppPalette.electricBlue, AppPalette.neonCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.neonCyan.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: _isRecording
                        ? const Icon(Icons.stop, color: Colors.white)
                        : Icon(
                            _messageController.text.isNotEmpty
                                ? Icons.send
                                : Icons.mic,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Recording... $_recordSeconds s",
                  style: const TextStyle(color: AppPalette.neonCyan),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  final String url;
  final String heroTag;

  const _ImageViewerPage({required this.url, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: Image.network(url),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(EvaIcons.close_circle,
                  color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
