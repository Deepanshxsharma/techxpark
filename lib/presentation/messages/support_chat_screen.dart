import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/support_chat_models.dart';
import '../../services/ai_support_service.dart';
import '../../services/navigation_service.dart';
import '../../theme/app_colors.dart';
import '../booking/my_bookings_screen.dart';
import '../booking/parking_timer_screen.dart';
import '../profile/wallet_screen.dart';

class SupportChatScreen extends StatefulWidget {
  final String chatId;

  const SupportChatScreen({
    super.key,
    this.chatId = AiSupportService.defaultChatId,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final AiSupportService _service = AiSupportService.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _service.markThreadRead(chatId: widget.chatId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);
    _controller.clear();
    HapticFeedback.lightImpact();
    debugPrint('User: $text');

    try {
      await _service.sendMessage(text, chatId: widget.chatId);
    } on FirebaseFunctionsException catch (error) {
      final code = error.code.toLowerCase();
      final message = code == 'unavailable' || code == 'deadline-exceeded'
          ? "You're offline. Please try again."
          : 'Something went wrong. Try again.';
      _showSnack(message);
      _controller.text = text;
    } catch (_) {
      _showSnack("You're offline. Please try again.");
      _controller.text = text;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleAction(SupportChatAction action) async {
    HapticFeedback.selectionClick();
    switch (action.type) {
      case 'navigate_parking':
        final lat = _readDouble(action.payload['latitude']);
        final lng = _readDouble(action.payload['longitude']);
        final label = action.payload['parkingName']?.toString() ?? 'Parking';
        if (lat == null || lng == null) return;
        await NavigationService.instance.launchOutdoorNavigation(
          destLat: lat,
          destLng: lng,
          label: label,
        );
        return;
      case 'extend_booking':
        final bookingId = action.payload['bookingId']?.toString() ?? '';
        if (bookingId.isEmpty) return;
        final parking = Map<String, dynamic>.from(
          action.payload['parking'] as Map? ?? const {},
        );
        final slot = action.payload['slotId']?.toString() ?? '';
        final floorIndex = _readInt(action.payload['floorIndex']);
        final start = _readDateTime(action.payload['startTime']);
        final end = _readDateTime(action.payload['endTime']);
        if (!mounted || start == null || end == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ParkingTimerScreen(
              bookingId: bookingId,
              parking: parking,
              slot: slot,
              floorIndex: floorIndex,
              start: start,
              end: end,
            ),
          ),
        );
        return;
      case 'open_wallet':
        if (!mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
        return;
      case 'open_bookings':
      default:
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FC),
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Support',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    _isSending ? 'Typing a reply...' : 'Parking assistant',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<SupportChatMessage>>(
                stream: _service.messagesStream(chatId: widget.chatId),
                builder: (context, snapshot) {
                  final messages =
                      snapshot.data ?? const <SupportChatMessage>[];

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _service.markThreadRead(chatId: widget.chatId);
                    _scrollToBottom();
                  });

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong. Try again.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData && _isSending) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  return ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    children: [
                      if (messages.isEmpty)
                        _EmptySupportState(
                          onPromptTap: (text) {
                            _controller.text = text;
                            _sendMessage();
                          },
                        )
                      else
                        ..._buildMessageGroups(messages),
                      if (_isSending) const _TypingBubble(),
                    ],
                  );
                },
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMessageGroups(List<SupportChatMessage> messages) {
    final widgets = <Widget>[];
    DateTime? previousTime;

    for (final message in messages) {
      final currentTime = message.timestamp;
      if (currentTime != null &&
          (previousTime == null ||
              currentTime.difference(previousTime).inMinutes.abs() > 20)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  DateFormat('MMM d, h:mm a').format(currentTime),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      previousTime = currentTime ?? previousTime;

      widgets.add(
        _SupportBubble(
          message: message,
          onActionTap: message.action == null
              ? null
              : () => _handleAction(message.action!),
        ),
      );
    }

    return widgets;
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7ECF6)),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Ask about bookings, slots, payment...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

class _SupportBubble extends StatelessWidget {
  final SupportChatMessage message;
  final VoidCallback? onActionTap;

  const _SupportBubble({required this.message, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isUser ? 22 : 8),
                      bottomRight: Radius.circular(isUser ? 8 : 22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: isUser
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (message.timestamp != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.jm().format(message.timestamp!),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.72)
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (message.action != null && !isUser) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.08,
                      ),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      message.action!.label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySupportState extends StatelessWidget {
  final ValueChanged<String> onPromptTap;

  const _EmptySupportState({required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    const prompts = <String>[
      'Extend my parking',
      'Navigate to parking',
      'Payment failed',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask your parking assistant anything',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookings, slots, payment issues, extensions, and navigation help all live here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: prompts
                .map(
                  (prompt) => ActionChip(
                    onPressed: () => onPromptTap(prompt),
                    label: Text(
                      prompt,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
