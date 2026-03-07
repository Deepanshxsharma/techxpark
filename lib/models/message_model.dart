import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime? timestamp;
  final bool read;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.timestamp,
    this.read = false,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> m) {
    return MessageModel(
      id: id,
      senderId: m['senderId'] ?? '',
      senderName: m['senderName'] ?? '',
      senderRole: m['senderRole'] ?? 'customer',
      text: m['text'] ?? m['message'] ?? '', // Handle legacy 'message' field
      timestamp: (m['timestamp'] as Timestamp?)?.toDate(),
      read: m['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': read,
      };
}
