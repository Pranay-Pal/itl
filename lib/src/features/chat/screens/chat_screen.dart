import 'dart:async';
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
import 'package:itl/src/services/download_util.dart' as download_util;
import 'package:itl/src/services/pusher_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/features/chat/widgets/voice_message_player_widget.dart'
    as voice_widget;

const String baseUrl =
    "https://mediumslateblue-hummingbird-258203.hostingersite.com/api";

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

  // If replying to a message, store its ID
  int? _replyToMessageId;

  // Voice recording
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Quick lookup for reply previews
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
    final channelName = 'private-chat-group.${widget.groupId}';
    await _pusherService.subscribeToChannel(channelName);
    _eventSubscription = _pusherService.eventStream.listen((event) {
      if (event.channelName == channelName &&
          event.eventName == 'message.sent') {
        _onNewMessage(event.data);
      }
    });
  }

  void _onNewMessage(dynamic data) {
    if (!mounted) return;
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      // Depending on structure: {message: {...}} or directly {...}
      final msg = decoded['message'] ?? decoded;
      setState(() {
        _messages.add(msg);
        if (msg['id'] != null) {
          _messageById[msg['id']] = msg;
        }
      });
      _markMessagesRead([msg]);
      _scrollToBottomDelayed();
    } catch (e) {
      debugPrint('Error parsing new message: $e');
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      // API returns {success: true, data: { current_page: 1, data: [...] }}
      final response = await _apiService.getMessages(widget.groupId, page: 1);

      if (mounted) {
        setState(() {
          if (response.isNotEmpty && response['data'] != null) {
            final innerData = response['data'];
            // innerData could be the list directly OR a pagination object
            List<dynamic> fetched = [];
            if (innerData is List) {
              fetched = innerData;
            } else if (innerData is Map && innerData['data'] is List) {
              fetched = innerData['data'];
            }

            _messages = List.from(fetched);
            // Cache for replies
            for (var m in _messages) {
              if (m['id'] != null) _messageById[m['id']] = m;
            }
            _hasMoreMessages = fetched.isNotEmpty;
          } else {
            _messages = [];
            _hasMoreMessages = false;
          }
          _isLoading = false;
        });
        _markMessagesRead(_messages); // Mark fetched messages as read
        _scrollToBottomDelayed();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markMessagesRead(List<dynamic> messages) {
    final currentUserId = _apiService.currentUserId;
    for (var msg in messages) {
      if (msg is Map) {
        final senderId = msg['user_id'] ?? msg['user']?['id'];
        final msgId = msg['id'];
        if (senderId != null && senderId != currentUserId && msgId is int) {
          // Only mark if status isn't already read
          final status = msg['status']?.toString();
          if (status != 'read') {
            _apiService.setMessageStatus(msgId, 'read');
            // update local status
            msg['status'] = 'read';
          }
        }
      }
    }
  }

  Future<void> _fetchMoreMessages() async {
    if (!_hasMoreMessages) return;
    try {
      final nextPage = _currentPage + 1;
      final response =
          await _apiService.getMessages(widget.groupId, page: nextPage);

      if (mounted) {
        setState(() {
          List<dynamic> fetched = [];
          if (response.isNotEmpty && response['data'] != null) {
            final innerData = response['data'];
            if (innerData is List) {
              fetched = innerData;
            } else if (innerData is Map && innerData['data'] is List) {
              fetched = innerData['data'];
            }
          }

          if (fetched.isEmpty) {
            _hasMoreMessages = false;
          } else {
            _messages.insertAll(0, fetched); // Prepend older messages
            _currentPage = nextPage;
            for (var m in fetched) {
              if (m['id'] != null) _messageById[m['id']] = m;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching more messages: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      Map<String, dynamic>? sentMessage;
      if (_replyToMessageId != null) {
        sentMessage =
            await _apiService.replyToMessage(_replyToMessageId!, text);
      } else {
        sentMessage = await _apiService.sendMessage(
          widget.groupId,
          text,
        );
      }

      if (sentMessage != null && mounted) {
        setState(() {
          _messages.add(sentMessage);
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
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload file')),
          );
        }
      } else {
        // Handle unsupported file type
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported file type')),
          );
        }
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

    final host = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final root = host.replaceAll('/api/', '').replaceAll('/api', '');
    return '$root/${storagePath.startsWith('/') ? storagePath.substring(1) : storagePath}';
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
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: kPrimaryBlue, width: 3)),
      ),
      child: Row(
        children: [
          Icon(EvaIcons.undo, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Loading reply...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontSize: 12,
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
        label = 'Photo';
      } else if (pType == 'voice') {
        label = 'Voice Message';
      } else {
        final name = (cached['original_name'] ?? '').toString();
        label = name.isNotEmpty ? 'File: $name' : 'File';
      }
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: kPrimaryBlue, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cached['sender_name'] ?? 'Reply',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
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
            label = 'Photo';
          } else if (type == 'voice') {
            label = 'Voice Message';
          } else {
            final name = (m['original_name'] ?? '').toString();
            label = name.isNotEmpty ? 'File: $name' : 'File';
          }
          return Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: kPrimaryBlue, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['sender_name'] ?? 'Reply',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: kPrimaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(EvaIcons.undo, color: kPrimaryBlue),
              title: Text('Reply', style: TextStyle()),
              onTap: () {
                setState(() => _replyToMessageId = msg['id']);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Icon(EvaIcons.share, color: kPrimaryBlue),
              title: Text('Share', style: TextStyle()),
              onTap: () async {
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
              leading: Icon(EvaIcons.arrow_forward, color: kPrimaryBlue),
              title: Text('Forward', style: TextStyle()),
              onTap: () {
                Navigator.of(context).pop();
                _showForwardDialog(msg['id']);
              },
            ),
            if (_apiService.userType == 'admin')
              ListTile(
                leading: Icon(EvaIcons.bookmark, color: kPrimaryBlue),
                title: Text('Set Status', style: TextStyle()),
                onTap: () {
                  Navigator.of(context).pop();
                  _showStatusDialog(msg['id']);
                },
              ),
            ListTile(
              leading: const Icon(EvaIcons.trash_2, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteMessage(msg['id']);
              },
            ),
            const SizedBox(height: 20),
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
              title: Text('Forward to...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return CheckboxListTile(
                      activeColor: kPrimaryBlue,
                      title: Text(group['name'] ?? '', style: TextStyle()),
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
          _messages.removeWhere((msg) => msg['id'] == messageId);
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgImage = isDark
        ? 'assets/images/InvertDoodleBG.jpg'
        : 'assets/images/DoodleBG.jpg';

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: isDark
            ? null
            : Container(
                decoration: BoxDecoration(gradient: kBlueGradient),
              ),
        backgroundColor: isDark ? Theme.of(context).primaryColor : null,
        leadingWidth: 70,
        automaticallyImplyLeading: false,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back,
                  color: isDark ? Colors.grey[400] : Colors.white),
              const SizedBox(width: 4),
              Hero(
                tag: 'group_avatar_${widget.groupId}',
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: const AssetImage('assets/images/grp.png'),
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'tap here for group info',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
            )
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert,
                color: isDark ? Colors.grey[400] : Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
            opacity:
                isDark ? 0.3 : 1.0, // Should reduce opacity if it's too busy
          ),
          color: isDark
              ? AppPalette.darkBackground
              : AppPalette.lightBackground, // Fallback
        ),
        child: Column(
          children: [
            // Chat List
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
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

                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
            ),

            // Input Area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map msg, bool isMe) {
    // userImage logic removed as WhatsApp mobile usually doesn't show avatars next to bubbles, just names in groups.

    final type = msg['type'] ?? 'text';
    final resolvedUrl = _resolveFileUrl(msg);
    final fileUrl = _sanitizeUrl(
      resolvedUrl ?? (msg['content'] ?? ''),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sentColor = isDark ? AppPalette.darkPrimary : AppPalette.lightPrimary;
    final whtColor = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    // Dark mode -> White text, Light mode -> Black text
    final textColor = isDark ? Colors.white : Colors.black;

    Widget contentWidget;
    if (type == 'image') {
      final heroTag = 'image_${msg['id'] ?? fileUrl}';
      contentWidget = GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) =>
                  _ImageViewerPage(url: fileUrl, heroTag: heroTag),
            ),
          );
        },
        child: Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fileUrl,
              width: 250,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        ),
      );
    } else if (type == 'voice') {
      contentWidget = voice_widget.VoiceMessagePlayerWidget(url: fileUrl);
    } else if (type == 'pdf' || type == 'file') {
      final displayName =
          (msg['original_name'] ?? fileUrl.split('/').last).toString();
      contentWidget = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: textColor, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.download, size: 24, color: textColor),
              onPressed: () => download_util.downloadFile(fileUrl),
            ),
          ],
        ),
      );
    } else {
      contentWidget = Text(
        msg['content'] ?? '',
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          height: 1.4,
        ),
      );
    }

    // Reply preview inside bubble
    final replyWidget = _buildReplyPreview(msg);

    // Swipe detection variables
    double dragDx = 0;

    return GestureDetector(
      onLongPress: () => _showActionsDialog(msg),
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) dragDx += details.delta.dx;
      },
      onHorizontalDragEnd: (_) {
        if (dragDx > 60) {
          setState(() => _replyToMessageId = msg['id']);
        }
        dragDx = 0;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe ? sentColor : whtColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(8),
                    topRight: const Radius.circular(8),
                    bottomLeft: Radius.circular(isMe ? 8 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      offset: const Offset(0, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show sender name in group for others
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          msg['user']?['name'] ?? msg['sender_name'] ?? '~',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800], // Random color usually
                          ),
                        ),
                      ),
                    replyWidget,
                    contentWidget,
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(msg['created_at']?.toString()),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Builder(builder: (context) {
                            final status = (msg['status'] ?? 'sent').toString();
                            IconData icon = Icons.check;
                            Color color = Colors.grey;
                            if (status == 'read') {
                              icon = Icons.done_all;
                              color = Colors.blue;
                            } else if (status == 'delivered') {
                              icon = Icons.done_all;
                            }
                            return Icon(
                              icon,
                              size: 16,
                              color: color,
                            );
                          }),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(8),
      // Background matches the main background/doodle or transparent
      // But standard whatsapp has separate input bar color?
      // Actually standard whatsapp just overlays.
      // We'll give it a solid background sometimes, but transparent works if we want bubble look.
      // Let's stick to safe defaults: Transparent allowing background to show, or solid?
      // Whatsapp has separate bar.
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Reply Indicator
            if (_replyToMessageId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text("Replying...",
                          style: TextStyle(color: hintColor)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _replyToMessageId = null),
                    )
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: Colors.grey[600]),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: "Message",
                              hintStyle: TextStyle(color: hintColor),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            onChanged: (val) {
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.attach_file, color: Colors.grey[600]),
                          onPressed: _uploadFile,
                        ),
                        if (_messageController.text.isEmpty)
                          IconButton(
                            icon:
                                Icon(Icons.camera_alt, color: Colors.grey[600]),
                            onPressed:
                                _uploadFile, // Reusing upload for camera for now or implement camera pick
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Mic / Send Button
                GestureDetector(
                  onTap: _isRecording
                      ? _stopRecordingAndSend
                      : (_messageController.text.isNotEmpty
                          ? _sendMessage
                          : null),
                  onLongPress: _startRecording,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: kPrimaryBlue,
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
                  style: const TextStyle(color: Colors.red),
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
