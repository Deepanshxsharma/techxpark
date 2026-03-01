import 'package:cloud_firestore/cloud_firestore.dart';

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
/*  CHAT MODEL                                                              */
/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
class ChatModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String status; // open | closed
  final DateTime? createdAt;
  final int unreadByUser;
  final int unreadByAdmin;

  const ChatModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.lastMessage = '',
    this.lastMessageTime,
    this.status = 'open',
    this.createdAt,
    this.unreadByUser = 0,
    this.unreadByAdmin = 0,
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> m) {
    return ChatModel(
      id: id,
      userId: m['userId'] ?? '',
      userName: m['userName'] ?? '',
      userEmail: m['userEmail'] ?? '',
      lastMessage: m['lastMessage'] ?? '',
      lastMessageTime: (m['lastMessageTime'] as Timestamp?)?.toDate(),
      status: m['status'] ?? 'open',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      unreadByUser: m['unreadByUser'] ?? 0,
      unreadByAdmin: m['unreadByAdmin'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime != null
            ? Timestamp.fromDate(lastMessageTime!)
            : FieldValue.serverTimestamp(),
        'status': status,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'unreadByUser': unreadByUser,
        'unreadByAdmin': unreadByAdmin,
      };

  ChatModel copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    String? status,
    int? unreadByUser,
    int? unreadByAdmin,
  }) {
    return ChatModel(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      status: status ?? this.status,
      createdAt: createdAt,
      unreadByUser: unreadByUser ?? this.unreadByUser,
      unreadByAdmin: unreadByAdmin ?? this.unreadByAdmin,
    );
  }
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
/*  MESSAGE MODEL                                                           */
/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
class MessageModel {
  final String id;
  final String senderId;
  final String senderType; // user | admin
  final String message;
  final DateTime? timestamp;
  final bool read;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.message,
    this.timestamp,
    this.read = false,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> m) {
    return MessageModel(
      id: id,
      senderId: m['senderId'] ?? '',
      senderType: m['senderType'] ?? 'user',
      message: m['message'] ?? '',
      timestamp: (m['timestamp'] as Timestamp?)?.toDate(),
      read: m['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderType': senderType,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': read,
      };
}
