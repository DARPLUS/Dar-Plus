import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'pro_avatar_widget.dart';

class BookingRatingCard extends StatefulWidget {
  const BookingRatingCard({
    super.key,
    required this.booking,
    required this.bookingId,
    required this.isProfessional,
    required this.submitted,
    required this.targetName,
    this.onSubmitted,
  });

  final Map<String, dynamic> booking;
  final String bookingId;
  final bool isProfessional;
  final bool submitted;
  final String targetName;
  final VoidCallback? onSubmitted;

  @override
  State<BookingRatingCard> createState() => _BookingRatingCardState();
}

class _BookingRatingCardState extends State<BookingRatingCard> {
  static const _teal = Color(0xFF0D6F69);
  static const _ink = Color(0xFF202235);
  static const _muted = Color(0xFF85879A);
  static const _line = Color(0xFFE5DDD7);
  static const _criteria = <String>[
    'punctuality',
    'quality',
    'price',
    'communication',
  ];
  static const _tags = <String>[
    'punctual',
    'professional',
    'clean',
    'fast',
    'fair_price',
  ];

  int _rating = 0;
  bool _saving = false;
  bool _ratingAttempted = false;
  late bool _submitted = widget.submitted;
  final _comment = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, int> _criterionRatings = {};
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  DateTime? _bookingDate() {
    for (final key in [
      'completedAt',
      'updatedAt',
      'scheduledDateKey',
      'scheduledDate',
      'createdAt',
    ]) {
      final value = widget.booking[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    if (_rating == 0) {
      setState(() => _ratingAttempted = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseService().submitBookingRating(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _comment.text,
        categoryRatings: {
          for (final entry in _criterionRatings.entries)
            if (entry.value > 0) entry.key: entry.value,
        },
        tags: _selectedTags.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('rating_thanks'.tr())));
      setState(() {
        _saving = false;
        _submitted = true;
      });
      widget.onSubmitted?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('rating_submit_error'.tr())));
    }
  }

  Widget _stars({
    required int value,
    required ValueChanged<int> onSelected,
    required double size,
    required bool enabled,
    required String semanticLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final selected = index < value;
        return Semantics(
          button: true,
          label: '$semanticLabel ${index + 1}',
          child: InkResponse(
            onTap: enabled ? () => onSelected(index + 1) : null,
            radius: size,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size < 22 ? 0 : 2),
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_rounded,
                size: size,
                color: selected
                    ? const Color(0xFFDEA94D)
                    : (isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFE5E1DE)),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _personSummary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : _line;
    final service = widget.booking['serviceType']?.toString().trim() ?? '';
    final date = _bookingDate();
    final dateLabel = date == null
        ? (widget.booking['scheduledDate']?.toString() ?? '')
        : DateFormat('MMMM yyyy', context.locale.languageCode).format(date);
    final photoBase64 = widget.isProfessional
        ? widget.booking['clientPhotoBase64']?.toString()
        : widget.booking['proPhotoBase64']?.toString();
    final photoUrl = widget.isProfessional
        ? widget.booking['clientPhotoUrl']?.toString()
        : widget.booking['proPhotoUrl']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ProAvatarWidget(
            name: widget.targetName,
            photoBase64: photoBase64,
            photoUrl: photoUrl,
            size: 48,
            borderRadius: 14,
            showVerifiedBadge: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (service.isNotEmpty) service,
                    if (dateLabel.isNotEmpty)
                      '${'rating_completed'.tr()} — $dateLabel',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _criterionRow(String key, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'rating_criterion_$key'.tr(),
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : _muted,
                fontSize: 13,
              ),
            ),
          ),
          _stars(
            value: _criterionRatings[key] ?? 0,
            size: 20,
            enabled: !_saving,
            semanticLabel: 'rating_criterion_$key'.tr(),
            onSelected: (value) =>
                setState(() => _criterionRatings[key] = value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : _line;
    final primaryText = isDark ? Colors.white : _ink;
    final secondaryText = isDark ? const Color(0xFF94A3B8) : _muted;
    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${'rating_already_submitted'.tr()} ${widget.targetName}.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _personSummary(context),
          const SizedBox(height: 24),
          Text(
            widget.isProfessional
                ? 'rating_prompt_client'.tr()
                : 'rating_overall_prompt'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _stars(
              value: _rating,
              size: 36,
              enabled: !_saving,
              semanticLabel: 'rating_overall_prompt'.tr(),
              onSelected: (value) => setState(() {
                _rating = value;
                _ratingAttempted = false;
              }),
            ),
          ),
          if (_ratingAttempted) ...[
            const SizedBox(height: 6),
            Text(
              'rating_select_required'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (!widget.isProfessional) ...[
            const SizedBox(height: 26),
            Text(
              'rating_details_title'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 6),
            ..._criteria.map((key) => _criterionRow(key, isDark: isDark)),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'rating_written_title'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _comment,
            maxLength: 500,
            maxLines: 4,
            minLines: 4,
            validator: (value) => (value ?? '').trim().length > 500
                ? 'booking_description_too_long'.tr()
                : null,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_saving,
            decoration: InputDecoration(
              hintText: 'rating_comment_hint'.tr(),
              hintStyle: TextStyle(color: secondaryText, fontSize: 13),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.all(16),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: _teal, width: 1.4),
              ),
            ),
          ),
          if (!widget.isProfessional) ...[
            const SizedBox(height: 26),
            Text(
              'rating_quick_tags_title'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _tags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text('rating_tag_$tag'.tr()),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: _saving
                      ? null
                      : (value) => setState(() {
                          if (value) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        }),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? (isDark ? const Color(0xFF5EEAD4) : _teal)
                        : secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1EEEA),
                  selectedColor: isDark
                      ? const Color(0xFF16433F)
                      : const Color(0xFFDDEFEA),
                  side: BorderSide(
                    color: selected ? const Color(0xFF9BCBC3) : borderColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'rating_submit'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
