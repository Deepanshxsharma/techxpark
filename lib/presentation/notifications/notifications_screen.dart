import 'package:techxpark/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late Animation<Color?> _bgColor1;
  late Animation<Color?> _bgColor2;

  static const Color _dark = Color(0xFF0F172A);
  static const Color _slate = Color(0xFF64748B);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgColor1 = ColorTween(
      begin: const Color(0xFFF0F4FF),
      end: const Color(0xFFF8FAFC),
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOutSine));
    _bgColor2 = ColorTween(
      begin: const Color(0xFFF8FAFC),
      end: const Color(0xFFE8F0FE),
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _notifCol => _uid != null
      ? FirebaseFirestore.instance.collection('notifications')
      : null;

  Query? get _userNotifQuery => _uid != null
      ? _notifCol!.where('userId', isEqualTo: _uid)
      : null;

  // ── Mark single notification as read ──────────────────────────────────────
  Future<void> _markAsRead(String docId) async {
    await _notifCol?.doc(docId).update({'read': true});
  }

  // ── Mark ALL as read ──────────────────────────────────────────────────────
  Future<void> _markAllAsRead() async {
    final snap = await _userNotifQuery?.where('read', isEqualTo: false).get();
    if (snap == null || snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Delete single notification ────────────────────────────────────────────
  Future<void> _deleteNotification(String id) async {
    HapticFeedback.mediumImpact();
    await _notifCol?.doc(id).delete();
  }

  // ── Clear all notifications ───────────────────────────────────────────────
  Future<void> _clearAll() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear All?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will permanently delete your entire notification history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final snap = await _userNotifQuery?.get();
    if (snap == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Animated Gradient Background ──────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _bgColor1.value ?? _surface,
                        _bgColor2.value ?? _surface,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Column(
              children: [
                SizedBox(height: topPad),
                _buildAppBar(),
                Expanded(
                  child: _uid == null
                      ? _buildEmpty('Sign in to see notifications')
                      : StreamBuilder<QuerySnapshot>(
                          stream: _userNotifQuery!.snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildShimmer();
                            }
                            if (snapshot.hasError) {
                              return _buildEmpty('Error loading notifications');
                            }
                            final docs = snapshot.data?.docs.toList() ?? [];
                            docs.sort((a, b) {
                              final dataA = a.data() as Map<String, dynamic>;
                              final dataB = b.data() as Map<String, dynamic>;
                              final tsA = dataA['createdAt'] as Timestamp?;
                              final tsB = dataB['createdAt'] as Timestamp?;
                              if (tsA != null && tsB != null) {
                                return tsB.compareTo(tsA);
                              }
                              return 0;
                            });
                            if (docs.isEmpty) {
                              return _buildEmpty('No notifications yet');
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              physics: const BouncingScrollPhysics(),
                              itemCount:
                                  docs.length + 1, // +1 for "Mark all" button
                              itemBuilder: (_, i) {
                                // First item: "Mark all as read" button
                                if (i == 0) {
                                  return _buildMarkAllRow(docs);
                                }
                                final idx = i - 1;
                                final doc = docs[idx];
                                final data = doc.data() as Map<String, dynamic>;
                                return TweenAnimationBuilder<double>(
                                  key: ValueKey(doc.id),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds:
                                        350 + (idx * 50).clamp(0, 400),
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, child) => Opacity(
                                    opacity: val,
                                    child: Transform.translate(
                                      offset: Offset(0, 20 * (1 - val)),
                                      child: child,
                                    ),
                                  ),
                                  child: _NotifCard(
                                    id: doc.id,
                                    data: data,
                                    onTap: () => _markAsRead(doc.id),
                                    onDelete: () => _deleteNotification(doc.id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Mark All Row ──────────────────────────────────────────────────────────
  Widget _buildMarkAllRow(List<QueryDocumentSnapshot> docs) {
    final unread = docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      return m['read'] == false;
    }).length;
    if (unread == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _markAllAsRead,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Mark all as read ($unread)',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          _PressBtn(
            onPressed: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _dark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _dark,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (_uid != null)
            _PressBtn(
              onPressed: _clearAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 52,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your notification history will appear here.',
            style: TextStyle(color: _slate, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Shimmer ───────────────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🃏 NOTIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _NotifCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NotifCard({
    required this.id,
    required this.data,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard> {
  bool _pressed = false;

  Color get _accentColor {
    switch (widget.data['type']) {
      case 'booking':
        return AppColors.primary;
      case 'payment':
        return const Color(0xFF10B981);
      case 'expiry':
        return const Color(0xFFF59E0B);
      case 'slot':
        return const Color(0xFF8B5CF6);
      case 'offer':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get _icon {
    switch (widget.data['type']) {
      case 'booking':
        return Icons.local_parking_rounded;
      case 'payment':
        return Icons.credit_card_rounded;
      case 'expiry':
        return Icons.timer_rounded;
      case 'slot':
        return Icons.directions_car_rounded;
      case 'offer':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = widget.data['read'] == false;

    return Dismissible(
      key: ValueKey(widget.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          if (isUnread) {
            HapticFeedback.lightImpact();
            widget.onTap(); // Mark as read
          }
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isUnread ? Colors.white : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUnread
                    ? _accentColor.withOpacity(0.25)
                    : const Color(0xFFE2E8F0),
                width: isUnread ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isUnread
                      ? _accentColor.withOpacity(0.08)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon bubble
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(isUnread ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _icon,
                      color: _accentColor.withOpacity(isUnread ? 1.0 : 0.6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.data['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: isUnread
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: 14,
                                  color: const Color(
                                    0xFF0F172A,
                                  ).withOpacity(isUnread ? 1.0 : 0.6),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: _accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.data['body'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(
                              0xFF64748B,
                            ).withOpacity(isUnread ? 1.0 : 0.7),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _timeAgo(widget.data['createdAt']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// ⚡ Pressable Button
// ─────────────────────────────────────────────────────────────────────────────
class _PressBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  const _PressBtn({required this.child, required this.onPressed});

  @override
  State<_PressBtn> createState() => _PressBtnState();
}

class _PressBtnState extends State<_PressBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎬 SMOOTH SLIDE-UP PAGE ROUTE (for the dashboard bell button)
// ─────────────────────────────────────────────────────────────────────────────
class NotificationsPageRoute extends PageRouteBuilder {
  NotificationsPageRoute()
    : super(
        pageBuilder: (_, __, ___) => const NotificationsScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, __, child) {
          final slideUp =
              Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ),
          );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slideUp, child: child),
          );
        },
      );
}
