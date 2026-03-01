import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Single common utility function to generate normalized, sorted conversation IDs
  String generateConversationId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return list.join('_');
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String receiverId,
    required String receiverName,
    required String receiverRole,
    required String text,
    String? lotId,
  }) async {
    final convId = generateConversationId(senderId, receiverId);

    final msgData = {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    // Construct participant info explicitly 
    final participantNames = {
      senderId: senderName,
      receiverId: receiverName,
    };

    final participantRoles = {
      senderId: senderRole,
      receiverId: receiverRole,
    };

    final convRef = _db.collection('conversations').doc(convId);

    await _db.runTransaction((transaction) async {
      final convDoc = await transaction.get(convRef);
      
      if (!convDoc.exists) {
        transaction.set(convRef, {
          'participants': [senderId, receiverId],
          'participantNames': participantNames,
          'participantRoles': participantRoles,
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {
            senderId: 0,
            receiverId: 1,
          },
          'lotId': lotId ?? '',
        });
      } else {
        final currentUnread = convDoc.data()?['unreadCount'] as Map<String, dynamic>? ?? {};
        final receiverUnread = (currentUnread[receiverId] as int? ?? 0) + 1;
        
        transaction.update(convRef, {
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount.$receiverId': receiverUnread,
          'participantNames': participantNames,
          'participantRoles': participantRoles,
        });
      }

      final newMessageRef = convRef.collection('messages').doc();
      transaction.set(newMessageRef, msgData);
    });
  }

  Future<void> markConversationRead(String conversationId, String userId) async {
    final convRef = _db.collection('conversations').doc(conversationId);
    
    // Reset unread count for this user
    await convRef.update({
      'unreadCount.$userId': 0,
    });

    // Mark all currently unread messages belonging to the other person as read
    final messagesSnap = await convRef
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in messagesSnap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
