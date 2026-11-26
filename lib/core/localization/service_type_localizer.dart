import 'package:easy_localization/easy_localization.dart';

/// Translate known service/category labels while preserving custom service names.
String localizeServiceType(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'chat_profile_service_unknown'.tr();

  final normalized = raw
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e');
  final key = switch (normalized) {
    'plomberie' ||
    'plumbing' ||
    'plomberie & sanitaire' ||
    'plumbing & sanitary' => 'cat_plumbing',
    'electricite' ||
    'electricity' ||
    'electrical services' => 'cat_electricity',
    'climatisation' ||
    'air conditioning' ||
    'air conditioning & heating' => 'cat_ac',
    'peinture' || 'painting' => 'cat_paint',
    'menuiserie' || 'carpentry' => 'cat_carpentry',
    'nettoyage' || 'cleaning' => 'cat_cleaning',
    'jardinage' || 'gardening' => 'cat_gardening',
    'serrurerie' || 'locksmith' => 'cat_locksmith',
    'bricolage' || 'handyman' => 'cat_handyman',
    _ => null,
  };
  return key == null ? raw : key.tr();
}
