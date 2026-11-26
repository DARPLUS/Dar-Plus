import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'pro_avatar_widget.dart';

class ProfessionalRecommendationCard extends StatelessWidget {
  const ProfessionalRecommendationCard({
    super.key,
    required this.professional,
    required this.onProfileTap,
    required this.onBookTap,
  });

  final Map<String, dynamic> professional;
  final VoidCallback onProfileTap;
  final VoidCallback onBookTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = professional['name']?.toString() ?? '';
    final serviceType = professional['serviceType']?.toString() ?? '';
    final location = professional['location']?.toString();
    final rating = professional['rating'] as double?;
    final price = professional['priceLabel']?.toString();
    final hasPrice = professional['hasStoredPrice'] == true;
    final hasAvailability = professional['hasStoredAvailability'] == true;
    final isAvailable = professional['available'] == true;

    return Container(
      margin: const EdgeInsetsDirectional.only(start: 44, top: 5, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProAvatarWidget(
                name: name,
                photoBase64: professional['photoBase64']?.toString() ?? '',
                size: 48,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      serviceType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 7,
            children: [
              _Fact(
                icon: Icons.location_on_outlined,
                label:
                    professional['hasStoredLocation'] == true &&
                        location != null
                    ? location
                    : 'ai_location_unknown'.tr(),
              ),
              _Fact(
                icon: Icons.star_rounded,
                label: rating == null
                    ? 'ai_rating_unknown'.tr()
                    : rating.toStringAsFixed(1),
              ),
              _Fact(
                icon: Icons.circle,
                iconColor: !hasAvailability
                    ? const Color(0xFF94A3B8)
                    : (isAvailable
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626)),
                label: !hasAvailability
                    ? 'ai_availability_unknown'.tr()
                    : (isAvailable ? 'available'.tr() : 'unavailable'.tr()),
              ),
              _Fact(
                icon: Icons.payments_outlined,
                label: hasPrice && price != null && price.isNotEmpty
                    ? price
                    : 'ai_price_unknown'.tr(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onProfileTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF14532D),
                    side: const BorderSide(color: Color(0xFF14532D)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'ai_view_profile'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: hasPrice ? onBookTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14532D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    hasPrice ? 'book_now'.tr() : 'ai_price_unknown'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFF64748B),
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}
