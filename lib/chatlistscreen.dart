import 'package:flutter/material.dart';

// --- COLOR CONSTANTS ---
const Color kPrimaryBlue = Color(0xFF007AFF);
const Color kLightBlueVariant = Color(0xFFEBF5FF);
const Color kPrimaryText = Color(0xFF1C1C1E);
const Color kSecondaryText = Color(0xFF8A8A8E);
const Color kBackground = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
            // TODO: Navigate back to the main app
          },
        ),
        title: const Text(
          'Chats',
          style: TextStyle(
            color: kPrimaryText,
            fontWeight: FontWeight.bold,
          ),
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
      body: ListView.separated(
        itemCount: 4, // Example item count
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          thickness: 1,
          color: kBackground, // Use a very light grey for the divider
          indent: 80, // Indent to align with text, not avatar
        ),
        itemBuilder: (context, index) {
          // --- DUMMY DATA ---
          if (index == 0) {
            return _GroupChatItem(
              // Example of an unread group chat
              groupName: 'Design Team',
              lastMessageSender: 'Alex',
              lastMessage: 'We need to finalize the mockups.',
              time: '10:55 AM',
              unreadCount: 3,
              isUnread: true,
              // Use a placeholder or a network image for the group icon
              imageUrl: 'https://i.pravatar.cc/150?img=5',
            );
          }
          if (index == 1) {
            return _OneToOneChatItem(
              // Example of a read 1-to-1 chat
              name: 'Rohan Sharma',
              lastMessage: 'Sounds good!',
              time: 'Yesterday',
              unreadCount: 0,
              isUnread: false,
              imageUrl: 'https://i.pravatar.cc/150?img=12',
            );
          }
          if (index == 2) {
            return _OneToOneChatItem(
              // Example of a read chat with a photo
                name: 'Maria Garcia',
                lastMessage: '📷 Photo',
                time: '2d ago',
                unreadCount: 0,
                isUnread: false,
                imageUrl: 'https://i.pravatar.cc/150?img=32');
          }
          return _OneToOneChatItem(
            // Example of an unread 1-to-1 chat
            name: 'John Doe',
            lastMessage: 'Hey, are you free for a call?',
            time: '11:15 AM',
            unreadCount: 1,
            isUnread: true,
            imageUrl: 'https://i.pravatar.cc/150?img=60',
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

  const _OneToOneChatItem({
    required this.imageUrl,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to conversation screen
      },
      child: Container(
        color: isUnread ? kLightBlueVariant : kWhite,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(imageUrl),
            ),
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
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
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

  const _GroupChatItem({
    required this.imageUrl,
    required this.groupName,
    required this.lastMessageSender,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to conversation screen
      },
      child: Container(
        color: isUnread ? kLightBlueVariant : kWhite,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Squircle Avatar for Groups
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0), // Creates the squircle shape
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
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: lastMessage,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
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