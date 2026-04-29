import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: 0.4)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.activeBlueLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: hasUnread
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'P',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(
                        name.toLowerCase().contains('support')
                            ? Icons.support_agent_rounded
                            : Icons.notifications_active_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
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
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasUnread
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: hasUnread
                                ? (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                : (isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: GoogleFonts.poppins(
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
