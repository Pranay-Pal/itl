import 'dart:async';
// unused import removed
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:icons_plus/icons_plus.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/bookings/bookings.dart';
import 'package:itl/src/features/chat/screens/chat_screen.dart';
import 'package:itl/src/features/chat/models/chat_models.dart';

import 'package:itl/src/services/pusher_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/services/shared_intent_service.dart';
import 'package:share_handler/share_handler.dart';
import 'package:itl/src/services/theme_service.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/common/animations/scale_button.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/config/app_palette.dart';

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

  List<ChatContact> _chatContacts = [];
  List<ChatContact> _searchResults = [];
  bool _isLoading = true;
  final Set<String> _typingUsers = {}; // ids of typing users (e.g. "user:1")
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
    final String? targetContactId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share to which chat?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _chatContacts.length,
              itemBuilder: (context, index) {
                final g = _chatContacts[index];
                return ListTile(
                  title: Text(g.name),
                  onTap: () => Navigator.of(context).pop(g.id),
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

    if (targetContactId == null || !mounted) return;

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
      // final type = _mapSharedType(f, path);
      try {
        // Assume group for now OR parse ID
        String type = 'user';
        if (targetContactId.startsWith('group:')) type = 'group';

        await _apiService.uploadChatFile(targetContactId, type, path);
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close progress dialog

    // Navigate to the target chat
    final contact = _chatContacts.firstWhere(
      (g) => g.id == targetContactId,
      orElse: () => ChatContact(
        id: targetContactId,
        originalId: 0,
        name: 'Chat',
        type: 'user',
      ),
    );
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              contactId: contact.id,
              contactName: contact.name,
              contactType: contact.type,
            ),
          ),
        )
        .then((_) => _fetchData());
  }

  void _subscribeToPusherEvents() {
    _pusherService.subscribeToChannel('chat'); // Public/Global channel if any?
    // Actually per-user private channel is better, but stick to existing pattern or updates
    // For now, re-fetch on generic events or specific user events

    _eventSubscription = _pusherService.eventStream.listen((event) {
      // Logic to update list dynamically
      if (['ChatMessageSent', 'ChatMessageBroadcast']
          .contains(event.eventName)) {
        // Optimization: parse and update local list instead of full fetch
        _fetchData();
      } else if (event.eventName == 'ChatTyping') {
        _handleTypingEvent(event.data);
      }
    });
  }

  void _handleTypingEvent(String dataVal) {
    try {
      final data = jsonDecode(dataVal);
      final senderId = data['sender_id'];
      final type = data['receiver_type'];
      final recId = data['receiver_id'];

      // If I am typing, ignore? No, list might show "You are typing" which is weird. Ignored.
      // But we don't know my ID easily here unless cached. Assuming event stream might echo.

      String? targetContactId;

      if (type == 'group') {
        targetContactId = 'group:$recId';
      } else if (senderId != null) {
        // DM: The person typing is the contact we want to update
        targetContactId = 'user:$senderId';
      }

      if (targetContactId != null) {
        if (mounted) {
          setState(() {
            _typingUsers.add(targetContactId!);
          });
        }

        // Clear after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingUsers.remove(targetContactId);
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error handling typing event: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    // Don't set loading to true on refresh to avoid flicker, only on initial load if needed
    // setState(() => _isLoading = true);

    try {
      final contacts = await _apiService.getChatContacts();
      if (!mounted) return;
      setState(() {
        _chatContacts = contacts;
        _isLoading = false;
      });
      // _refreshUnreadCounts(); // integrated in getChatContacts now
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // _refreshUnreadCounts and _fetchLatestMessagesForGroups removed as API does this efficiently now

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AuroraBackground(
        child: Column(
          children: [
            // Custom Glass Header (Replaces AppBar)
            SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Messages',
                        style: AppTypography.displaySmall
                            .copyWith(color: Colors.white, fontSize: 28)),
                    Row(
                      children: [
                        _buildHeaderIcon(Icons.table_chart, 'Bookings', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingDashboardScreen(
                                  userCode: _apiService.userCode ?? ''),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        _buildHeaderIcon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            'Theme', () {
                          ThemeService().toggleTheme();
                        }),
                        const SizedBox(width: 8),
                        _buildHeaderIcon(Icons.home, 'Home', () {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        }),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // 2. Search Bar (Glass)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 50,
                child: Row(
                  children: [
                    Icon(Icons.search,
                        color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          setState(() => _isSearching = val.isNotEmpty);
                          _onSearchChanged(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Filter Chips (Neon Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildNeonFilterChip('All', !_showUnreadOnly, () {
                    setState(() => _showUnreadOnly = false);
                  }),
                  const SizedBox(width: 12),
                  _buildNeonFilterChip('Unread', _showUnreadOnly, () {
                    setState(() => _showUnreadOnly = true);
                  }),
                ],
              ),
            ),

            // 4. Content List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                color: AppPalette.neonCyan,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppPalette.neonCyan))
                    : _buildListContent(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleButton(
        onTap: _showCreateGroupOrUserDialog,
        child: Container(
          width: 56,
          height: 56,
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
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.edit_square, color: Colors.white),
        ),
      ),
    );
  }

  // Removed _buildCustomHeader as we rely on standard AppBar now

  Widget _buildHeaderIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildNeonFilterChip(
      String label, bool isSelected, VoidCallback onTap) {
    return ScaleButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.neonCyan.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? AppPalette.neonCyan
                : Colors.white.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppPalette.neonCyan.withValues(alpha: 0.2),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppPalette.neonCyan : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isSearching) {
      final query = _searchController.text.toLowerCase().trim();
      final localMatches = _chatContacts.where((g) {
        final name = (g.name).toLowerCase();
        return name.contains(query);
      }).toList();

      if (localMatches.isEmpty && _searchResults.isEmpty) {
        return Center(
          child: Text("No conversations found",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        );
      }

      return ListView(
        padding: const EdgeInsets.only(bottom: 80, top: 0),
        children: [
          if (localMatches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text("RECENT",
                  style: AppTypography.labelSmall.copyWith(
                      color: AppPalette.neonCyan, letterSpacing: 1.5)),
            ),
            ...localMatches.map((g) => _buildChatItem(g)),
          ],
          if (_searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text("GLOBAL SEARCH",
                  style: AppTypography.labelSmall.copyWith(
                      color: AppPalette.neonCyan, letterSpacing: 1.5)),
            ),
            ..._searchResults.map((u) => _buildChatItem(u)),
          ],
        ],
      );
    }

    List<ChatContact> displayGroups = _chatContacts;
    if (_showUnreadOnly) {
      displayGroups = _chatContacts.where((g) => g.unreadCount > 0).toList();
    }

    if (displayGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(EvaIcons.message_circle_outline,
                size: 60, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text("No conversations yet",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: displayGroups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildChatItem(displayGroups[index]);
      },
    );
  }

  Widget _buildChatItem(ChatContact contact) {
    final name = contact.name;
    final id = contact.id;
    final unread = contact.unreadCount;

    ImageProvider avatar;
    if (contact.avatar != null &&
        contact.avatar != 'https://via.placeholder.com/150') {
      avatar = NetworkImage(contact.avatar!);
    } else {
      avatar = const AssetImage('assets/images/grp.png');
    }

    final latestMessage = contact.lastMessage;
    String subtitle = 'No messages';
    bool isTyping = _typingUsers.contains(id); // Hooked up to state
    Color subtitleColor = Colors.white54;

    if (latestMessage != null) {
      final sender = latestMessage.senderName;
      final content = latestMessage.content ?? '';

      // Smart subtitle logic
      if (latestMessage.type == 'file') {
        subtitle = '📎 Attachment';
      } else if (latestMessage.type == 'image') {
        subtitle = '📷 Image';
      } else if (latestMessage.type == 'voice') {
        subtitle = '🎤 Voice Note';
      } else {
        subtitle = content;
      }

      if (sender == 'You') {
        subtitle = 'You: $subtitle';
      }
    }

    // Glass List Item
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ScaleButton(
        onTap: () async {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                      contactId: id,
                      contactName: name,
                      contactType: contact.type),
                ),
              )
              .then((_) => _fetchData());
        },
        child: GlassContainer(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with active indicator (optional)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: unread > 0
                          ? AppPalette.neonCyan
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black26,
                  backgroundImage: avatar,
                  child: contact.type == 'group'
                      ? const Icon(Icons.people,
                          size: 16, color: Colors.white70)
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Info
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
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: unread > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (latestMessage != null)
                          Text(
                            _formatTime(latestMessage.createdAt),
                            style: AppTypography.labelSmall.copyWith(
                              color: unread > 0
                                  ? AppPalette.neonCyan
                                  : Colors.white38,
                              fontWeight: unread > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isTyping ? 'Typing...' : subtitle,
                            style: AppTypography.bodySmall.copyWith(
                              color: isTyping
                                  ? AppPalette.neonCyan
                                  : subtitleColor,
                              fontStyle: isTyping
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppPalette.neonCyan,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
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
        final results = await _apiService.searchContacts(query);
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
}
