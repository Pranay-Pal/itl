import 'package:itl/src/config/base_url.dart';

class ChatContact {
  final String id; // "user:1", "group:5", "admin:1"
  final int originalId;
  final String name;
  final String type; // "user", "group", "admin"
  final String? avatar;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isOnline; // Optional, if we track presence

  ChatContact({
    required this.id,
    required this.originalId,
    required this.name,
    required this.type,
    this.avatar,
    this.lastMessage,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: json['id']?.toString() ?? '',
      originalId: json['orig_id'] is int
          ? json['orig_id']
          : (int.tryParse(json['orig_id']?.toString() ?? '0') ?? 0),
      name: json['name']?.toString() ?? 'Unknown',
      type: json['type']?.toString() ?? 'user',
      avatar: json['avatar']?.toString(),
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] is int
          ? json['unread_count']
          : (int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0),
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final String senderType; // "user", "admin", "system"
  final String senderName;
  final String? senderAvatar;
  final String receiverId; // "user:2", "group:1"
  final String receiverType;
  final String? content;
  final DateTime createdAt;

  DateTime? readAt;
  final List<ChatAttachment> attachments;
  final String? audioUrl;
  final String? fileUrl;
  Map<String, List<String>> reactions; // emoji -> [user_ids]
  final ChatMessage? replyTo;
  bool isMine;

  String get type {
    if (audioUrl != null) return 'voice';
    if (attachments.isNotEmpty) return 'file';
    return 'text';
  }

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    this.senderAvatar,
    required this.receiverId,
    required this.receiverType,
    this.content,
    required this.createdAt,
    this.readAt,
    this.attachments = const [],
    this.audioUrl,
    this.fileUrl,
    this.reactions = const {},
    this.replyTo,
    this.isMine = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {int? currentUserId}) {
    final senderId = json['sender_id'] is int
        ? json['sender_id']
        : (int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0);

    // Parse attachments
    List<ChatAttachment> atts = [];
    if (json['attachments'] != null && json['attachments'] is List) {
      atts = (json['attachments'] as List)
          .map((e) => ChatAttachment.fromJson(e))
          .toList();
    }

    // Parse reactions
    Map<String, List<String>> reacts = {};
    if (json['reactions'] != null && json['reactions'] is Map) {
      (json['reactions'] as Map).forEach((k, v) {
        if (v is List) {
          reacts[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    ChatMessage? replyMsg;
    if (json['reply_to'] != null && json['reply_to'] is Map) {
      // reply_to object is a simplified message snippet usually
      replyMsg = ChatMessage.fromSnippet(json['reply_to']);
    }

    return ChatMessage(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      senderId: senderId,
      senderType: json['sender_type']?.toString() ?? 'user',
      senderName: json['sender_name']?.toString() ?? 'Unknown',
      senderAvatar: json['sender_avatar']?.toString(),
      receiverId: json['receiver_id']?.toString() ?? '',
      receiverType: json['receiver_type']?.toString() ?? 'user',
      content: json['content']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      attachments: atts,
      audioUrl: _resolveUrl(json['audio_url']),
      fileUrl: _resolveUrl(json['file_url']),
      reactions: reacts,
      replyTo: replyMsg,
      isMine: currentUserId != null && senderId == currentUserId,
    );
  }

  // For simplified objects in reply_to or snippet lists
  factory ChatMessage.fromSnippet(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      senderId: 0, // usually not provided in snippet or unimportant
      senderType: 'user',
      senderName: json['sender_name']?.toString() ?? '',
      receiverId: '',
      receiverType: '',
      content: json['snippet']?.toString() ?? json['content']?.toString(),
      createdAt: DateTime.now(),
      attachments: [],
    );
  }

  static String? _resolveUrl(String? path) {
    if (path == null) return null;
    if (path.startsWith('http')) return path;
    // Ensure base URL doesn't have double slash issues
    String base = baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (path.startsWith('/')) return '$base$path';
    return '$base/$path';
  }
}

class ChatAttachment {
  final String url;
  final String name;
  final int size;
  final String? type; // 'pdf', 'image', etc. inferred

  ChatAttachment(
      {required this.url, required this.name, this.size = 0, this.type});

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url']?.toString();
    final url = ChatMessage._resolveUrl(rawUrl) ?? '';

    return ChatAttachment(
      url: url,
      name: json['name']?.toString() ?? 'File',
      size: json['size'] is int
          ? json['size']
          : (int.tryParse(json['size']?.toString() ?? '0') ?? 0),
      type: _inferType(url),
    );
  }

  static String _inferType(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
    if (ext == 'pdf') return 'pdf';
    return 'file';
  }
}
