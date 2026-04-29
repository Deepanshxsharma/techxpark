import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/support_chat_models.dart';

class AiSupportService {
  AiSupportService._();
  static final instance = AiSupportService._();

  static const String defaultChatId = 'ai_support';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _chatDoc(String uid, String chatId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('support_chats')
        .doc(chatId);
  }

  CollectionReference<Map<String, dynamic>> _messagesCol(
    String uid,
    String chatId,
  ) {
    return _chatDoc(uid, chatId).collection('messages');
  }

  Stream<List<SupportChatMessage>> messagesStream({
    String chatId = defaultChatId,
  }) {
    final uid = _uid;
    if (uid == null) return const Stream<List<SupportChatMessage>>.empty();

    return _messagesCol(uid, chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupportChatMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<SupportChatThread?> threadStream({String chatId = defaultChatId}) {
    final uid = _uid;
    if (uid == null) return const Stream<SupportChatThread?>.empty();

    return _chatDoc(uid, chatId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return SupportChatThread.fromMap(snapshot.id, data);
    });
  }

  Stream<List<SupportChatThread>> threadsStream() {
    final uid = _uid;
    if (uid == null) return const Stream<List<SupportChatThread>>.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('support_chats')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupportChatThread.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> sendMessage(String text, {String chatId = defaultChatId}) async {
    final uid = _uid;
    if (uid == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Please sign in to continue.',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _functions.httpsCallable('sendAiSupportMessage').call({
      'chatId': chatId,
      'message': trimmed,
    });
  }

  Future<void> markThreadRead({String chatId = defaultChatId}) async {
    final uid = _uid;
    if (uid == null) return;

    final doc = _chatDoc(uid, chatId);
    await doc.set({
      'unreadCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final unreadMessages = await _messagesCol(uid, chatId)
        .where('sender', whereIn: ['ai', 'system'])
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final message in unreadMessages.docs) {
      batch.update(message.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
