import 'package:flutter/material.dart';

enum ProfessionalIconType {
  user,
  phone,
  email,
  password,
  service,
  adminKey,
  location,
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
    IconData iconData;
    Color primaryColor;
    Color bgGradientStart;
    Color bgGradientEnd;

    switch (iconType) {
      case ProfessionalIconType.user:
        iconData = Icons.person_rounded;
        primaryColor = const Color(0xFF0C5050);
        bgGradientStart = const Color(0xFF0C5050).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFF147A7A).withValues(alpha: 0.08);
        break;

      case ProfessionalIconType.phone:
        iconData = Icons.phone_iphone_rounded;
        primaryColor = const Color(0xFF2563EB); // Royal Blue
        bgGradientStart = const Color(0xFF2563EB).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFF60A5FA).withValues(alpha: 0.08);
        break;

      case ProfessionalIconType.email:
        iconData = Icons.alternate_email_rounded;
        primaryColor = const Color(0xFF0284C7); // Cyan Teal
        bgGradientStart = const Color(0xFF0284C7).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFF38BDF8).withValues(alpha: 0.08);
        break;

      case ProfessionalIconType.password:
        iconData = Icons.lock_outline_rounded;
        primaryColor = const Color(0xFFEA580C); // Warm Orange
        bgGradientStart = const Color(0xFFEA580C).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFFFB923C).withValues(alpha: 0.08);
        break;

      case ProfessionalIconType.service:
        iconData = Icons.handyman_rounded;
        primaryColor = const Color(0xFF059669); // Emerald
        bgGradientStart = const Color(0xFF059669).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFF34D399).withValues(alpha: 0.08);
        break;

      case ProfessionalIconType.adminKey:
        iconData = Icons.admin_panel_settings_rounded;
        primaryColor = const Color(0xFF7C3AED); // Deep Purple
        bgGradientStart = const Color(0xFF7C3AED).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFFA78BFA).withValues(alpha: 0.08);
        break;

      case ProfessionalIconType.location:
        iconData = Icons.location_on_rounded;
        primaryColor = const Color(0xFFE11D48); // Rose
        bgGradientStart = const Color(0xFFE11D48).withValues(alpha: 0.14);
        bgGradientEnd = const Color(0xFFFB7185).withValues(alpha: 0.08);
        break;
    }

    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(left: 12, right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgGradientStart, bgGradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        iconData,
        color: primaryColor,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8E4DC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
          fontWeight: FontWeight.w600,
          fontFamily: 'sans-serif',
        ),
        decoration: InputDecoration(
          prefixIcon: _buildProfessionalIcon(),
          prefixIconConstraints: const BoxConstraints(minWidth: 62, minHeight: 52),
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
                    color: const Color(0xFF64748B),
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
