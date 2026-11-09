import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' as easy;

extension TranslationExtension on BuildContext {
  String tr(String key) {
    try {
      final res = easy.tr(key, context: this);
      if (res != key) return res;
    } catch (_) {}
    return AppLocalizations.of(this).translate(key);
  }
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(context.locale);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
  ];

  static bool isRTL(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      // General & Brand
      'app_name': 'DAR PLUS',
      'good_morning': 'Bon matin',
      'welcome': 'Bonjour',
      'welcome_subtitle': 'Quel service recherchez-vous aujourd\'hui ?',
      'search_hint': 'Rechercher un service, artisan...',
      'categories': 'Nos Services',
      'recommended_pros': 'Artisans recommandés',
      'see_all': 'Voir tout',
      'rating': 'Avis',
      'price_from': 'À partir de',
      'tnd': 'TND',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'loading': 'Chargement...',
      'success': 'Succès',
      'error': 'Une erreur est survenue',
      'pts': 'pts',
      'available': 'Disponible',
      'unavailable': 'Indisponible',

      // Quick Actions
      'action_urgent': 'Urgence 24/7',
      'action_estimate': 'Estimer',
      'action_map': 'Carte GPS',
      'action_urgent_sub': 'Intervention express',
      'action_estimate_sub': 'Devis gratuit',
      'action_map_sub': 'Autour de vous',

      // Categories
      'cat_plumbing': 'Plomberie',
      'cat_electricity': 'Électricité',
      'cat_ac': 'Climatisation',
      'cat_paint': 'Peinture',
      'cat_carpentry': 'Menuiserie',
      'cat_cleaning': 'Nettoyage',
      'cat_gardening': 'Jardinage',
      'cat_locksmith': 'Serrurerie',
      'cat_more': 'Plus',
      'cat_all': 'Tous',

      // Navigation / Drawer
      'menu': 'Menu',
      'home': 'Accueil',
      'search': 'Recherche',
      'bookings': 'Réservations',
      'favorites': 'Favoris',
      'profile': 'Profil',
      'settings': 'Paramètres',
      'language': 'Langue',
      'theme_mode': 'Thème d\'affichage',
      'theme_system': 'Système (par défaut)',
      'theme_light': 'Mode Clair',
      'theme_dark': 'Mode Sombre',
      'theme_choose': 'Choisir le thème',
      'dark_mode': 'Mode Sombre',
      'light_mode': 'Mode Clair',
      'logout': 'Déconnexion',
      'about': 'À propos de DAR PLUS',
      'help': 'Aide & Assistance',
      'role_client': 'Client',
      'role_pro': 'Professionnel',
      'role_admin': 'Administrateur',

      // TabBar Bookings
      'tab_all': 'Toutes',
      'tab_pending': 'En attente',
      'tab_confirmed': 'Confirmées',
      'tab_completed': 'Terminées',
      'tab_cancelled': 'Annulées',
      'no_bookings': 'Aucune réservation trouvée',
      'status': 'Statut',

      // Catalog & Search
      'catalog_title': 'Catalogue & Recherche',
      'all_pros_available': 'Tous les artisans disponibles',
      'pros_in_category': 'Artisans en',
      'filters_and_sort': 'Filtres & Tri',
      'sort_by': 'Trier par',
      'sort_rating': 'Meilleure note ★',
      'sort_price_asc': 'Prix croissant',
      'sort_price_desc': 'Prix décroissant',
      'only_available_now': 'Uniquement disponibles maintenant',
      'apply_filters': 'Appliquer les filtres',
      'no_pros_found': 'Aucun artisan trouvé',
      'adjust_filters_hint': 'Essayez d\'ajuster vos filtres ou votre recherche.',

      // Service Detail & Booking
      'about_pro': 'À propos du professionnel',
      'skills_and_services': 'Prestations & Compétences',
      'client_reviews': 'Derniers avis clients',
      'hourly_rate': 'Tarif horaire',
      'global_rating': 'Note globale',
      'call': 'Appeler',
      'book_now': 'Réserver',
      'book_service': 'Réserver',
      'intervention_address': 'Adresse d\'intervention',
      'address_hint': 'Ex: Rue Habib Bourguiba, La Marsa',
      'need_description': 'Description du besoin',
      'description_hint': 'Ex: Fuite sous évier cuisine à réparer...',
      'confirm_booking': 'Confirmer la réservation',
      'booking_sent_success': 'Demande de réservation envoyée avec succès !',
      'choose_zone': 'Choisir votre zone',
      'profile_updated': 'Profil mis à jour avec succès',
      // Booking extended
      'booking_recap': 'Récapitulatif de réservation',
      'booking_cancel_confirm': 'Confirmer l\'annulation ?',
      'booking_cancelled_success': 'Réservation annulée.',
      'booking_date': 'Date & heure',
      'booking_address': 'Adresse d\'intervention',
      'booking_pro': 'Professionnel',
      'booking_detail_title': 'Détail de la réservation',
      'booking_timeline_request': 'Demande envoyée',
      'booking_timeline_confirm': 'Confirmation',
      'booking_timeline_progress': 'En cours',
      'booking_timeline_done': 'Terminé',
      'slot_asap': 'Dès que possible',
      'slot_tomorrow_morning': 'Demain matin',
      'slot_choose_date': 'Choisir une date',
      'address_too_short': 'Adresse trop courte (min. 10 caractères)',
      'cancel_booking': 'Annuler la réservation',
      'my_bookings': 'Mes réservations',
      'booking_id': 'N° réservation',
      'contact_pro': 'Contacter le pro',
      'call_pro': 'Appeler le professionnel',
    },
    'en': {
      // General & Brand
      'app_name': 'DAR PLUS',
      'good_morning': 'Good morning',
      'welcome': 'Hello',
      'welcome_subtitle': 'What service are you looking for today?',
      'search_hint': 'Search for a service, handyman...',
      'categories': 'Our Services',
      'recommended_pros': 'Recommended Handymen',
      'see_all': 'See all',
      'rating': 'Reviews',
      'price_from': 'Starting from',
      'tnd': 'TND',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'loading': 'Loading...',
      'success': 'Success',
      'error': 'An error occurred',
      'pts': 'pts',
      'available': 'Available',
      'unavailable': 'Unavailable',

      // Quick Actions
      'action_urgent': 'Urgent 24/7',
      'action_estimate': 'Estimate',
      'action_map': 'GPS Map',
      'action_urgent_sub': 'Fast response',
      'action_estimate_sub': 'Free quote',
      'action_map_sub': 'Near you',

      // Categories
      'cat_plumbing': 'Plumbing',
      'cat_electricity': 'Electricity',
      'cat_ac': 'Air Conditioning',
      'cat_paint': 'Painting',
      'cat_carpentry': 'Carpentry',
      'cat_cleaning': 'Cleaning',
      'cat_gardening': 'Gardening',
      'cat_locksmith': 'Locksmith',
      'cat_more': 'More',
      'cat_all': 'All',

      // Navigation / Drawer
      'menu': 'Menu',
      'home': 'Home',
      'search': 'Search',
      'bookings': 'Bookings',
      'favorites': 'Favorites',
      'profile': 'Profile',
      'settings': 'Settings',
      'language': 'Language',
      'theme_mode': 'Display Theme',
      'theme_system': 'System (default)',
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'theme_choose': 'Choose Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'logout': 'Log Out',
      'about': 'About DAR PLUS',
      'help': 'Help & Support',
      'role_client': 'Client',
      'role_pro': 'Professional',
      'role_admin': 'Administrator',

      // TabBar Bookings
      'tab_all': 'All',
      'tab_pending': 'Pending',
      'tab_confirmed': 'Confirmed',
      'tab_completed': 'Completed',
      'tab_cancelled': 'Cancelled',
      'no_bookings': 'No bookings found',
      'status': 'Status',

      // Catalog & Search
      'catalog_title': 'Catalog & Search',
      'all_pros_available': 'All available pros',
      'pros_in_category': 'Pros in',
      'filters_and_sort': 'Filters & Sort',
      'sort_by': 'Sort by',
      'sort_rating': 'Top rated ★',
      'sort_price_asc': 'Price: Low to High',
      'sort_price_desc': 'Price: High to Low',
      'only_available_now': 'Available right now',
      'apply_filters': 'Apply filters',
      'no_pros_found': 'No handymen found',
      'adjust_filters_hint': 'Try adjusting your search or filters.',

      // Service Detail & Booking
      'about_pro': 'About the professional',
      'skills_and_services': 'Services & Skills',
      'client_reviews': 'Recent reviews',
      'hourly_rate': 'Hourly rate',
      'global_rating': 'Overall rating',
      'call': 'Call',
      'book_now': 'Book Now',
      'book_service': 'Book',
      'intervention_address': 'Intervention address',
      'address_hint': 'e.g. Avenue Habib Bourguiba, La Marsa',
      'need_description': 'Description of the issue',
      'description_hint': 'e.g. Water leak under kitchen sink...',
      'confirm_booking': 'Confirm booking',
      'booking_sent_success': 'Booking request sent successfully!',
      'choose_zone': 'Select your area',
      'profile_updated': 'Profile updated successfully',
      // Booking extended
      'booking_recap': 'Booking Summary',
      'booking_cancel_confirm': 'Confirm cancellation?',
      'booking_cancelled_success': 'Booking cancelled.',
      'booking_date': 'Date & time',
      'booking_address': 'Service address',
      'booking_pro': 'Professional',
      'booking_detail_title': 'Booking Detail',
      'booking_timeline_request': 'Request sent',
      'booking_timeline_confirm': 'Confirmed',
      'booking_timeline_progress': 'In progress',
      'booking_timeline_done': 'Completed',
      'slot_asap': 'As soon as possible',
      'slot_tomorrow_morning': 'Tomorrow morning',
      'slot_choose_date': 'Choose a date',
      'address_too_short': 'Address too short (min. 10 chars)',
      'cancel_booking': 'Cancel booking',
      'my_bookings': 'My bookings',
      'booking_id': 'Booking #',
      'contact_pro': 'Contact pro',
      'call_pro': 'Call the professional',
    },
    'ar': {
      // General & Brand
      'app_name': 'دار بلس',
      'good_morning': 'صباح الخير',
      'welcome': 'مرحباً',
      'welcome_subtitle': 'ما هي الخدمة التي تبحث عنها اليوم؟',
      'search_hint': 'ابحث عن خدمة، حرفي...',
      'categories': 'خدماتنا',
      'recommended_pros': 'حرفيون موصى بهم',
      'see_all': 'عرض الكل',
      'rating': 'تقييمات',
      'price_from': 'ابتداءً من',
      'tnd': 'د.ت',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'loading': 'جاري التحميل...',
      'success': 'تم بنجاح',
      'error': 'حدث خطأ ما',
      'pts': 'نقطة',
      'available': 'متاح',
      'unavailable': 'غير متاح',

      // Quick Actions
      'action_urgent': 'طوارئ 24/7',
      'action_estimate': 'تقدير التكلفة',
      'action_map': 'الخريطة',
      'action_urgent_sub': 'تدخل سريع',
      'action_estimate_sub': 'عرض أسعار مجاني',
      'action_map_sub': 'بالقرب منك',

      // Categories
      'cat_plumbing': 'سباكة',
      'cat_electricity': 'كهرباء',
      'cat_ac': 'تكييف',
      'cat_paint': 'دهان',
      'cat_carpentry': 'نجارة',
      'cat_cleaning': 'تنظيف',
      'cat_gardening': 'بستنة',
      'cat_locksmith': 'أقفال',
      'cat_more': 'المزيد',
      'cat_all': 'الكل',

      // Navigation / Drawer
      'menu': 'القائمة',
      'home': 'الرئيسية',
      'search': 'بحث',
      'bookings': 'الحجوزات',
      'favorites': 'المفضلة',
      'profile': 'حسابي',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'theme_mode': 'المظهر',
      'theme_system': 'تلقائي (حسب النظام)',
      'theme_light': 'الوضع الفاتح',
      'theme_dark': 'الوضع الداكن',
      'theme_choose': 'اختر المظهر',
      'dark_mode': 'الوضع الليلي',
      'light_mode': 'الوضع النهاري',
      'logout': 'تسجيل الخروج',
      'about': 'حول دار بلس',
      'help': 'المساعدة والدعم',
      'role_client': 'حريف',
      'role_pro': 'مهني',
      'role_admin': 'مشرف',

      // TabBar Bookings
      'tab_all': 'الكل',
      'tab_pending': 'قيد الانتظار',
      'tab_confirmed': 'مؤكدة',
      'tab_completed': 'مكتملة',
      'tab_cancelled': 'ملغاة',
      'no_bookings': 'لا توجد حجوزات حالياً',
      'status': 'الحالة',

      // Catalog & Search
      'catalog_title': 'الدليل والبحث',
      'all_pros_available': 'جميع الحرفيين المتاحين',
      'pros_in_category': 'حرفيون في',
      'filters_and_sort': 'الفلاتر والترتيب',
      'sort_by': 'ترتيب حسب',
      'sort_rating': 'الأعلى تقييماً ★',
      'sort_price_asc': 'السعر: من الأقل إلى الأعلى',
      'sort_price_desc': 'السعر: من الأعلى إلى الأقل',
      'only_available_now': 'المتاحون الآن فقط',
      'apply_filters': 'تطبيق الفلاتر',
      'no_pros_found': 'لم يتم العثور على أي حرفي',
      'adjust_filters_hint': 'جرب تغيير خيارات البحث أو الفلاتر.',

      // Service Detail & Booking
      'about_pro': 'حول الحرفي',
      'skills_and_services': 'الخدمات والمهارات',
      'client_reviews': 'آخر تقييمات الحرفاء',
      'hourly_rate': 'السعر بالساعة',
      'global_rating': 'التقييم العام',
      'call': 'اتصال',
      'book_now': 'احجز الآن',
      'book_service': 'حجز',
      'intervention_address': 'عنوان التدخل',
      'address_hint': 'مثال: شارع الحبيب بورقيبة، المرسى',
      'need_description': 'وصف العطل أو الطلب',
      'description_hint': 'مثال: تسرب مياه تحت حوض المطبخ...',
      'confirm_booking': 'تأكيد الحجز',
      'booking_sent_success': 'تم إرسال طلب الحجز بنجاح!',
      'choose_zone': 'اختر منطقتك',
      'profile_updated': 'تم تحديث الملف الشخصي بنجاح',
      // Booking extended
      'booking_recap': 'ملخص الحجز',
      'booking_cancel_confirm': 'تأكيد الإلغاء؟',
      'booking_cancelled_success': 'تم إلغاء الحجز.',
      'booking_date': 'التاريخ والوقت',
      'booking_address': 'عنوان التدخل',
      'booking_pro': 'الحرفي',
      'booking_detail_title': 'تفاصيل الحجز',
      'booking_timeline_request': 'تم إرسال الطلب',
      'booking_timeline_confirm': 'تأكيد',
      'booking_timeline_progress': 'جاري التنفيذ',
      'booking_timeline_done': 'مكتمل',
      'slot_asap': 'في أقرب وقت',
      'slot_tomorrow_morning': 'صباح الغد',
      'slot_choose_date': 'اختر تاريخاً',
      'address_too_short': 'العنوان قصير جداً (10 أحرف على الأقل)',
      'cancel_booking': 'إلغاء الحجز',
      'my_bookings': 'حجوزاتي',
      'booking_id': 'رقم الحجز',
      'contact_pro': 'التواصل مع الحرفي',
      'call_pro': 'الاتصال بالحرفي',
    },
  };

  String translate(String key) {
    final translated = easy.tr(key);
    if (translated != key) return translated;
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['fr']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fr', 'en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
