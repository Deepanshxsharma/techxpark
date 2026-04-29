import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/support_chat_models.dart';
import '../../services/ai_support_service.dart';
import 'package:techxpark/utils/navigation_utils.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../booking/my_bookings_screen.dart';
import '../map/dashboard_map_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/wallet_screen.dart';
import '../search/search_parking_screen.dart';
import 'chat_screen.dart';
import 'support_chat_screen.dart';

enum InboxTab { all, support, notifications }

class MessagesScreen extends StatefulWidget {
  final InboxTab initialTab;
  final bool showStandaloneNav;

  const MessagesScreen({
    super.key,
    this.initialTab = InboxTab.all,
    this.showStandaloneNav = false,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final AiSupportService _aiSupportService = AiSupportService.instance;

  late InboxTab _selectedTab;
  bool _showUnreadOnly = false;
  List<_InboxItem> _latestItems = const [];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  String? get _uid => _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final bottomInset = widget.showStandaloneNav ? 160.0 : 136.0;

    if (uid == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FC),
        body: Center(
          child: Text(
            'Please log in',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FC),
        extendBody: widget.showStandaloneNav,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: widget.showStandaloneNav ? 74 : 0),
          child: _SupportFab(onTap: _openSupportChat),
        ),
        bottomNavigationBar: widget.showStandaloneNav
            ? _StandaloneBottomNav(
                current: _StandaloneNavItem.messages,
                onSelected: _handleStandaloneNavTap,
              )
            : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF7F8FF),
                      Colors.white,
                      const Color(0xFFF4F7FC),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _InboxTopBar(
                    onMenuTap: _showInboxMenu,
                    onSearchTap: _openSearch,
                    onFilterTap: _showFilterSheet,
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db
                          .collection('users')
                          .doc(uid)
                          .collection('messages')
                          .snapshots(),
                      builder: (context, userMessagesSnapshot) {
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _db
                              .collection('notifications')
                              .where('userId', isEqualTo: uid)
                              .snapshots(),
                          builder: (context, notificationsSnapshot) {
                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: _db
                                  .collection('conversations')
                                  .where('participants', arrayContains: uid)
                                  .snapshots(),
                              builder: (context, conversationsSnapshot) {
                                return StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: _db
                                      .collection('users')
                                      .doc(uid)
                                      .collection('support_chats')
                                      .snapshots(),
                                  builder: (context, supportChatsSnapshot) {
                                    final userMessagesError =
                                        userMessagesSnapshot.hasError;
                                    final notificationsError =
                                        notificationsSnapshot.hasError;
                                    final conversationsError =
                                        conversationsSnapshot.hasError;
                                    final supportChatsError =
                                        supportChatsSnapshot.hasError;

                                    if (userMessagesError) {
                                      debugPrint(
                                        'Inbox user messages stream failed: '
                                        '${userMessagesSnapshot.error}',
                                      );
                                    }
                                    if (notificationsError) {
                                      debugPrint(
                                        'Inbox notifications stream failed: '
                                        '${notificationsSnapshot.error}',
                                      );
                                    }
                                    if (conversationsError) {
                                      debugPrint(
                                        'Inbox conversations stream failed: '
                                        '${conversationsSnapshot.error}',
                                      );
                                    }
                                    if (supportChatsError) {
                                      debugPrint(
                                        'Inbox support chats stream failed: '
                                        '${supportChatsSnapshot.error}',
                                      );
                                    }

                                    if (userMessagesError &&
                                        notificationsError &&
                                        conversationsError &&
                                        supportChatsError) {
                                      return _InboxErrorState(
                                        onRetry: () => setState(() {}),
                                      );
                                    }

                                    if (!userMessagesError &&
                                            userMessagesSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting ||
                                        !notificationsError &&
                                            notificationsSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting ||
                                        !conversationsError &&
                                            conversationsSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting ||
                                        !supportChatsError &&
                                            supportChatsSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                      return const _InboxLoadingState();
                                    }

                                    final items = _composeItems(
                                      uid: uid,
                                      userMessages: userMessagesError
                                          ? const []
                                          : userMessagesSnapshot.data?.docs ??
                                                const [],
                                      notifications: notificationsError
                                          ? const []
                                          : notificationsSnapshot.data?.docs ??
                                                const [],
                                      conversations: conversationsError
                                          ? const []
                                          : conversationsSnapshot.data?.docs ??
                                                const [],
                                      supportChats: supportChatsError
                                          ? const []
                                          : supportChatsSnapshot.data?.docs ??
                                                const [],
                                    );
                                    final visibleItems = _applyFilters(items);
                                    _latestItems = visibleItems;

                                    if (visibleItems.isEmpty) {
                                      return _InboxEmptyState(
                                        currentTab: _selectedTab,
                                        isUnreadOnly: _showUnreadOnly,
                                      );
                                    }

                                    return CustomScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      slivers: [
                                        SliverPadding(
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            12,
                                            20,
                                            0,
                                          ),
                                          sliver: SliverToBoxAdapter(
                                            child: Column(
                                              children: [
                                                _InboxTabs(
                                                  selectedTab: _selectedTab,
                                                  onChanged: (tab) {
                                                    HapticFeedback.selectionClick();
                                                    setState(
                                                      () => _selectedTab = tab,
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 18),
                                                const _FeaturedSection(),
                                                const SizedBox(height: 22),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SliverPadding(
                                          padding: EdgeInsets.fromLTRB(
                                            20,
                                            0,
                                            20,
                                            bottomInset,
                                          ),
                                          sliver: SliverList.separated(
                                            itemCount: visibleItems.length,
                                            separatorBuilder:
                                                (context, index) =>
                                                    const SizedBox(height: 12),
                                            itemBuilder: (context, index) {
                                              final item = visibleItems[index];
                                              return TweenAnimationBuilder<
                                                double
                                              >(
                                                key: ValueKey(
                                                  '${item.source.name}-${item.id}',
                                                ),
                                                duration: Duration(
                                                  milliseconds:
                                                      240 + (index * 45),
                                                ),
                                                curve: Curves.easeOutCubic,
                                                tween: Tween<double>(
                                                  begin: 0,
                                                  end: 1,
                                                ),
                                                builder:
                                                    (context, value, child) {
                                                      return Opacity(
                                                        opacity: value,
                                                        child:
                                                            Transform.translate(
                                                              offset: Offset(
                                                                0,
                                                                18 *
                                                                    (1 - value),
                                                              ),
                                                              child: child,
                                                            ),
                                                      );
                                                    },
                                                child: _InboxCard(
                                                  item: item,
                                                  onTap: () =>
                                                      _handleItemTap(item),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_InboxItem> _composeItems({
    required String uid,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> userMessages,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> notifications,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> conversations,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> supportChats,
  }) {
    final items = <_InboxItem>[
      ...userMessages.map(_InboxItem.fromUserMessage),
      ...notifications.map(_InboxItem.fromNotification),
      ...supportChats.map(_InboxItem.fromSupportChat),
      ...conversations
          .map((doc) => _InboxItem.fromConversation(uid, doc))
          .where((item) => item != null)
          .cast<_InboxItem>(),
    ];

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    debugPrint('Messages count: ${items.length}');
    return items;
  }

  List<_InboxItem> _applyFilters(List<_InboxItem> items) {
    return items.where((item) {
      if (_showUnreadOnly && item.isRead) {
        return false;
      }

      switch (_selectedTab) {
        case InboxTab.all:
          return true;
        case InboxTab.support:
          return item.isSupport;
        case InboxTab.notifications:
          return item.isNotificationLike;
      }
    }).toList();
  }

  Future<void> _handleItemTap(_InboxItem item) async {
    await _markAsRead(item);
    if (!mounted) return;

    switch (item.type) {
      case 'support':
        if (item.source == _InboxSource.aiSupportChat) {
          await _openSupportChat();
          return;
        }
        await _openChatForItem(item);
        return;
      case 'booking':
      case 'reminder':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
        );
        return;
      case 'payment':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
        return;
      default:
        if (item.conversationId != null || item.otherUserId != null) {
          await _openChatForItem(item);
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
        );
    }
  }

  Future<void> _markAsRead(_InboxItem item) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      switch (item.source) {
        case _InboxSource.userMessage:
          await _db
              .collection('users')
              .doc(uid)
              .collection('messages')
              .doc(item.id)
              .set({'isRead': true}, SetOptions(merge: true));
          break;
        case _InboxSource.notification:
          await _db.collection('notifications').doc(item.id).update({
            'read': true,
          });
          break;
        case _InboxSource.aiSupportChat:
          await _aiSupportService.markThreadRead(chatId: item.id);
          break;
        case _InboxSource.supportConversation:
          await _chatService.markConversationRead(
            item.conversationId ?? item.id,
          );
          break;
      }
    } catch (error) {
      debugPrint('Failed to mark inbox item as read: $error');
    }
  }

  Future<void> _markAllVisibleAsRead() async {
    final items = List<_InboxItem>.from(_latestItems);
    for (final item in items.where((entry) => !entry.isRead)) {
      await _markAsRead(item);
    }
  }

  Future<void> _openSupportChat() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SupportChatScreen()));
  }

  Future<void> _openChatForItem(_InboxItem item) async {
    if (item.otherUserId == null || item.otherUserId!.isEmpty) {
      await _openSupportChat();
      return;
    }

    final name = item.otherUserName?.trim().isNotEmpty == true
        ? item.otherUserName!.trim()
        : item.title;
    final role = item.otherUserRole?.trim().isNotEmpty == true
        ? item.otherUserRole!.trim()
        : 'admin';
    final uid = _uid;
    if (uid == null || !mounted) return;

    final conversationId =
        item.conversationId ??
        _chatService.generateConversationId(uid, item.otherUserId!);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherUserId: item.otherUserId!,
          otherUserName: name,
          otherUserRole: role,
        ),
      ),
    );
  }

  void _openSearch() async {
    HapticFeedback.selectionClick();
    final selected = await showSearch<_InboxItem?>(
      context: context,
      delegate: _InboxSearchDelegate(items: _latestItems),
    );
    if (selected != null) {
      await _handleItemTap(selected);
    }
  }

  void _showInboxMenu() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E7F4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _SheetActionTile(
                  icon: Icons.mark_email_read_rounded,
                  title: 'Mark visible items as read',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _markAllVisibleAsRead();
                  },
                ),
                _SheetActionTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Contact support',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openSupportChat();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1E7F4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Inbox Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: _showUnreadOnly,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(
                        alpha: 0.32,
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Unread only',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      subtitle: Text(
                        'Show only items that still need attention',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() => _showUnreadOnly = value);
                        setState(() => _showUnreadOnly = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _markAllVisibleAsRead();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Mark Visible Items Read',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleStandaloneNavTap(_StandaloneNavItem item) async {
    if (!mounted) return;
    if (item == _StandaloneNavItem.messages) return;

    HapticFeedback.selectionClick();
    Widget destination;
    switch (item) {
      case _StandaloneNavItem.map:
        destination = const DashboardMapScreen();
        break;
      case _StandaloneNavItem.park:
        destination = const SearchParkingScreen();
        break;
      case _StandaloneNavItem.messages:
        return;
      case _StandaloneNavItem.wallet:
        destination = const WalletScreen();
        break;
      case _StandaloneNavItem.profile:
        destination = const ProfileScreen();
        break;
    }

  await safePushReplacement(context, destination);
  }
}

enum _InboxSource {
  userMessage,
  notification,
  aiSupportChat,
  supportConversation,
}

class _InboxItem {
  final String id;
  final _InboxSource source;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String? conversationId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserRole;

  const _InboxItem({
    required this.id,
    required this.source,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    this.conversationId,
    this.otherUserId,
    this.otherUserName,
    this.otherUserRole,
  });

  bool get isSupport =>
      type == 'support' ||
      source == _InboxSource.supportConversation ||
      source == _InboxSource.aiSupportChat;

  bool get isNotificationLike => !isSupport;

  factory _InboxItem.fromUserMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _InboxItem(
      id: doc.id,
      source: _InboxSource.userMessage,
      title: _readString(data['title'], fallback: 'New message'),
      message: _readString(
        data['message'] ?? data['body'],
        fallback: 'Tap to view details.',
      ),
      type: _normalizeType(data['type']),
      timestamp: _readTimestamp(
        data['timestamp'] ?? data['createdAt'] ?? data['updatedAt'],
      ),
      isRead: data['isRead'] == true,
      conversationId: data['conversationId']?.toString(),
      otherUserId: data['otherUserId']?.toString(),
      otherUserName: data['otherUserName']?.toString(),
      otherUserRole: data['otherUserRole']?.toString(),
    );
  }

  factory _InboxItem.fromNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _InboxItem(
      id: doc.id,
      source: _InboxSource.notification,
      title: _readString(data['title'], fallback: 'Notification'),
      message: _readString(
        data['message'] ?? data['body'],
        fallback: 'Tap to view details.',
      ),
      type: _normalizeType(data['type']),
      timestamp: _readTimestamp(data['createdAt'] ?? data['timestamp']),
      isRead: data['read'] == true || data['isRead'] == true,
      conversationId: data['conversationId']?.toString(),
      otherUserId: data['otherUserId']?.toString(),
      otherUserName: data['otherUserName']?.toString(),
      otherUserRole: data['otherUserRole']?.toString(),
    );
  }

  factory _InboxItem.fromSupportChat(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final thread = SupportChatThread.fromMap(doc.id, doc.data());
    return _InboxItem(
      id: thread.id,
      source: _InboxSource.aiSupportChat,
      title: thread.title,
      message: thread.lastMessage.isEmpty
          ? 'Ask about bookings, slots, payment, or navigation.'
          : thread.lastMessage,
      type: 'support',
      timestamp:
          thread.lastMessageTime ??
          thread.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: thread.unreadCount == 0,
    );
  }

  static _InboxItem? fromConversation(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final participants = List<String>.from(data['participants'] ?? const []);
    final unreadMap = Map<String, dynamic>.from(
      data['unreadCount'] ?? const {},
    );
    final names = Map<String, dynamic>.from(
      data['participantNames'] ?? const {},
    );
    final roles = Map<String, dynamic>.from(
      data['participantRoles'] ?? const {},
    );

    final otherId = participants
        .where((id) => id != uid)
        .cast<String?>()
        .firstWhere((id) => id != null && id.isNotEmpty, orElse: () => null);
    if (otherId == null) return null;

    final role = roles[otherId]?.toString() ?? 'admin';
    final isSupportRole =
        role == 'admin' || role == 'owner' || role == 'support';
    if (!isSupportRole) return null;

    final name = _readString(
      names[otherId],
      fallback: role == 'owner' ? 'Parking Support' : 'TechXPark Support',
    );

    return _InboxItem(
      id: doc.id,
      source: _InboxSource.supportConversation,
      title: name,
      message: _readString(
        data['lastMessage'],
        fallback: 'Support replied to your conversation.',
      ),
      type: 'support',
      timestamp: _readTimestamp(data['lastMessageTime'] ?? data['createdAt']),
      isRead: ((unreadMap[uid] as num?)?.toInt() ?? 0) == 0,
      conversationId: doc.id,
      otherUserId: otherId,
      otherUserName: name,
      otherUserRole: role,
    );
  }

  static String _readString(dynamic value, {required String fallback}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  static String _normalizeType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'booking':
      case 'support':
      case 'reminder':
      case 'payment':
        return raw;
      case 'general':
      case 'broadcast':
      case 'alert':
        return 'reminder';
      default:
        return raw.isEmpty ? 'reminder' : raw;
    }
  }

  static DateTime _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _InboxTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;

  const _InboxTopBar({
    required this.onMenuTap,
    required this.onSearchTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _BlurIconButton(icon: Icons.menu_rounded, onTap: onMenuTap),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Messages',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                _BlurIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
                const SizedBox(width: 10),
                _BlurIconButton(icon: Icons.tune_rounded, onTap: onFilterTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxTabs extends StatelessWidget {
  final InboxTab selectedTab;
  final ValueChanged<InboxTab> onChanged;

  const _InboxTabs({required this.selectedTab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _TabChip(
            label: 'All',
            isSelected: selectedTab == InboxTab.all,
            onTap: () => onChanged(InboxTab.all),
          ),
          _TabChip(
            label: 'Support',
            isSelected: selectedTab == InboxTab.support,
            onTap: () => onChanged(InboxTab.support),
          ),
          _TabChip(
            label: 'Notifications',
            isSelected: selectedTab == InboxTab.notifications,
            onTap: () => onChanged(InboxTab.notifications),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 144,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4345F5),
                    AppColors.primary,
                    Color(0xFF1F23B9),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    top: -10,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 22,
                    top: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Premium',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TechXPark Premium',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Unlock Priority Parking Slots',
                        maxLines: 2,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8ECF7)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F0FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Daily Rewards',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Claim perks',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
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
}

class _InboxCard extends StatelessWidget {
  final _InboxItem item;
  final VoidCallback onTap;

  const _InboxCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(item.type);
    final icon = _iconForType(item.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFFE8ECF5)
                  : accent.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: item.isRead ? 0.04 : 0.09),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatRelativeTime(item.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: item.isRead ? 0 : 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportFab extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.support_agent_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Contact Support',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxLoadingState extends StatelessWidget {
  const _InboxLoadingState();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE8EDF7),
                  highlightColor: Colors.white,
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE8EDF7),
                  highlightColor: Colors.white,
                  child: Container(
                    height: 144,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
          sliver: SliverList.separated(
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return Shimmer.fromColors(
                baseColor: const Color(0xFFE8EDF7),
                highlightColor: Colors.white,
                child: Container(
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  final InboxTab currentTab;
  final bool isUnreadOnly;

  const _InboxEmptyState({
    required this.currentTab,
    required this.isUnreadOnly,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'No messages yet';
    String subtitle = 'Your latest updates will show up here.';

    if (currentTab == InboxTab.support) {
      title = 'No support messages yet';
      subtitle = 'Start a support conversation when you need help.';
    } else if (currentTab == InboxTab.notifications) {
      title = 'No notifications yet';
      subtitle = 'System alerts and reminders will appear here.';
    } else if (isUnreadOnly) {
      title = 'All caught up';
      subtitle = 'There are no unread items in your inbox.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_chat_unread_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _InboxErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Failed to load messages',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BlurIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EBF6)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFF6F8FD),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StandaloneNavItem { map, park, messages, wallet, profile }

class _StandaloneBottomNav extends StatelessWidget {
  final _StandaloneNavItem current;
  final ValueChanged<_StandaloneNavItem> onSelected;

  const _StandaloneBottomNav({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StandaloneNavButton(
                    label: 'Map',
                    icon: Icons.map_outlined,
                    selectedIcon: Icons.map_rounded,
                    selected: current == _StandaloneNavItem.map,
                    onTap: () => onSelected(_StandaloneNavItem.map),
                  ),
                  _StandaloneNavButton(
                    label: 'Park',
                    icon: Icons.local_parking_outlined,
                    selectedIcon: Icons.local_parking_rounded,
                    selected: current == _StandaloneNavItem.park,
                    onTap: () => onSelected(_StandaloneNavItem.park),
                  ),
                  _StandaloneNavButton(
                    label: 'Messages',
                    icon: Icons.chat_bubble_outline_rounded,
                    selectedIcon: Icons.chat_bubble_rounded,
                    selected: current == _StandaloneNavItem.messages,
                    onTap: () => onSelected(_StandaloneNavItem.messages),
                  ),
                  _StandaloneNavButton(
                    label: 'Wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    selectedIcon: Icons.account_balance_wallet_rounded,
                    selected: current == _StandaloneNavItem.wallet,
                    onTap: () => onSelected(_StandaloneNavItem.wallet),
                  ),
                  _StandaloneNavButton(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    selected: current == _StandaloneNavItem.profile,
                    onTap: () => onSelected(_StandaloneNavItem.profile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandaloneNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _StandaloneNavButton({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFF98A2B3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxSearchDelegate extends SearchDelegate<_InboxItem?> {
  final List<_InboxItem> items;

  _InboxSearchDelegate({required this.items});

  @override
  String get searchFieldLabel => 'Search messages';

  @override
  TextStyle? get searchFieldStyle => GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildBody(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? items
        : items.where((item) {
            return item.title.toLowerCase().contains(normalized) ||
                item.message.toLowerCase().contains(normalized);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No matching messages',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _InboxCard(item: item, onTap: () => close(context, item));
      },
    );
  }
}

Color _accentForType(String type) {
  switch (type) {
    case 'booking':
      return AppColors.primary;
    case 'support':
      return const Color(0xFF0EA5A4);
    case 'payment':
      return const Color(0xFF7C3AED);
    case 'reminder':
    default:
      return const Color(0xFFF59E0B);
  }
}

IconData _iconForType(String type) {
  switch (type) {
    case 'booking':
      return Icons.local_parking_rounded;
    case 'support':
      return Icons.support_agent_rounded;
    case 'payment':
      return Icons.account_balance_wallet_rounded;
    case 'reminder':
    default:
      return Icons.notifications_active_rounded;
  }
}

String _formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays == 1) {
    return 'Yesterday';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  return '${dateTime.day}/${dateTime.month}/${dateTime.year % 100}';
}
