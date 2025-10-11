import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:itl/api_service.dart';
import 'package:itl/chat_screen.dart';
import 'package:itl/constants.dart';
import 'package:itl/pusher_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/shared_intent_service.dart';
import 'package:share_handler/share_handler.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _apiService = ApiService();
  final PusherService _pusherService = PusherService();
  late StreamSubscription<PusherEvent> _eventSubscription;
  StreamSubscription? _sharedDataSubscription;

  List<dynamic> _chatGroups = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _showSearch = false;
  bool _isCreatingDM = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribeToPusherEvents();
    _initSharedIntentService();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _sharedDataSubscription?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _initSharedIntentService() {
    final sharedIntentService = SharedIntentService();
    sharedIntentService.start();

    // Process initial shared files
    Future.delayed(const Duration(milliseconds: 600), () {
      _processPendingShared(sharedIntentService.takePending());
    });

    // Listen for incoming shared files via platform stream
    _sharedDataSubscription = ShareHandlerPlatform.instance.sharedMediaStream
        .listen((SharedMedia media) {
      final atts = media.attachments ?? [];
      if (atts.isNotEmpty) {
        _processPendingShared(atts.whereType<SharedAttachment>().toList());
      }
    });
  }

  Future<void> _processPendingShared(List<SharedAttachment> attachments) async {
    if (attachments.isEmpty || !mounted) return;

    // Ask user to select a target group
    final int? targetGroupId = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share to which chat?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _chatGroups.length,
              itemBuilder: (context, index) {
                final g = _chatGroups[index];
                return ListTile(
                  title: Text(g['name'] ?? 'Group'),
                  onTap: () => Navigator.of(context).pop(g['id'] as int?),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (targetGroupId == null || !mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Sharing to chat...'),
              ],
            ),
          ),
        ),
      ),
    );

    for (final f in attachments) {
      final path = f.path;
      if (path.isEmpty) continue;
      final type = _mapSharedType(f, path);
      try {
        await _apiService.uploadFile(targetGroupId, path, type: type);
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close progress dialog

    // Navigate to the target chat
    final group = _chatGroups.firstWhere(
      (g) => g['id'] == targetGroupId,
      orElse: () => {'id': targetGroupId, 'name': 'Chat'},
    );
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              groupId: group['id'],
              groupName: group['name'] ?? 'Chat',
            ),
          ),
        )
        .then((_) => _fetchData());
  }

  String _mapSharedType(SharedAttachment f, String path) {
    final t = f.type.toString().toLowerCase();
    if (t.contains('image')) return 'image';
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(ext)) return 'voice';
    return 'file';
  }

  void _subscribeToPusherEvents() {
    _pusherService.subscribeToChannel('chat');
    _eventSubscription = _pusherService.eventStream.listen((event) {
      if (event.channelName == 'chat' &&
          event.eventName == 'ChatMessageBroadcast') {
        final data = jsonDecode(event.data);
        final message = data['message'];

        if (message != null && mounted) {
          final groupId = message['group_id'];
          final index = _chatGroups.indexWhere((g) => g['id'] == groupId);

          if (index != -1) {
            setState(() {
              final group = _chatGroups[index];
              group['latest'] = {
                'content': message['content'],
                'created_at': message['created_at'],
                'sender_name': message['sender_name'],
              };
              group['unread'] = (group['unread'] ?? 0) + 1;

              // Move the updated chat to the top
              final updatedGroup = _chatGroups.removeAt(index);
              _chatGroups.insert(0, updatedGroup);
            });
          }
        }
      }
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await _apiService.getChatGroups();
      if (!mounted) return;
      setState(() {
        _chatGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: groupNameController,
            decoration: const InputDecoration(hintText: "Enter group name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = groupNameController.text.trim();
                if (name.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  final newGroup = await _apiService.createGroup(name);
                  if (!mounted) return;
                  if (newGroup != null) {
                    navigator.pop();
                    _fetchData();
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(dynamic raw) {
    try {
      final t = raw.toString();
      if (t.contains('T')) {
        return t.split('T')[1].split('.').first.substring(0, 5);
      }
      return t;
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Chats',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 2),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (_showSearch) {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _searchFocus.requestFocus(),
                      );
                    } else {
                      _searchController.clear();
                      _searchFocus.unfocus();
                      _searchResults = [];
                    }
                  });
                },
              ),
            ],
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _showSearch
                  ? TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      decoration: InputDecoration(
                        hintText: 'Search chats or people',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                        filled: true,
                        fillColor: kWhite,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (q) async {
                        if (q.length > 2) {
                          final results = await _apiService.searchUsers(q);
                          final currentUserId = _apiService.currentUserId;
                          setState(() {
                            _searchResults = results
                                .where((user) => user['id'] != currentUserId)
                                .toList();
                          });
                        } else {
                          setState(() => _searchResults = []);
                        }
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _showSearch
                      ? _buildSearchResults()
                      : _buildChatList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(),
        backgroundColor: kPrimaryBlue,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      itemCount: _chatGroups.length,
      itemBuilder: (context, index) {
        final group = _chatGroups[index];
        final name = group['name'] ?? 'Group';
        final id = group['id'] ?? 0;

        ImageProvider avatar;
        if (group['avatar'] != null &&
            group['avatar'] != 'https://via.placeholder.com/150') {
          avatar = NetworkImage(group['avatar']);
        } else {
          avatar = const AssetImage('assets/images/grp.png');
        }

        final latestMessage = group['latest'];
        String subtitle = 'No messages yet';
        if (latestMessage != null) {
          final sender = latestMessage['sender_name'] ?? '';
          final content = latestMessage['content'] ?? '';
          subtitle = sender.isNotEmpty ? '$sender: $content' : content;
          if (subtitle.trim().isEmpty) {
            subtitle = '[Media]';
          }
        }

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ListTile(
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ChatScreen(groupId: id, groupName: name),
                    ),
                  )
                  .then((_) => _fetchData());
            },
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: kPrimaryBlue,
              backgroundImage: avatar,
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latestMessage?['created_at'] != null
                      ? _formatTime(latestMessage['created_at'])
                      : '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if ((group['unread'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${group['unread']}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isCreatingDM) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          title: Text(user['name'] ?? ''),
          subtitle: Text(user['email'] ?? ''),
          onTap: () async {
            setState(() {
              _isCreatingDM = true;
            });
            final navigator = Navigator.of(context);
            final newGroup = await _apiService.createDirectMessage(user['id']);
            if (!mounted) return;
            if (mounted) {
              setState(() {
                _isCreatingDM = false;
              });
              if (newGroup != null) {
                navigator
                    .push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          groupId: newGroup['id'],
                          groupName: newGroup['name'],
                        ),
                      ),
                    )
                    .then((_) => _fetchData());
              }
            }
          },
        );
      },
    );
  }
}
