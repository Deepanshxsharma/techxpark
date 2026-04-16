import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation_model.dart';
import '../theme/app_colors.dart';

/// Conversation tile — Stitch design.
/// Gradient avatar, bold name, time badge, unread pill with gradient,
/// and consistent dark mode support.
class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherId = conversation.participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );

    final name = conversation.participantNames[otherId] ?? 'Support';
    final unreadCount =
        (conversation.unreadCount[currentUserId] as num?)?.toInt() ?? 0;
    final hasUnread = unreadCount > 0;

    String timeStr = '';
    if (conversation.lastMessageTime != null) {
      final now = DateTime.now();
      final dt = conversation.lastMessageTime!;
      if (now.difference(dt).inDays == 0 && now.day == dt.day) {
        timeStr = DateFormat.jm().format(dt);
      } else {
        timeStr = DateFormat.MMMd().format(dt);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: hasUnread
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.primary.withValues(alpha: 0.03))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // ── Avatar ─────────────────────────────────────
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Info ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread
                                ? AppColors.primary
                                : (isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Message + badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                            color: hasUnread
                                ? (isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155))
                                : (isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99
                                ? '99+'
                                : unreadCount.toString(),
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
