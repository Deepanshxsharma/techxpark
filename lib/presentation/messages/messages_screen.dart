import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/message_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _messageService = MessageService();

  String _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return '🛡️';
      case 'owner':
        return '🅿️';
      default:
        return '👤';
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Support';
      case 'owner':
        return 'Parking Manager';
      default:
        return 'Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: AppTextStyles.h2),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('conversations')
            .where('participants', arrayContains: user.uid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 64, color: AppColors.textTertiaryLight),
                  const SizedBox(height: 16),
                  const Text('No messages yet',
                      style: AppTextStyles.h3),
                  const SizedBox(height: 6),
                  Text('Your conversations will appear here',
                      style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showNewChatSheet(context),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Start a Conversation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final convId = docs[index].id;

              final participants = List<String>.from(data['participants'] ?? []);
              final otherId = participants.firstWhere((p) => p != user.uid,
                  orElse: () => '');
              final participantNames =
                  data['participantNames'] as Map<String, dynamic>? ?? {};
              final participantRoles =
                  data['participantRoles'] as Map<String, dynamic>? ?? {};
              final name = participantNames[otherId] ?? 'Support';
              final role = (participantRoles[otherId] ?? 'admin') as String;

              // Unread count
              final unreadMap =
                  data['unreadCount'] as Map<String, dynamic>? ?? {};
              final unread = (unreadMap[user.uid] as num?)?.toInt() ?? 0;

              final lastMsg = data['lastMessage'] as String? ?? '';
              final timestamp =
                  (data['lastMessageTime'] as Timestamp?)?.toDate();

              String timeStr = '';
              if (timestamp != null) {
                final now = DateTime.now();
                if (now.difference(timestamp).inDays == 0 && now.day == timestamp.day) {
                  timeStr = DateFormat.jm().format(timestamp);
                } else {
                  timeStr = DateFormat.MMMd().format(timestamp);
                }
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTextStyles.body1SemiBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: role == 'admin'
                                  ? Colors.blue.withOpacity(0.1)
                                  : role == 'owner'
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_getRoleIcon(role)} ${_getRoleLabel(role)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: role == 'admin'
                                    ? Colors.blue
                                    : role == 'owner'
                                        ? Colors.orange
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: AppTextStyles.caption.copyWith(
                          color: unread > 0 ? AppColors.primary : AppColors.textTertiaryLight,
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lastMsg,
                        style: AppTextStyles.body2.copyWith(
                          color: unread > 0 ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: convId,
                        otherUserId: otherId,
                        otherUserName: name,
                        otherUserRole: role,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─── New Chat Bottom Sheet ─────────────────────────────────────
  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(messageService: _messageService),
    );
  }
}

// ─── New Chat Contact Sheet ──────────────────────────────────────
class _NewChatSheet extends StatefulWidget {
  final MessageService messageService;

  const _NewChatSheet({required this.messageService});

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
          final lotDoc = await _db.collection('parking_locations').doc(parkingId).get();
          final ownerId = lotDoc.data()?['assignedOwnerId'] as String?;
          if (ownerId != null && ownerId != uid && !ownerIds.contains(ownerId)) {
            ownerIds.add(ownerId);
            final ownerDoc = await _db.collection('users').doc(ownerId).get();
            if (ownerDoc.exists) {
              contacts.add({
                'id': ownerId,
                'name': ownerDoc.data()!['name'] ?? 'Parking Manager',
                'role': 'owner',
                'subtitle': '🅿️ ${lotDoc.data()?['name'] ?? 'Parking Manager'}',
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'New Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D1117),
                  ),
                ),
              ],
            ),
          ),

          // Contacts list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _contacts.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts available',
                          style: AppTextStyles.body2.copyWith(color: AppColors.textTertiaryLight),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, Color(0xFF4C63E8)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  (contact['name'] as String).isNotEmpty
                                      ? (contact['name'] as String)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              contact['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D1117),
                              ),
                            ),
                            subtitle: Text(
                              contact['subtitle'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFF5C6B8A),
                                fontSize: 12,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              final currentUser = _auth.currentUser;
                              if (currentUser == null) return;
                              final convId = widget.messageService.generateConversationId(
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
