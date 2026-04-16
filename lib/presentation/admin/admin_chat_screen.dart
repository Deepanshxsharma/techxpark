import 'package:techxpark/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/chat_model.dart';
import '../../services/support_repository.dart';

/// Admin chat view — can reply to a user and close the chat.
class AdminChatScreen extends StatefulWidget {
  final String chatId;
  const AdminChatScreen({super.key, required this.chatId});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _repo = SupportRepository.instance;

  static const Color _primary = Color(0xFF4D6FFF);
  static const Color _bg = Color(0xFFF5F7FB);
  static const Color _textDark = Color(0xFF1C1C1E);
  static const Color _error = Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();
    _repo.markReadByAdmin(widget.chatId);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    HapticFeedback.lightImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    await _repo.sendAdminMessage(widget.chatId, uid, text);
    _scrollToBottom();
  }

  void _confirmCloseChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Close Chat?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'This will mark the conversation as resolved. The user can start a new chat later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8E8E93)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repo.closeChat(widget.chatId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Close Chat',
                style: TextStyle(
                    color: _error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon:
              const Icon(Icons.arrow_back_rounded, color: _textDark, size: 22),
        ),
        title: const Text('Chat',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textDark,
                fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _confirmCloseChat,
            tooltip: 'Close chat',
            icon: const Icon(Icons.check_circle_outline_rounded,
                color: _primary, size: 24),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<List<MessageModel>>(
      stream: _repo.messagesStream(widget.chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        final messages = snapshot.data!;
        if (messages.isEmpty) {
          return const Center(
            child: Text('No messages',
                style: TextStyle(color: Color(0xFF8E8E93))),
          );
        }

        _scrollToBottom();

        return ListView.builder(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isAdmin = msg.senderType == 'admin';
            return _AdminBubble(message: msg, isAdmin: isAdmin);
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Reply as admin...',
                  hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendReply(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _msgCtrl,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _sendReply : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasText ? _primary : _primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
/*  ADMIN BUBBLE                                                             */
/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
class _AdminBubble extends StatelessWidget {
  final MessageModel message;
  final bool isAdmin;

  const _AdminBubble({required this.message, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final time = message.timestamp != null
        ? DateFormat.jm().format(message.timestamp!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAdmin) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE0E7FF),
              child: Text(
                'U',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAdmin
                    ? const Color(0xFF4D6FFF)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isAdmin ? 18 : 4),
                  bottomRight: Radius.circular(isAdmin ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(message.message,
                      style: TextStyle(
                        color: isAdmin
                            ? Colors.white
                            : const Color(0xFF1C1C1E),
                        fontSize: 15,
                        height: 1.4,
                      )),
                  const SizedBox(height: 4),
                  Text(time,
                      style: TextStyle(
                          color: isAdmin
                              ? Colors.white.withValues(alpha: 0.6)
                              : const Color(0xFFAAAAAA),
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
