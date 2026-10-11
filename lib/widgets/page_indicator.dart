import 'package:flutter/material.dart';

class SlidePageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  const SlidePageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    this.inactiveColor = const Color(0xFFE5E0D8),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 26 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
