import 'package:flutter/material.dart';

enum ProfessionalIconType {
  user,
  phone,
  email,
  password,
  service,
}

class ProfessionalInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ProfessionalIconType iconType;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const ProfessionalInputField({
    super.key,
    this.controller,
    required this.hintText,
    required this.iconType,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  Widget _buildProfessionalIcon() {
    switch (iconType) {
      case ProfessionalIconType.user:
        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 14, right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4C3B71).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF4C3B71),
            size: 20,
          ),
        );

      case ProfessionalIconType.phone:
        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 14, right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF5B45B2).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.smartphone_rounded,
            color: Color(0xFF5B45B2),
            size: 19,
          ),
        );

      case ProfessionalIconType.email:
        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 14, right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF7E8BA3).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.mail_outline_rounded,
            color: Color(0xFF6B7280),
            size: 19,
          ),
        );

      case ProfessionalIconType.password:
        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 14, right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.lock_rounded,
            color: Color(0xFFE8834F),
            size: 19,
          ),
        );

      case ProfessionalIconType.service:
        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 14, right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.build_rounded,
            color: Color(0xFF64748B),
            size: 18,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E4DC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: Color(0xFF0B1B2B),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'sans-serif',
        ),
        decoration: InputDecoration(
          prefixIcon: _buildProfessionalIcon(),
          prefixIconConstraints: const BoxConstraints(minWidth: 58, minHeight: 48),
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFF8B98A8).withValues(alpha: 0.9),
            fontSize: 14.5,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }
}
