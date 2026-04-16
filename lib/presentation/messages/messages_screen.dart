import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/conversation_tile.dart';
import 'chat_screen.dart';

/// Messages Screen — Stitch design.
/// Premium conversation list with gradient avatar, unread badges,
/// frosted new-chat bottom sheet, and polished empty state.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: const Center(child: Text('Please log in')),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  (isDark ? AppColors.bgDark : const Color(0xFFF9F9FB))
                      .withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Messages',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _showNewChatSheet(context, isDark),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),

            // ── Conversation List ──────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('conversations')
                    .where('participants', arrayContains: user.uid)
                    .orderBy('lastMessageTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: _buildErrorState(isDark),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return SliverFillRemaining(
                        child: _buildEmptyState(isDark, context));
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final conversation =
                            ConversationModel.fromMap(doc.id, data);

                        final otherId = conversation.participants.firstWhere(
                            (p) => p != user.uid,
                            orElse: () => '');
                        final name = conversation
                                .participantNames[otherId] ??
                            'Support';
                        final role =
                            (conversation.participantRoles[otherId] ??
                                'admin') as String;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: ConversationTile(
                            conversation: conversation,
                            currentUserId: user.uid,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: conversation.id,
                                    otherUserId: otherId,
                                    otherUserName: name,
                                    otherUserRole: role,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark
                  : AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 52,
              color: isDark
                  ? Colors.white38
                  : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No messages yet',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your conversations will appear here',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => _showNewChatSheet(context, isDark),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Start a Conversation',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load messages',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NEW CHAT BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════
  void _showNewChatSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _NewChatSheet(chatService: _chatService, isDark: isDark),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NEW CHAT CONTACT SHEET — Stitch design
// ═══════════════════════════════════════════════════════════════
class _NewChatSheet extends StatefulWidget {
  final ChatService chatService;
  final bool isDark;

  const _NewChatSheet({required this.chatService, required this.isDark});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final List<Map<String, dynamic>> contacts = [];

    try {
      // 1. Get admin (Support)
      final adminSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      for (final doc in adminSnap.docs) {
        if (doc.id != uid) {
          contacts.add({
            'id': doc.id,
            'name': doc.data()['name'] ?? 'TechXPark Support',
            'role': 'admin',
            'subtitle': '🛡️ Platform Support',
            'icon': Icons.support_agent,
          });
        }
      }

      // 2. Get owner(s) of lots user has booked
      final bookingsSnap = await _db
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .get();

      final Set<String> ownerIds = {};
      for (final booking in bookingsSnap.docs) {
        final parkingId = booking.data()['parkingId'] as String?;
        if (parkingId != null) {
          final lotDoc =
              await _db.collection('parking_locations').doc(parkingId).get();
          final ownerId = lotDoc.data()?['assignedOwnerId'] as String?;
          if (ownerId != null &&
              ownerId != uid &&
              !ownerIds.contains(ownerId)) {
            ownerIds.add(ownerId);
            final ownerDoc =
                await _db.collection('users').doc(ownerId).get();
            if (ownerDoc.exists) {
              contacts.add({
                'id': ownerId,
                'name':
                    ownerDoc.data()!['name'] ?? 'Parking Manager',
                'role': 'owner',
                'subtitle':
                    '🅿️ ${lotDoc.data()?['name'] ?? 'Parking Manager'}',
                'icon': Icons.local_parking,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load contacts: $e');
    }

    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Text(
                  'New Message',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Contacts list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _contacts.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts available',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return _buildContactTile(
                              contact, isDark, context);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
      Map<String, dynamic> contact, bool isDark, BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;
        final convId = widget.chatService.generateConversationId(
          currentUser.uid,
          contact['id'],
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              otherUserId: contact['id'],
              otherUserName: contact['name'],
              otherUserRole: contact['role'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  (contact['name'] as String).isNotEmpty
                      ? (contact['name'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact['subtitle'] ?? '',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: isDark
                          ? Colors.white54
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right,
                color: isDark
                    ? Colors.white24
                    : const Color(0xFFC5C5D8),
                size: 22),
          ],
        ),
      ),
    );
  }
}
