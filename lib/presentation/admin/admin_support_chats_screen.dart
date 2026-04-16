import 'package:techxpark/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/chat_model.dart';
import '../../services/support_repository.dart';
import 'admin_chat_screen.dart';

/// Admin screen that lists all support chats.
class AdminSupportChatsScreen extends StatelessWidget {
  const AdminSupportChatsScreen({super.key});

  static const Color _primary = Color(0xFF4D6FFF);
  static const Color _bg = Color(0xFFF5F7FB);
  static const Color _textDark = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Support Chats',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: SupportRepository.instance.allChatsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _primary));
          }

          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No support chats yet',
                      style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatCard(
                  chat: chat,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AdminChatScreen(chatId: chat.id)),
                    );
                  });
            },
          );
        },
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;

  const _ChatCard({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final time = chat.lastMessageTime != null
        ? DateFormat.jm().format(chat.lastMessageTime!)
        : '';
    final isClosed = chat.status == 'closed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE0E7FF),
              child: Text(
                (chat.userName.isNotEmpty ? chat.userName[0] : 'U')
                    .toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 18),
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
                        child: Text(chat.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1C1C1E))),
                      ),
                      Text(time,
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: chat.unreadByAdmin > 0
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFF8E8E93),
                              fontSize: 13,
                              fontWeight: chat.unreadByAdmin > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (chat.unreadByAdmin > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4D6FFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${chat.unreadByAdmin}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      if (isClosed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Closed',
                              style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
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
