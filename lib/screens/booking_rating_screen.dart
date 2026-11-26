import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/booking_rating_card.dart';

class BookingRatingScreen extends StatelessWidget {
  const BookingRatingScreen({
    super.key,
    required this.booking,
    required this.isProfessional,
    this.alreadySubmitted = false,
  });

  final Map<String, dynamic> booking;
  final bool isProfessional;
  final bool alreadySubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetName = isProfessional
        ? (booking['clientName'] ?? 'Client').toString()
        : (booking['proName'] ?? 'Professionnel').toString();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFAF7F4),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1D2030),
        elevation: 0,
        titleSpacing: 4,
        title: Text(
          isProfessional ? 'rating_rate_client'.tr() : 'rating_page_title'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE9E3DE),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: BookingRatingCard(
            booking: booking,
            bookingId: booking['id']?.toString() ?? '',
            isProfessional: isProfessional,
            submitted: alreadySubmitted,
            targetName: targetName,
            onSubmitted: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
  }
}
