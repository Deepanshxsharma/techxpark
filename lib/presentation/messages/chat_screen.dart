import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:techxpark/services/message_service.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _messageService = MessageService();

  String _senderName = 'User';
  String _senderRole = 'customer';

  @override
  void initState() {
    super.initState();
    _loadSenderInfo();
    _markAsRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSenderInfo() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _senderName = userDoc.data()?['name'] ?? _auth.currentUser?.displayName ?? 'User';
          _senderRole = userDoc.data()?['role'] ?? 'customer';
        });
      }
    } catch (e) {
      debugPrint('Failed to load sender info: $e');
    }
  }

  void _markAsRead() {
    final user = _auth.currentUser;
    if (user != null) {
      _messageService.markConversationRead(widget.conversationId, user.uid);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _msgCtrl.clear();
    HapticFeedback.lightImpact();

    await _messageService.sendMessage(
      senderId: user.uid,
      senderName: _senderName,
      senderRole: _senderRole,
      receiverId: widget.otherUserId,
      receiverName: widget.otherUserName,
      receiverRole: widget.otherUserRole,
      text: text,
    );
    
    _scrollToBottom();
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return '🛡️ Support';
      case 'owner':
        return '🅿️ Parking Manager';
      case 'customer':
        return '👤 Customer';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'S',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: AppTextStyles.body1SemiBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getRoleLabel(widget.otherUserRole),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
            _markAsRead();
        });

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👋', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Say hi to ${widget.otherUserName}!',
                  style: AppTextStyles.body2.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final isMe = data['senderId'] == _auth.currentUser?.uid;
            final prevData = index > 0 ? messages[index - 1].data() as Map<String, dynamic> : null;
            
            bool showTimeSeparator = false;
            if (index == 0) {
              showTimeSeparator = true;
            } else if (data['timestamp'] != null && prevData?['timestamp'] != null) {
              final current = (data['timestamp'] as Timestamp).toDate();
              final previous = (prevData!['timestamp'] as Timestamp).toDate();
              if (current.difference(previous).inMinutes > 20) {
                showTimeSeparator = true;
              }
            }

            return Column(
              children: [
                if (showTimeSeparator && data['timestamp'] != null)
                  _buildTimeSeparator((data['timestamp'] as Timestamp).toDate()),
                _ChatBubble(
                  text: data['text'] ?? '',
                  isMe: isMe,
                  timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
                  isRead: data['read'] ?? false,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimeSeparator(DateTime dateTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        DateFormat('MMM d, h:mm a').format(dateTime),
        style: AppTextStyles.captionBold.copyWith(color: AppColors.textTertiaryLight),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? timestamp;
  final bool isRead;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    this.timestamp,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: AppTextStyles.body2.copyWith(color: isMe ? Colors.white : AppColors.textPrimaryLight),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timestamp != null)
                  Text(
                    DateFormat('h:mm a').format(timestamp!),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textTertiaryLight,
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
