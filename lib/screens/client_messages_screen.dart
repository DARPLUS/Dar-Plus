import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'booking_chat_screen.dart';
import 'booking_detail_screen.dart';

/// Boîte de réception du client : liste les professionnels contactés avec leur
/// photo, leur nom, la dernière message et le statut de la demande.
class ClientMessagesScreen extends StatelessWidget {
  const ClientMessagesScreen({super.key, this.embedded = false});

  /// `true` lorsque l'écran est affiché comme onglet de la barre de
  /// navigation : l'AppBar ne doit alors pas proposer de retour.
  final bool embedded;

  bool _chatAvailable(Map<String, dynamic> booking) {
    final status = booking['status'];
    return status == 'confirmee' ||
        status == 'terminee' ||
        (status == 'annulee' && booking['acceptedAt'] is Timestamp);
  }

  List<_ClientConversation> _groupByProfessional(
    List<Map<String, dynamic>> bookings,
  ) {
    final grouped = <String, _ClientConversation>{};
    // Les réservations arrivent déjà triées de la plus récente à la plus
    // ancienne : le premier passage par un pro reste la conversation affichée.
    for (final booking in bookings) {
      final proId = booking['proId']?.toString().trim() ?? '';
      if (proId.isEmpty) continue;

      final existing = grouped[proId];
      if (existing == null) {
        grouped[proId] = _ClientConversation(
          booking: booking,
          requestCount: 1,
          chatAvailable: _chatAvailable(booking),
        );
        continue;
      }

      existing.requestCount += 1;
      final bookingIsChatAvailable = _chatAvailable(booking);
      if (!existing.chatAvailable && bookingIsChatAvailable) {
        existing.booking = booking;
        existing.chatAvailable = true;
      }
    }
    return grouped.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text('messages_inbox'.tr()),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().streamClientBookings(),
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

          final bookings = snapshot.data ?? const <Map<String, dynamic>>[];
          final conversations = _groupByProfessional(bookings);

          if (conversations.isEmpty) {
            return _ClientMessagesEmptyState(isDark: isDark);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationTile(
                key: ValueKey(
                  '${conversation.booking['proId']}_${conversation.booking['id']}',
                ),
                booking: conversation.booking,
                requestCount: conversation.requestCount,
                chatAvailable: conversation.chatAvailable,
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }
}

class _ClientConversation {
  Map<String, dynamic> booking;
  int requestCount;
  bool chatAvailable;

  _ClientConversation({
    required this.booking,
    required this.requestCount,
    required this.chatAvailable,
  });
}

class _ClientMessagesEmptyState extends StatelessWidget {
  const _ClientMessagesEmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF16433F)
                    : const Color(0xFFE6F1EF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_rounded,
                size: 44,
                color: isDark
                    ? const Color(0xFF5EEAD4)
                    : const Color(0xFF0D544E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'messages_empty_title'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'messages_empty_body'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    super.key,
    required this.booking,
    required this.requestCount,
    required this.chatAvailable,
    required this.isDark,
  });

  final Map<String, dynamic> booking;
  final int requestCount;
  final bool chatAvailable;
  final bool isDark;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  Map<String, dynamic>? _professional;

  String get _proId => widget.booking['proId']?.toString() ?? '';

  String get _bookingId => widget.booking['id']?.toString() ?? '';

  String get _serviceType =>
      widget.booking['serviceType']?.toString() ?? 'Service';

  String get _professionalName {
    final fromBooking = widget.booking['proName']?.toString().trim() ?? '';
    if (fromBooking.isNotEmpty) return fromBooking;
    final fromProfile = _professional?['fullName']?.toString().trim() ?? '';
    return fromProfile.isNotEmpty ? fromProfile : 'Professionnel';
  }

  @override
  void initState() {
    super.initState();
    _loadProfessional();
  }

  Future<void> _loadProfessional() async {
    if (_proId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_proId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() => _professional = doc.data());
      }
    } catch (_) {
      // Photo indisponible : l'avatar affichera l'initiale du professionnel.
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _lastMessageStream() {
    if (!widget.chatAvailable || _bookingId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('bookings')
        .doc(_bookingId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  void _openConversation() {
    final navigator = Navigator.of(context);
    if (widget.chatAvailable) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BookingChatScreen(booking: widget.booking),
        ),
      );
    } else {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(booking: widget.booking),
        ),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'en_attente':
        return 'tab_pending'.tr();
      case 'confirmee':
        return 'tab_confirmed'.tr();
      case 'terminee':
        return 'tab_completed'.tr();
      case 'annulee':
        return 'tab_cancelled'.tr();
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'en_attente':
        return const Color(0xFFDE6D1B);
      case 'confirmee':
        return const Color(0xFF2563EB);
      case 'terminee':
        return const Color(0xFF10B981);
      case 'annulee':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  DateTime? _createdAt() {
    final value = widget.booking['createdAt'];
    return value is Timestamp ? value.toDate() : null;
  }

  String _formatWhen(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) {
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildAvatar() {
    final base64Photo = (_professional?['photoBase64'] ?? '').toString().trim();
    if (base64Photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 27,
          backgroundColor: widget.isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFE6F1EF),
          backgroundImage: MemoryImage(base64Decode(base64Photo)),
        );
      } catch (_) {}
    }

    final photoUrl = (_professional?['photoUrl'] ?? '').toString().trim();
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 27,
        backgroundColor: widget.isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE6F1EF),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, _) {},
      );
    }

    final name = _professionalName;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFF0D544E),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTile({
    String lastMessage = '',
    DateTime? lastMessageAt,
    bool hasConversation = false,
  }) {
    final status = widget.booking['status']?.toString() ?? '';
    final subtitle = lastMessage.isNotEmpty ? lastMessage : _serviceType;
    final when = _formatWhen(lastMessageAt ?? _createdAt());
    final cardColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final previewColor = widget.isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _openConversation,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _professionalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (when.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              when,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _serviceType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0D544E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: previewColor,
                              fontStyle: hasConversation
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                        if (widget.requestCount > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? const Color(0xFF16433F)
                                  : const Color(0xFFE6F1EF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.requestCount}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Color(0xFF5EEAD4)
                                    : Color(0xFF0D544E),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.chatAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.chatAvailable) {
      return _buildTile();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _lastMessageStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return _buildTile();

        final data = docs.first.data();
        final text = data['text']?.toString() ?? '';
        final createdAt = data['createdAt'];
        final lastAt = createdAt is Timestamp ? createdAt.toDate() : null;
        return _buildTile(
          lastMessage: text,
          lastMessageAt: lastAt,
          hasConversation: text.isNotEmpty,
        );
      },
    );
  }
}
