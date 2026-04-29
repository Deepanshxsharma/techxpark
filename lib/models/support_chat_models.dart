import 'package:cloud_firestore/cloud_firestore.dart';

class SupportChatThread {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String assistantType;
  final DateTime? createdAt;

  const SupportChatThread({
    required this.id,
    required this.title,
    required this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.assistantType = 'ai',
    this.createdAt,
  });

  factory SupportChatThread.fromMap(String id, Map<String, dynamic> data) {
    return SupportChatThread(
      id: id,
      title: data['title']?.toString().trim().isNotEmpty == true
          ? data['title'].toString().trim()
          : 'AI Support',
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      assistantType: data['assistantType']?.toString() ?? 'ai',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SupportChatAction {
  final String type;
  final String label;
  final Map<String, dynamic> payload;

  const SupportChatAction({
    required this.type,
    required this.label,
    this.payload = const {},
  });

  factory SupportChatAction.fromMap(Map<String, dynamic> data) {
    return SupportChatAction(
      type: data['type']?.toString() ?? '',
      label: data['label']?.toString() ?? '',
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'label': label,
    'payload': payload,
  };
}

class SupportChatMessage {
  final String id;
  final String text;
  final String sender;
  final DateTime? timestamp;
  final bool isRead;
  final bool isTyping;
  final bool isSystem;
  final SupportChatAction? action;

  const SupportChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    this.timestamp,
    this.isRead = false,
    this.isTyping = false,
    this.isSystem = false,
    this.action,
  });

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';

  factory SupportChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return SupportChatMessage(
      id: id,
      text: data['text']?.toString() ?? '',
      sender: data['sender']?.toString() ?? 'ai',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] == true,
      isTyping: data['isTyping'] == true,
      isSystem: data['isSystem'] == true,
      action: data['action'] is Map<String, dynamic>
          ? SupportChatAction.fromMap(data['action'] as Map<String, dynamic>)
          : data['action'] is Map
          ? SupportChatAction.fromMap(
              Map<String, dynamic>.from(data['action'] as Map),
            )
          : null,
    );
  }
}
