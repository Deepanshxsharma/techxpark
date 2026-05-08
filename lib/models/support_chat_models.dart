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
  final List<SupportChatAction> actions;

  const SupportChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    this.timestamp,
    this.isRead = false,
    this.isTyping = false,
    this.isSystem = false,
    this.actions = const [],
  });

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';
  SupportChatAction? get action => actions.isEmpty ? null : actions.first;

  factory SupportChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final actions = <SupportChatAction>[];
    final rawActions = data['actions'];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is Map<String, dynamic>) {
          actions.add(SupportChatAction.fromMap(item));
        } else if (item is Map) {
          actions.add(
            SupportChatAction.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    if (actions.isEmpty) {
      final legacyAction = data['action'];
      if (legacyAction is Map<String, dynamic>) {
        actions.add(SupportChatAction.fromMap(legacyAction));
      } else if (legacyAction is Map) {
        actions.add(
          SupportChatAction.fromMap(Map<String, dynamic>.from(legacyAction)),
        );
      }
    }

    return SupportChatMessage(
      id: id,
      text: data['text']?.toString() ?? '',
      sender: data['sender']?.toString() ?? 'ai',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] == true,
      isTyping: data['isTyping'] == true,
      isSystem: data['isSystem'] == true,
      actions: actions,
    );
  }
}
