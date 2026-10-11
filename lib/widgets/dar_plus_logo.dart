import 'dart:ui';
import 'package:flutter/material.dart';

class DarPlusLogoPill extends StatelessWidget {
  final Color badgeColor;

  const DarPlusLogoPill({
    super.key,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular D+ badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'D+',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    fontFamily: 'sans-serif',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // DAR PLUS text
              const Text(
                'DAR PLUS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.0,
                  fontFamily: 'sans-serif',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
