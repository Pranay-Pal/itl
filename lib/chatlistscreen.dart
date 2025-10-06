import 'package:flutter/material.dart';
import 'package:itl/api_service.dart';
import 'package:itl/chat_screen.dart';

// --- COLOR CONSTANTS ---
const Color kPrimaryBlue = Color(0xFF007AFF);
const Color kLightBlueVariant = Color(0xFFEBF5FF);
const Color kPrimaryText = Color(0xFF1C1C1E);
const Color kSecondaryText = Color(0xFF8A8A8E);
const Color kBackground = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _chatGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChatGroups();
  }

  Future<void> _fetchChatGroups() async {
    try {
      final groups = await _apiService.getChatGroups();
      setState(() {
        _chatGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite, // Main background is white for a seamless list
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0.5, // Subtle shadow for a clean look
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryText),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Chats',
          style: TextStyle(color: kPrimaryText, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: kPrimaryText),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _chatGroups.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                color: kBackground,
                indent: 80,
              ),
              itemBuilder: (context, index) {
                final group = _chatGroups[index];
                return _GroupChatItem(
                  groupName: group['name'],
                  lastMessageSender: 'Admin', // Placeholder
                  lastMessage: '...', // Placeholder
                  time: '10:55 AM', // Placeholder
                  unreadCount: 0, // Placeholder
                  isUnread: false, // Placeholder
                  imageUrl: 'https://i.pravatar.cc/150?img=5', // Placeholder
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          groupId: group['id'],
                          groupName: group['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to new chat screen
        },
        backgroundColor: kPrimaryBlue,
        child: const Icon(Icons.add, color: kWhite),
      ),
    );
  }
}

// --- WIDGET FOR 1-TO-1 CHAT ITEM ---
class _OneToOneChatItem extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isUnread;
  final VoidCallback onTap;

  const _OneToOneChatItem({
    required this.imageUrl,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? kLightBlueVariant : kWhite,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundImage: NetworkImage(imageUrl)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isUnread ? kPrimaryBlue : kSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? kPrimaryBlue : kSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                if (isUnread)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: kPrimaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET FOR GROUP CHAT ITEM ---
class _GroupChatItem extends StatelessWidget {
  final String imageUrl;
  final String groupName;
  final String lastMessageSender;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isUnread;
  final VoidCallback onTap;

  const _GroupChatItem({
    required this.imageUrl,
    required this.groupName,
    required this.lastMessageSender,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? kLightBlueVariant : kWhite,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Squircle Avatar for Groups
            ClipRRect(
              borderRadius: BorderRadius.circular(
                16.0,
              ), // Creates the squircle shape
              child: Image.network(
                imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: isUnread ? kPrimaryBlue : kSecondaryText,
                      ),
                      children: [
                        TextSpan(
                          text: '$lastMessageSender: ',
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: lastMessage,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? kPrimaryBlue : kSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                if (isUnread)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: kPrimaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
