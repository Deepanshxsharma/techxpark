import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantNames;
  final Map<String, dynamic> participantRoles;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final Map<String, dynamic> unreadCount;
  final String? lotId;

  const ConversationModel({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantRoles,
    this.lastMessage = '',
    this.lastMessageTime,
    this.createdAt,
    this.unreadCount = const {},
    this.lotId,
  });

  factory ConversationModel.fromMap(String id, Map<String, dynamic> m) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(m['participants'] ?? []),
      participantNames: m['participantNames'] as Map<String, dynamic>? ?? {},
      participantRoles: m['participantRoles'] as Map<String, dynamic>? ?? {},
      lastMessage: m['lastMessage'] ?? '',
      lastMessageTime: (m['lastMessageTime'] as Timestamp?)?.toDate(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      unreadCount: m['unreadCount'] as Map<String, dynamic>? ?? {},
      lotId: m['lotId'],
    );
  }

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'participantNames': participantNames,
        'participantRoles': participantRoles,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime != null
            ? Timestamp.fromDate(lastMessageTime!)
            : FieldValue.serverTimestamp(),
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'unreadCount': unreadCount,
        'lotId': lotId,
      };
}
