import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:itl/api_service.dart';
import 'package:itl/constants.dart';
import 'package:itl/pusher_service.dart';
import 'package:itl/voice_message_player_widget.dart' as voice_widget;
import 'package:itl/download_util.dart' as download_util;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:itl/base_url.dart';
import 'package:share_plus/share_plus.dart';

class ChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const ChatScreen({super.key, required this.groupId, required this.groupName});

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

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _hasMoreMessages = true;
  int _currentPage = 1;
  int? _replyToMessageId;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // cache for quick lookup of messages by id (for reply previews)
  final Map<int, dynamic> _messageById = {};

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

  void _subscribeToPusher() {
    _pusherService.subscribeToChannel('chat');
    _eventSubscription = _pusherService.eventStream.listen((event) {
      if (event.channelName != 'chat') return;

      final data = jsonDecode(event.data);

      if (event.eventName == 'ChatMessageBroadcast') {
        final message = data['message'];
        if (message != null &&
            message['group_id'] == widget.groupId &&
            mounted) {
          setState(() {
            if (!_messages.any((m) => m['id'] == message['id'])) {
              _messages.add(message);
            }
          });
          _scrollToBottomDelayed();
        }
      } else if (event.eventName == 'ChatMessageUpdated') {
        final updatedMessage = data['message'];
        if (updatedMessage != null &&
            updatedMessage['group_id'] == widget.groupId &&
            mounted) {
          final index = _messages.indexWhere(
            (m) => m['id'] == updatedMessage['id'],
          );
          if (index != -1) {
            setState(() {
              _messages[index] = updatedMessage;
            });
          }
        }
      } else if (event.eventName == 'ChatMessageDeleted') {
        final messageId = data['message_id'];
        final groupId = data['group_id'];
        if (messageId != null && groupId == widget.groupId && mounted) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == messageId);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _eventSubscription.cancel();
    _pusherService.unsubscribeFromChannel('chat');
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final messageData = await _apiService.getMessages(widget.groupId);
      if (!mounted) return;

      setState(() {
        _messages = messageData['data'] ?? [];
        // populate cache map
        _messageById
          ..clear()
          ..addEntries(
            _messages
                .where((m) => m is Map && m['id'] != null)
                .map((m) => MapEntry<int, dynamic>(m['id'] as int, m)),
          );
        _hasMoreMessages =
            messageData['pagination']?['has_more_pages'] ?? false;
        _currentPage = messageData['pagination']?['current_page'] ?? 1;
        _isLoading = false;
      });

      if (_messages.isNotEmpty) {
        _apiService.markAsSeen(widget.groupId, _messages.last['id']);
      }

      _scrollToBottomDelayed();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreMessages() async {
    if (!_hasMoreMessages || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messageData = await _apiService.getMessages(
        widget.groupId,
        page: _currentPage + 1,
      );
      if (!mounted) return;

      setState(() {
        final older = (messageData['data'] as List?) ?? [];
        _messages.insertAll(0, older);
        for (final m in older) {
          if (m is Map && m['id'] != null) {
            _messageById[m['id']] = m;
          }
        }
        _hasMoreMessages =
            messageData['pagination']?['has_more_pages'] ?? false;
        _currentPage =
            messageData['pagination']?['current_page'] ?? _currentPage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final sentMessage = _replyToMessageId != null
          ? await _apiService.replyToMessage(_replyToMessageId!, text)
          : await _apiService.sendMessage(widget.groupId, text);
      if (sentMessage != null && mounted) {
        setState(() {
          _messages.add(sentMessage);
          if (sentMessage['id'] != null) {
            _messageById[sentMessage['id']] = sentMessage;
          }
          _messageController.clear();
          _replyToMessageId = null;
        });
        _scrollToBottomDelayed();
      }
    } catch (e) {
      // ignore for now
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
        'ogg',
      ],
    );

    if (result != null) {
      final path = result.files.single.path!;
      final type = _getFileType(path);

      if (type != null) {
        final sentMessage = await _apiService.uploadFile(
          widget.groupId,
          path,
          type: type,
          replyToMessageId: _replyToMessageId,
        );

        if (sentMessage != null && mounted) {
          setState(() {
            _messages.add(sentMessage);
            _replyToMessageId = null;
          });
          _scrollToBottomDelayed();
        }
      } else {
        // Handle unsupported file type
      }
    }
  }

  String? _getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'image';
    } else if (extension == 'pdf') {
      return 'pdf';
    } else if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extension)) {
      return 'voice';
    }
    return null;
  }

  String _sanitizeUrl(String? url) => (url ?? '').replaceAll('\\', '');

  // Build a usable file URL from message object
  String? _resolveFileUrl(Map msg) {
    final rawUrl = _sanitizeUrl(msg['file_url']?.toString());
    if (rawUrl.isNotEmpty) return rawUrl;
    final filePath = (msg['file_path'] ?? '').toString().replaceAll('\\', '');
    if (filePath.isEmpty) return null;
    // backend stores under public/chat/... and serves from /storage/chat/...
    final storagePath = filePath.replaceFirst(RegExp(r'^public/'), 'storage/');
    // try to infer host from API base in ApiService
    // since base already includes https host, we hardcode known base host to avoid coupling
    final host = baseUrl.endsWith('/') ? baseUrl : baseUrl;
    return host + (storagePath.startsWith('/') ? storagePath : '/$storagePath');
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return DateFormat('HH:mm').format(dt.toLocal());
    } catch (_) {
      return iso;
    }
  }

  // Fetch parent message for reply preview if not cached
  Future<Map?> _ensureParentLoaded(int parentId) async {
    if (_messageById.containsKey(parentId)) {
      return _messageById[parentId] as Map?;
    }
    try {
      final resp = await _apiService.getSingleMessage(parentId);
      if (resp is Map && (resp as Map).isNotEmpty) {
        // some APIs wrap in {success,data} or direct
        final dynamic maybeData = (resp as Map?)?['data'] ?? resp;
        if (maybeData is Map && maybeData['id'] != null) {
          _messageById[maybeData['id']] = maybeData;
          return maybeData;
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildReplyPreview(dynamic msg) {
    final parentId = msg['reply_to_message_id'];
    if (parentId == null) return const SizedBox.shrink();
    final cached = _messageById[parentId] as Map?;
    final base = Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Replying...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );

    if (cached != null) {
      final pType = (cached['type'] ?? 'text').toString();
      String label;
      if (pType == 'text') {
        label = (cached['content'] ?? '').toString();
      } else if (pType == 'image') {
        label = '[Image]';
      } else if (pType == 'voice') {
        label = '[Voice]';
      } else {
        final name = (cached['original_name'] ?? '').toString();
        label = name.isNotEmpty ? '[File] $name' : '[File]';
      }
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.reply, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // trigger async load
    return FutureBuilder<Map?>(
      future: _ensureParentLoaded(
        parentId is int ? parentId : int.tryParse(parentId.toString()) ?? -1,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          final m = snapshot.data!;
          final type = (m['type'] ?? 'text').toString();
          String label;
          if (type == 'text') {
            label = (m['content'] ?? '').toString();
          } else if (type == 'image') {
            label = '[Image]';
          } else if (type == 'voice') {
            label = '[Voice]';
          } else {
            final name = (m['original_name'] ?? '').toString();
            label = name.isNotEmpty ? '[File] $name' : '[File]';
          }
          return Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return base;
      },
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.green;
      case 'hold':
        return Colors.orange;
      case 'cancel':
      case 'unbooked':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return 'Booked';
      case 'hold':
        return 'Hold';
      case 'cancel':
        return 'Cancel';
      case 'unbooked':
        return 'Unbooked';
      default:
        return status;
    }
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

  void _showActionsDialog(dynamic msg) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.reply),
              title: Text('Reply'),
              onTap: () {
                setState(() => _replyToMessageId = msg['id']);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () async {
                // capture navigator before async to avoid context-after-await lint
                final navigator = Navigator.of(context);
                final type = (msg['type'] ?? 'text').toString();
                try {
                  if (type == 'text') {
                    final text = (msg['content'] ?? '').toString();
                    if (text.isNotEmpty) {
                      await SharePlus.instance.share(ShareParams(text: text));
                    }
                  } else {
                    final resolvedUrl = _resolveFileUrl(msg);
                    final fileUrl = _sanitizeUrl(
                      resolvedUrl ?? (msg['content'] ?? ''),
                    );
                    if (fileUrl.isNotEmpty) {
                      await download_util.shareFileFromUrl(
                        fileUrl,
                        text: (msg['original_name'] ?? '').toString(),
                      );
                    }
                  }
                } catch (_) {}
                if (mounted) navigator.pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.forward),
              title: Text('Forward'),
              onTap: () {
                _showForwardDialog(msg['id']);
              },
            ),
            if (_apiService.userType == 'admin')
              ListTile(
                leading: Icon(Icons.bookmark),
                title: Text('Set Status'),
                onTap: () {
                  _showStatusDialog(msg['id']);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                _deleteMessage(msg['id']);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
              title: Text('Forward to...'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return CheckboxListTile(
                      title: Text(group['name'] ?? ''),
                      value: selected.contains(group['id']),
                      onChanged: (isSelected) {
                        setState(() {
                          if (isSelected == true) {
                            selected.add(group['id']);
                          } else {
                            selected.remove(group['id']);
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
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selected.toList()),
                  child: Text('Forward'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedGroupIds != null && selectedGroupIds.isNotEmpty) {
      await _apiService.forwardMessage(messageId, selectedGroupIds);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close the actions bottom sheet
    }
  }

  void _showStatusDialog(int messageId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Message Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Hold'),
                onTap: () {
                  _apiService.setMessageStatus(messageId, 'hold');
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Booked'),
                onTap: () {
                  _apiService.setMessageStatus(messageId, 'booked');
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Cancel'),
                onTap: () {
                  _apiService.setMessageStatus(messageId, 'cancel');
                  Navigator.of(context).pop();
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
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteMessage(messageId);
      if (success && mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg['id'] == messageId);
        });
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;
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
    } catch (_) {}
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      if (mounted) setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        final sentMessage = await _apiService.uploadFile(
          widget.groupId,
          path,
          type: 'voice',
          replyToMessageId: _replyToMessageId,
        );
        if (sentMessage != null && mounted) {
          setState(() {
            _messages.add(sentMessage);
            _replyToMessageId = null;
          });
          _scrollToBottomDelayed();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundImage: AssetImage('assets/images/grp.png'),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 8),
            Text(widget.groupName, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading && _messages.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Container(
                color: kBackground,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0 && _hasMoreMessages) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final msgIndex = _hasMoreMessages ? index - 1 : index;
                    final msg = _messages[msgIndex];
                    final currentUserId = _apiService.currentUserId;
                    final msgUserId = msg['user_id'] ?? msg['user']?['id'];
                    final isMe = msgUserId != null &&
                        currentUserId != null &&
                        msgUserId == currentUserId;

                    ImageProvider userImage;
                    final imageUrl = msg['user']?['avatar'];
                    if (imageUrl != null &&
                        imageUrl != 'https://via.placeholder.com/150') {
                      userImage = NetworkImage(imageUrl);
                    } else {
                      userImage = const AssetImage('assets/images/usr.png');
                    }

                    Widget messageContent;
                    final type = msg['type'] ?? 'text';
                    final resolvedUrl = _resolveFileUrl(msg);
                    final fileUrl = _sanitizeUrl(
                      resolvedUrl ?? (msg['content'] ?? ''),
                    );
                    if (type == 'image') {
                      messageContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) =>
                                    Dialog(child: Image.network(fileUrl)),
                              );
                            },
                            child: Image.network(
                              fileUrl,
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'Open',
                                onPressed: () =>
                                    download_util.downloadAndOpen(fileUrl),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                tooltip: 'Share',
                                onPressed: () =>
                                    download_util.shareFileFromUrl(fileUrl),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else if (type == 'voice') {
                      messageContent = voice_widget.VoiceMessagePlayerWidget(
                        url: fileUrl,
                      );
                    } else if (type == 'pdf' || type == 'file') {
                      final displayName =
                          (msg['original_name'] ?? fileUrl.split('/').last)
                              .toString();
                      messageContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.insert_drive_file),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'Open',
                                onPressed: () =>
                                    download_util.downloadAndOpen(fileUrl),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download),
                                tooltip: 'Download',
                                onPressed: () async {
                                  await download_util.downloadFile(fileUrl);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                tooltip: 'Share',
                                onPressed: () => download_util.shareFileFromUrl(
                                  fileUrl,
                                  text: displayName,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      messageContent = Text(
                        msg['content'] ?? '',
                        style: const TextStyle(color: Colors.black87),
                      );
                    }

                    // reply preview
                    final replyWidget = _buildReplyPreview(msg);

                    return GestureDetector(
                      onLongPress: () => _showActionsDialog(msg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: userImage,
                                ),
                              ),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? Colors.blue.shade100 : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withAlpha(26),
                                    spreadRadius: 1,
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      msg['user']?['name'] ??
                                          msg['sender_name'] ??
                                          'Unknown User',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  replyWidget,
                                  messageContent,
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg['created_at']?.toString()),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (msg['status'] != null)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            (msg['status'] ?? '').toString(),
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(
                                            (msg['status'] ?? '').toString(),
                                          ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _statusColor(
                                              (msg['status'] ?? '').toString(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToMessageId != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.reply, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FutureBuilder<Map?>(
                                  future: _ensureParentLoaded(
                                    _replyToMessageId!,
                                  ),
                                  builder: (context, snapshot) {
                                    final txt = (snapshot.data?['content'] ??
                                            'Replying...')
                                        .toString();
                                    return Text(
                                      txt,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _replyToMessageId = null),
                        ),
                      ],
                    ),
                  ),
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          'Recording ${_recordSeconds}s',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: _isRecording ? Colors.red : Colors.grey[700],
                      ),
                      onPressed: () async {
                        if (_isRecording) {
                          await _stopRecordingAndSend();
                        } else {
                          await _startRecording();
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Type your message...',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isRecording,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isRecording ? null : _uploadFile,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isRecording ? null : _sendMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
