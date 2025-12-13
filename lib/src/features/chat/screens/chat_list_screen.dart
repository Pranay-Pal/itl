import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:icons_plus/icons_plus.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/bookings/bookings.dart';
import 'package:itl/src/features/chat/screens/chat_screen.dart';
import 'package:itl/src/config/constants.dart';

import 'package:itl/src/services/pusher_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/services/shared_intent_service.dart';
import 'package:share_handler/share_handler.dart';
import 'package:itl/src/services/theme_service.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  // Filter
  bool _showUnreadOnly = false;
  Timer? _debounce;

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
    final sharedService = SharedIntentService();
    // note: Service is started in main.dart, so we just consume/listen here.

    // 1. Check for buffered initial intent (app launch)
    final initial = sharedService.consumeInitial();
    if (initial.isNotEmpty) {
      // Delay slightly to ensure context is ready or wait for frame
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _processPendingShared(initial);
      });
    }

    // 2. Listen for new intents (background/foreground)
    _sharedDataSubscription = sharedService.attachmentsStream.listen((atts) {
      if (atts.isNotEmpty) {
        _processPendingShared(atts);
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
              // Increment unread only if message isn't from current user
              final currentUserId = _apiService.currentUserId;
              final msgUserId = message['user_id'] ?? message['user']?['id'];
              final isMine =
                  currentUserId != null && msgUserId == currentUserId;
              if (!isMine) {
                final prev = group['unread'];
                int current = 0;
                if (prev is int) current = prev;
                if (prev is String) current = int.tryParse(prev) ?? 0;
                if (prev is double) current = prev.round();
                group['unread'] = current + 1;
              }

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
      await _refreshUnreadCounts();
      _fetchLatestMessagesForGroups();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUnreadCounts() async {
    try {
      debugPrint("Fetching unread counts...");
      final data = await _apiService.getUnreadCounts();
      if (!mounted) return;
      if (data == null || data['data'] == null) {
        debugPrint("Unread counts data is null");
        return;
      }
      // API returns a Map of ID -> Count
      final unreadMap = data['data'];
      if (unreadMap is! Map) {
        debugPrint("Unread data is not a Map: $unreadMap");
        return;
      }

      setState(() {
        for (var i = 0; i < _chatGroups.length; i++) {
          final g = _chatGroups[i] as Map;
          final id = g['id'];
          final idStr = id.toString();

          if (unreadMap.containsKey(idStr)) {
            final u = unreadMap[idStr];
            int unread = 0;
            if (u is int) unread = u;
            if (u is String) unread = int.tryParse(u) ?? 0;
            if (u is double) unread = u.round(); // cast double to int if needed
            g['unread'] = unread;
          }
        }
      });
    } catch (e) {
      debugPrint("Error refreshing unread counts: $e");
    }
  }

  Future<void> _fetchLatestMessagesForGroups() async {
    for (var i = 0; i < _chatGroups.length; i++) {
      final g = _chatGroups[i] as Map;
      final groupId = g['id'];
      if (groupId is int) {
        try {
          final response = await _apiService.getMessages(groupId, page: 1);
          if (response['data'] is List &&
              (response['data'] as List).isNotEmpty) {
            final latest = (response['data'] as List).first;
            if (mounted) {
              setState(() {
                g['latest'] = latest;
              });
              debugPrint(
                  "Fetched latest msg for $groupId: ${latest['content']}");
            }
          }
        } catch (e) {
          debugPrint("Failed to fetch latest msg for $groupId: $e");
        }
      }
    }
  }

  void _showCreateGroupOrUserDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey[400] : const Color(0xFF075E54);
    final textColor = isDark ? Colors.white : Colors.black87;

    // Show a bottom sheet or dialog to choose between creating a group or searching for a user
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(EvaIcons.people_outline, color: iconColor),
              title: Text('Create New Group',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupDialog();
              },
            ),
            ListTile(
              leading: Icon(EvaIcons.person_add_outline, color: iconColor),
              title: Text('Start Direct Message',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _focusSearchToFindUsers();
              },
            ),
          ],
        );
      },
    );
  }

  void _focusSearchToFindUsers() {
    _searchFocus.requestFocus();
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Create New Group',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
          content: TextField(
            controller: groupNameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Enter group name",
              hintStyle:
                  TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark ? const Color(0xFF00A884) : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF00A884) : const Color(0xFF075E54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
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
              child:
                  const Text('Create', style: TextStyle(color: Colors.white)),
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
    // Determine status bar brightness based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Use standard AppBar for WhatsApp feel
      appBar: AppBar(
        flexibleSpace: isDark
            ? null
            : Container(
                decoration: BoxDecoration(gradient: kBlueGradient),
              ),
        backgroundColor: isDark ? Theme.of(context).primaryColor : null,
        automaticallyImplyLeading: false,
        title: Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22, // Slightly larger for emphasis
            color: isDark ? Colors.grey[400] : Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.table_chart,
                color: isDark ? Colors.grey[400] : Colors.white),
            tooltip: 'Bookings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingDashboardScreen(
                      userCode: _apiService.userCode ?? ''),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.grey[400] : Colors.white,
            ),
            onPressed: () {
              ThemeService().toggleTheme();
            },
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: Icon(Icons.home,
                color: isDark ? Colors.grey[400] : Colors.white),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            tooltip: 'Back to Home',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                icon: Icon(Icons.search,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                hintText: 'Search...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() {
                  _isSearching = val.isNotEmpty;
                });
                _onSearchChanged(val);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryBlue,
        onPressed: _showCreateGroupOrUserDialog,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('All', !_showUnreadOnly, () {
                    setState(() => _showUnreadOnly = false);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unread', _showUnreadOnly, () {
                    setState(() => _showUnreadOnly = true);
                  }),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildListContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed _buildCustomHeader as we rely on standard AppBar now

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE7FCE3) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF008069) : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isSearching) {
      final query = _searchController.text.toLowerCase().trim();

      // 1. Local matches from existing chats
      final localMatches = _chatGroups.where((g) {
        final name = (g['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();

      // 2. API results (exclude those we already have chats with)

      // Filter out API results that are already in local matches (optional, but good UX)
      // Usually API returns USERS, local are GROUPS.
      // We'll just show both sections for clarity.

      if (localMatches.isEmpty && _searchResults.isEmpty) {
        return const Center(child: Text("No users found"));
      }

      return ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          if (localMatches.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text("Chats",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ...localMatches.map((g) => _buildChatItem(g)),
          ],
          if (_searchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text("Global Search",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ..._searchResults.map((u) => _buildUserItem(u)),
          ],
        ],
      );
    }

    // Standard Filter (All / Unread)
    List<dynamic> displayGroups = _chatGroups;
    if (_showUnreadOnly) {
      displayGroups = _chatGroups.where((g) => (g['unread'] ?? 0) > 0).toList();
    }

    if (displayGroups.isEmpty) {
      if (_showUnreadOnly) {
        return const Center(
            child:
                Text("No unread chats", style: TextStyle(color: Colors.grey)));
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(EvaIcons.message_circle_outline,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text("No chats yet", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 0, bottom: 80),
      itemCount: displayGroups.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        return _buildChatItem(displayGroups[index]);
      },
    );
  }

  Widget _buildChatItem(dynamic group) {
    final name = group['name'] ?? 'Group';
    final id = group['id'] ?? 0;
    final unread = (group['unread'] ?? 0);

    ImageProvider avatar;
    if (group['avatar'] != null &&
        group['avatar'] != 'https://via.placeholder.com/150') {
      avatar = NetworkImage(group['avatar']);
    } else {
      avatar = const AssetImage('assets/images/grp.png');
    }

    final latestMessage = group['latest'];
    String subtitle = 'No messages';
    if (latestMessage != null) {
      final sender = latestMessage['sender_name'] ?? '';
      final content = latestMessage['content'] ?? '';
      subtitle = sender.isNotEmpty ? '$sender: $content' : content;
      if (subtitle.trim().isEmpty) {
        subtitle = '[Media]';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return InkWell(
      onTap: () {
        setState(() {
          final prev = group['unread'];
          if (prev != null) group['unread'] = 0;
        });
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(groupId: id, groupName: name),
              ),
            )
            .then((_) => _fetchData());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: avatar,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        latestMessage?['created_at'] != null
                            ? _formatTime(latestMessage['created_at'])
                            : '',
                        style: TextStyle(
                            fontSize: 12,
                            color: unread > 0
                                ? const Color(0xFF25D366)
                                : subtitleColor,
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: subtitleColor,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unread',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _searchResults = [];
        });
        return;
      }

      setState(() {
        // Trigger rebuild to filter chats locally
      });

      try {
        final results = await _apiService.searchUsers(query);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
        });
      } catch (e) {
        debugPrint("Search error: $e");
      }
    });
    // Trigger rebuild to update local filter immediately
    setState(() {});
  }

  Widget _buildUserItem(dynamic user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: Text(
            (user['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      title: Text(user['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle:
          Text(user['email'] ?? '', style: const TextStyle(color: Colors.grey)),
      onTap: () async {
        setState(() => _isLoading = true);
        final navigator = Navigator.of(context);
        final newGroup = await _apiService.createDirectMessage(user['id']);
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _isSearching = false;
          _searchController.clear();
          _searchResults = [];
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
      },
    );
  }
}
