import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/message_bubble.dart';

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
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }


  void _markAsRead() {
    final user = _auth.currentUser;
    if (user != null) {
      _chatService.markConversationRead(widget.conversationId);
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

    try {
      await _chatService.sendMessage(
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        receiverRole: widget.otherUserRole,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    }
    
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
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
            final message = MessageModel.fromMap(messages[index].id, data);
            final isMe = message.senderId == _auth.currentUser?.uid;
            
            bool showTimeSeparator = false;
            if (index == 0) {
              showTimeSeparator = true;
            } else {
              final prevData = messages[index - 1].data() as Map<String, dynamic>;
              if (message.timestamp != null && prevData['timestamp'] != null) {
                final current = message.timestamp!;
                final previous = (prevData['timestamp'] as Timestamp).toDate();
                if (current.difference(previous).inMinutes > 20) {
                  showTimeSeparator = true;
                }
              }
            }

            return Column(
              children: [
                if (showTimeSeparator && message.timestamp != null)
                  _buildTimeSeparator(message.timestamp!),
                MessageBubble(message: message, isMe: isMe),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
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

