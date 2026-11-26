import 'package:easy_localization/easy_localization.dart';

/// Localize the password-change messages returned by FirebaseService.
String localizePasswordChangeMessage(String? message) {
  final normalized = message?.toLowerCase() ?? '';
  if (normalized.contains('incorrect') || normalized.contains('incorrecte')) {
    return 'profile_current_password_incorrect'.tr();
  }
  if (normalized.contains('success') ||
      normalized.contains('succès') ||
      normalized.contains('modifié')) {
    return 'password_change_success'.tr();
  }
  return 'password_change_failed'.tr();
}
