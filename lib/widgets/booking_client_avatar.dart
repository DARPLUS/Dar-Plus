import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'pro_avatar_widget.dart';

class BookingClientAvatar extends StatelessWidget {
  const BookingClientAvatar({
    super.key,
    required this.booking,
    required this.size,
    this.borderRadius = 24,
  });

  final Map<String, dynamic> booking;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final name = booking['clientName']?.toString() ?? 'Client';
    return FutureBuilder<Map<String, String>>(
      future: FirebaseService().getBookingClientPhoto(booking),
      builder: (context, snapshot) {
        final photo = snapshot.data ?? const <String, String>{};
        return ProAvatarWidget(
          name: name,
          photoBase64: photo['photoBase64'] ?? booking['clientPhotoBase64']?.toString(),
          photoUrl: photo['photoUrl'] ?? booking['clientPhotoUrl']?.toString(),
          size: size,
          borderRadius: borderRadius,
          showVerifiedBadge: false,
        );
      },
    );
  }
}
