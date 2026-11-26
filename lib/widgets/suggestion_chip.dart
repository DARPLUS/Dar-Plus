import 'package:flutter/material.dart';

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({
    super.key,
    required this.label,
    required this.prompt,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final String prompt;
  final IconData icon;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17, color: const Color(0xFF14532D)),
      label: Text(label),
      labelStyle: const TextStyle(
        color: Color(0xFF14532D),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFDCE9E0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      onPressed: () => onSelected(prompt),
    );
  }
}
