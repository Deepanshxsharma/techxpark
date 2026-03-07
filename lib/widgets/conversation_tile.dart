import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
    final otherId = conversation.participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    
    final name = conversation.participantNames[otherId] ?? 'Support';
    final unreadCount = (conversation.unreadCount[currentUserId] as num?)?.toInt() ?? 0;

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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Middle Column (Name + Last Message)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: AppTextStyles.caption.copyWith(
                            color: unreadCount > 0 
                                ? AppColors.primary 
                                : AppColors.textTertiaryLight,
                            fontWeight: unreadCount > 0 
                                ? FontWeight.w600 
                                : FontWeight.w400,
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
                          style: AppTextStyles.body2.copyWith(
                            color: unreadCount > 0
                                ? AppColors.textPrimaryLight
                                : AppColors.textSecondaryLight,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
