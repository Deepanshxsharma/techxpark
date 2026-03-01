import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';

/// Centralised Firestore logic for the Support Chat feature.
/// No Firestore code should live in UI widgets — everything goes through here.
class SupportRepository {
  SupportRepository._();
  static final instance = SupportRepository._();

  final _firestore = FirebaseFirestore.instance;
  CollectionReference get _chatsCol => _firestore.collection('support_chats');

  /* ── Helpers ────────────────────────────────────────────────────────────── */
  User? get _user => FirebaseAuth.instance.currentUser;

  CollectionReference _messagesCol(String chatId) =>
      _chatsCol.doc(chatId).collection('messages');

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  CHAT OPERATIONS                                                       */
  /* ═══════════════════════════════════════════════════════════════════════ */

  /// Returns the user's existing open chat, or `null`.
  Future<ChatModel?> getExistingChat() async {
    if (_user == null) return null;
    final snap = await _chatsCol
        .where('userId', isEqualTo: _user!.uid)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ChatModel.fromMap(
        snap.docs.first.id, snap.docs.first.data() as Map<String, dynamic>);
  }

  /// Creates a new support chat and returns its model.
  Future<ChatModel> createChat() async {
    final user = _user!;
    // Fetch user profile from Firestore for name
    final userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final chat = ChatModel(
      id: '', // will be created by Firestore
      userId: user.uid,
      userName: userData['name'] ?? 'User',
      userEmail: user.email ?? '',
    );

    final ref = await _chatsCol.add(chat.toMap());
    return ChatModel.fromMap(ref.id, chat.toMap());
  }

  /// Real-time stream of messages for a chat, ordered oldest → newest.
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _messagesCol(chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                MessageModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Send a message from the current user.
  Future<void> sendMessage(String chatId, String text) async {
    final user = _user;
    if (user == null || text.trim().isEmpty) return;

    final msg = MessageModel(
      id: '',
      senderId: user.uid,
      senderType: 'user',
      message: text.trim(),
    );

    await _messagesCol(chatId).add(msg.toMap());

    // Update chat document
    await _chatsCol.doc(chatId).update({
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadByAdmin': FieldValue.increment(1),
    });
  }

  /// Send a message as admin.
  Future<void> sendAdminMessage(
      String chatId, String adminUid, String text) async {
    if (text.trim().isEmpty) return;

    final msg = MessageModel(
      id: '',
      senderId: adminUid,
      senderType: 'admin',
      message: text.trim(),
    );

    await _messagesCol(chatId).add(msg.toMap());

    await _chatsCol.doc(chatId).update({
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadByUser': FieldValue.increment(1),
    });
  }

  /// Mark all admin messages as read by the user.
  Future<void> markReadByUser(String chatId) async {
    await _chatsCol.doc(chatId).update({'unreadByUser': 0});

    final unread = await _messagesCol(chatId)
        .where('senderType', isEqualTo: 'admin')
        .where('read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      doc.reference.update({'read': true});
    }
  }

  /// Mark all user messages as read by admin.
  Future<void> markReadByAdmin(String chatId) async {
    await _chatsCol.doc(chatId).update({'unreadByAdmin': 0});

    final unread = await _messagesCol(chatId)
        .where('senderType', isEqualTo: 'user')
        .where('read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      doc.reference.update({'read': true});
    }
  }

  /// Close a chat (admin or user).
  Future<void> closeChat(String chatId) async {
    await _chatsCol.doc(chatId).update({'status': 'closed'});
  }

  /// Stream all chats for admin — ordered by latest message.
  Stream<List<ChatModel>> allChatsStream() {
    return _chatsCol
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ChatModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }
}
