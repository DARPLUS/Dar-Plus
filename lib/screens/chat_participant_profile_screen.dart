import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/localization/service_type_localizer.dart';
import '../services/firebase_service.dart';
import '../widgets/booking_client_avatar.dart';

/// Read-only profile for the other participant in a booking conversation.
/// It only uses profile details already available to both booking participants.
class ChatParticipantProfileScreen extends StatelessWidget {
  const ChatParticipantProfileScreen({
    super.key,
    required this.booking,
    required this.isProfessional,
  });

  final Map<String, dynamic> booking;
  final bool isProfessional;

  @override
  Widget build(BuildContext context) {
    final uid =
        (isProfessional ? booking['proId'] : booking['clientId'])?.toString() ??
        '';
    final name =
        (isProfessional ? booking['proName'] : booking['clientName'])
            ?.toString()
            .trim() ??
        '';
    final displayName = name.isEmpty
        ? (isProfessional
              ? 'chat_profile_professional'.tr()
              : 'chat_profile_client'.tr())
        : name;
    final rawService = booking['serviceType']?.toString().trim() ?? '';
    final service = rawService.isEmpty ? '' : localizeServiceType(rawService);
    final location = booking['proLocation']?.toString().trim() ?? '';
    final bio = booking['proBio']?.toString().trim() ?? '';
    final experience = booking['proExperienceYears'];
    final price = booking['price']?.toString().trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('chat_profile_title'.tr(args: [displayName]))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: _ProfileAvatar(booking: booking, isPro: isProfessional),
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            isProfessional
                ? (service.isEmpty ? 'chat_profile_professional'.tr() : service)
                : 'chat_profile_client'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (isProfessional && uid.isNotEmpty) ...[
            const SizedBox(height: 18),
            _RatingSummary(uid: uid),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isProfessional && service.isNotEmpty)
                    _ProfileInfoRow(
                      icon: Icons.handyman_outlined,
                      label: 'chat_profile_service'.tr(),
                      value: service,
                    ),
                  if (isProfessional && location.isNotEmpty) ...[
                    if (service.isNotEmpty) const Divider(height: 22),
                    _ProfileInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'chat_profile_zone'.tr(),
                      value: location,
                    ),
                  ],
                  if (isProfessional && price.isNotEmpty) ...[
                    if (service.isNotEmpty || location.isNotEmpty)
                      const Divider(height: 22),
                    _ProfileInfoRow(
                      icon: Icons.payments_outlined,
                      label: 'chat_profile_price'.tr(),
                      value: price,
                    ),
                  ],
                  if (isProfessional && experience is num) ...[
                    if (service.isNotEmpty ||
                        location.isNotEmpty ||
                        price.isNotEmpty)
                      const Divider(height: 22),
                    _ProfileInfoRow(
                      icon: Icons.workspace_premium_outlined,
                      label: 'chat_profile_experience'.tr(),
                      value: 'chat_profile_years'.tr(
                        args: [experience.toInt().toString()],
                      ),
                    ),
                  ],
                  if (isProfessional && bio.isNotEmpty) ...[
                    if (service.isNotEmpty ||
                        location.isNotEmpty ||
                        price.isNotEmpty ||
                        experience is num)
                      const Divider(height: 22),
                    _ProfileInfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'chat_profile_about'.tr(),
                      value: bio,
                    ),
                  ],
                  if (!isProfessional)
                    _ProfileInfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'chat_profile_client'.tr(),
                      value: 'chat_profile_booking_participant'.tr(),
                    ),
                  if (isProfessional &&
                      service.isEmpty &&
                      location.isEmpty &&
                      price.isEmpty &&
                      bio.isEmpty &&
                      experience is! num)
                    Text('chat_profile_unavailable'.tr()),
                ],
              ),
            ),
          ),
          if (isProfessional && uid.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'chat_profile_reviews'.tr(),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ProfessionalReviews(uid: uid),
          ],
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.booking, required this.isPro});

  final Map<String, dynamic> booking;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isPro) {
      return BookingClientAvatar(booking: booking, size: 104, borderRadius: 52);
    }

    final encoded = booking['proPhotoBase64']?.toString().trim() ?? '';
    final photoUrl = booking['proPhotoUrl']?.toString().trim() ?? '';
    ImageProvider? image;
    try {
      if (encoded.isNotEmpty) {
        image = MemoryImage(base64Decode(encoded));
      } else if (photoUrl.isNotEmpty) {
        image = NetworkImage(photoUrl);
      }
    } catch (_) {}

    final initials = (booking['proName']?.toString() ?? 'P')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return CircleAvatar(
      radius: 52,
      backgroundColor: isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFE6F1EF),
      foregroundImage: image,
      child: image == null
          ? Text(
              initials.isEmpty ? 'P' : initials,
              style: TextStyle(
                fontSize: 30,
                color: isDark
                    ? const Color(0xFF5EEAD4)
                    : const Color(0xFF0D544E),
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirebaseService().streamRatingSummary(uid),
      builder: (context, snapshot) {
        final rating = snapshot.data?['rating'];
        final reviewsCount = snapshot.data?['reviewsCount'] ?? 0;
        final ratingLabel = rating is num ? rating.toStringAsFixed(1) : '—';
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A2E1A) : const Color(0xFFFFF4DD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF4A623)),
                  const SizedBox(width: 4),
                  Text(
                    'chat_profile_rating'.tr(
                      namedArgs: {
                        'rating': ratingLabel,
                        'count': reviewsCount.toString(),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfessionalReviews extends StatelessWidget {
  const _ProfessionalReviews({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamReviews(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('chat_profile_reviews_error'.tr());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data ?? const <Map<String, dynamic>>[];
        if (reviews.isEmpty) return Text('chat_profile_no_reviews'.tr());

        return Column(
          children: reviews.take(10).map((review) {
            final rating = review['rating'];
            final comment = review['comment']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF4A623),
                ),
                title: Text(
                  rating is num
                      ? '${rating.toInt()}/5'
                      : 'chat_profile_reviews'.tr(),
                ),
                subtitle: comment.isEmpty ? null : Text(comment),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0D544E), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
