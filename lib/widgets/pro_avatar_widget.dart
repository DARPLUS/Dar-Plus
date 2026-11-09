import 'dart:convert';
import 'package:flutter/material.dart';

/// Widget réutilisable pour l'avatar d'un professionnel.
/// Affiche la photo base64 si disponible, sinon un avatar coloré avec l'initiale.
class ProAvatarWidget extends StatelessWidget {
  final double size;
  final String name;
  final String? photoBase64;
  final double borderRadius;
  final bool showVerifiedBadge;

  const ProAvatarWidget({
    super.key,
    this.size = 64,
    required this.name,
    this.photoBase64,
    this.borderRadius = 16,
    this.showVerifiedBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: _buildImage(),
        ),
        if (showVerifiedBadge)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFF0D544E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    final hasPhoto = photoBase64 != null && photoBase64!.trim().isNotEmpty;
    if (hasPhoto) {
      try {
        final bytes = base64Decode(photoBase64!);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(),
        );
      } catch (_) {
        return _buildInitialAvatar();
      }
    }
    return _buildInitialAvatar();
  }

  Widget _buildInitialAvatar() {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    // Couleur déterministe basée sur le nom
    final colors = [
      const Color(0xFF0D544E),
      const Color(0xFFDE6D1B),
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFEC4899),
      const Color(0xFF0284C7),
    ];
    final colorIndex = name.isEmpty ? 0 : name.codeUnits.first % colors.length;
    final bgColor = colors[colorIndex];

    return Container(
      width: size,
      height: size,
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
