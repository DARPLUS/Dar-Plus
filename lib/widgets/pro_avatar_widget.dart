import 'dart:convert';
import 'package:flutter/material.dart';

/// Widget réutilisable pour l'avatar d'un utilisateur ou professionnel.
/// Affiche la photo réseau, base64 ou asset si disponible,
/// sinon un avatar coloré unique avec initiales déterministes.
class ProAvatarWidget extends StatelessWidget {
  final double size;
  final String name;
  final String? photoBase64;
  final String? photoUrl;
  final String? avatarAsset;
  final double borderRadius;
  final bool showVerifiedBadge;
  final bool fill;

  const ProAvatarWidget({
    super.key,
    this.size = 64,
    required this.name,
    this.photoBase64,
    this.photoUrl,
    this.avatarAsset,
    this.borderRadius = 16,
    this.showVerifiedBadge = true,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (fill)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: _buildImage(),
            ),
          )
        else
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
    // Une photo personnalisée (base64) est prioritaire sur l'ancienne URL.
    final b64 = photoBase64?.trim() ?? '';
    if (b64.isNotEmpty) {
      return _buildBase64Image();
    }
    final url = photoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAssetOrInitials(),
      );
    }
    return _buildAssetOrInitials();
  }

  Widget _buildBase64Image() {
    final hasPhoto = photoBase64 != null && photoBase64!.trim().isNotEmpty;
    if (hasPhoto) {
      try {
        final bytes = base64Decode(photoBase64!.trim());
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAssetOrInitials(),
        );
      } catch (_) {
        return _buildAssetOrInitials();
      }
    }
    return _buildAssetOrInitials();
  }

  Widget _buildAssetOrInitials() {
    final asset = avatarAsset?.trim() ?? '';
    if (asset.isNotEmpty) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(),
      );
    }
    return _buildInitialAvatar();
  }

  Widget _buildInitialAvatar() {
    final cleanName = name.trim();
    String initials = '?';
    if (cleanName.isNotEmpty) {
      final words = cleanName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2) {
        initials = '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else {
        initials = cleanName.length >= 2
            ? cleanName.substring(0, 2).toUpperCase()
            : cleanName[0].toUpperCase();
      }
    }

    // Palette étendue de 10 couleurs élégantes et distinctes
    final colors = [
      const Color(0xFF0D544E), // Dar Plus Teal
      const Color(0xFFDE6D1B), // Dar Plus Orange
      const Color(0xFF4338CA), // Indigo
      const Color(0xFF059669), // Emerald
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFFD97706), // Amber
      const Color(0xFF7C3AED), // Violet
      const Color(0xFFE11D48), // Rose
      const Color(0xFF0891B2), // Cyan
      const Color(0xFF475569), // Slate
    ];

    int hash = 0;
    for (int i = 0; i < cleanName.length; i++) {
      hash = (hash * 31 + cleanName.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final primaryColor = colors[cleanName.isEmpty ? 0 : (hash % colors.length)];
    final secondaryColor = Color.lerp(primaryColor, Colors.black, 0.2) ?? primaryColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
