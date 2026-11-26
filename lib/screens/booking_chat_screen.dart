import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/localization/service_type_localizer.dart';
import '../models/booking_message.dart';
import '../services/booking_chat_service.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../widgets/booking_client_avatar.dart';
import 'chat_participant_profile_screen.dart';

class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({super.key, required this.booking});

  final Map<String, dynamic> booking;

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final _messageController = TextEditingController();
  final _messageFormKey = GlobalKey<FormState>();
  final _chatService = BookingChatService();
  bool _isSending = false;

  String get _bookingId => widget.booking['id']?.toString() ?? '';

  void _openOtherParticipantProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCurrentUserPro = uid == widget.booking['proId'];
    final participantId =
        (isCurrentUserPro
                ? widget.booking['clientId']
                : widget.booking['proId'])
            ?.toString()
            .trim() ??
        '';
    if (participantId.isEmpty || participantId == uid) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatParticipantProfileScreen(
          booking: widget.booking,
          isProfessional: !isCurrentUserPro,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Remettre à zéro le compteur de messages non lus pour l'utilisateur courant.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _bookingId.isEmpty) return;
    final isPro = uid == widget.booking['proId'];
    final field = isPro ? 'unreadPro' : 'unreadClient';
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(_bookingId)
          .update({field: 0});
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (!(_messageFormKey.currentState?.validate() ?? false)) return;
    final text = _messageController.text.trim();
    if (_isSending) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('booking_chat_sign_in'.tr())));
      return;
    }

    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(bookingId: _bookingId, text: text);
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'booking_chat_send_error'.tr()} $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isPro = uid == widget.booking['proId'];
    final serviceName = localizeServiceType(
      widget.booking['serviceType']?.toString(),
    );
    final rawParticipantName =
        (isPro ? widget.booking['clientName'] : widget.booking['proName'])
            ?.toString()
            .trim() ??
        '';
    final otherParticipant = rawParticipantName.isNotEmpty
        ? rawParticipantName
        : (isPro
              ? 'chat_profile_client'.tr()
              : 'chat_profile_professional'.tr());
    final peerId =
        (isPro ? widget.booking['clientId'] : widget.booking['proId'])
            ?.toString() ??
        '';
    final canCall = peerId.isNotEmpty && peerId != uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (isPro) ...[
              BookingClientAvatar(booking: widget.booking, size: 36),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: InkWell(
                onTap: _openOtherParticipantProfile,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        otherParticipant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        serviceName,
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'call'.tr(),
            onPressed: canCall
                ? () => CallService.instance.startCall(
                    calleeId: peerId,
                    calleeName: otherParticipant,
                    bookingId: _bookingId,
                    serviceType: serviceName,
                  )
                : null,
            icon: const Icon(Icons.call_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<BookingMessage>>(
              stream: _chatService.streamMessages(_bookingId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${'booking_chat_load_error'.tr()} ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? const <BookingMessage>[];
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'booking_chat_empty'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - index - 1];
                    final isProfessional =
                        message.senderId == widget.booking['proId'];
                    final rawSenderName =
                        (isProfessional
                                ? widget.booking['proName']
                                : widget.booking['clientName'])
                            ?.toString()
                            .trim() ??
                        '';
                    final senderName = rawSenderName.isNotEmpty
                        ? rawSenderName
                        : (isProfessional
                              ? 'chat_profile_professional'.tr()
                              : 'chat_profile_client'.tr());
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == uid,
                      senderName: senderName,
                      onSenderTap: _openOtherParticipantProfile,
                    );
                  },
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            formKey: _messageFormKey,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderName,
    required this.onSenderTap,
  });

  final BookingMessage message;
  final bool isMine;
  final String senderName;
  final VoidCallback onSenderTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine
                ? const Color(0xFF14532D)
                : dark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine && senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: InkWell(
                    onTap: onSenderTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              Text(message.text, style: TextStyle(color: textColor)),
              const SizedBox(height: 4),
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                '${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.formKey,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: Border(
            top: BorderSide(
              color: dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'booking_message_required'.tr()
                      : null,
                  onFieldSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'booking_chat_hint'.tr(),
                    counterText: '',
                    filled: true,
                    fillColor: dark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              tooltip: 'booking_chat_send'.tr(),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF14532D),
                foregroundColor: Colors.white,
              ),
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingConversationsScreen extends StatelessWidget {
  const BookingConversationsScreen({super.key, required this.isProfessional});

  final bool isProfessional;

  bool _isChatAvailable(Map<String, dynamic> booking) {
    final status = booking['status'];
    return status == 'confirmee' ||
        status == 'terminee' ||
        (status == 'annulee' && booking['acceptedAt'] is Timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final stream = isProfessional
        ? FirebaseService().streamProBookings()
        : FirebaseService().streamClientBookings();
    return Scaffold(
      appBar: AppBar(title: Text('booking_chat_title'.tr())),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${'booking_chat_load_error'.tr()} ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = (snapshot.data ?? const <Map<String, dynamic>>[])
              .where(_isChatAvailable)
              .toList();
          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'booking_chat_no_conversations'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: bookings.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final rawOtherName =
                  (isProfessional ? booking['clientName'] : booking['proName'])
                      ?.toString()
                      .trim() ??
                  '';
              final otherName = rawOtherName.isNotEmpty
                  ? rawOtherName
                  : (isProfessional
                        ? 'chat_profile_client'.tr()
                        : 'chat_profile_professional'.tr());
              final serviceName = localizeServiceType(
                booking['serviceType']?.toString(),
              );
              return Card(
                child: ListTile(
                  leading: isProfessional
                      ? BookingClientAvatar(booking: booking, size: 48)
                      : const CircleAvatar(
                          backgroundColor: Color(0xFF14532D),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                  title: Text(otherName),
                  subtitle: Text(serviceName),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingChatScreen(booking: booking),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
