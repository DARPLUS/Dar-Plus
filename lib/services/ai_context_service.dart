import '../services/firebase_service.dart';

class AiContext {
  final String? serviceType;
  final bool asksForPrice;
  final String? priceEstimate;
  final List<Map<String, dynamic>> recommendations;
  final String promptContext;

  const AiContext({
    required this.serviceType,
    required this.asksForPrice,
    required this.priceEstimate,
    required this.recommendations,
    required this.promptContext,
  });
}

class AiContextService {
  AiContextService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;

  static const Map<String, List<String>> _serviceKeywords = {
    'Plomberie': [
      'plomb',
      'fuite',
      'robinet',
      'tuyau',
      'evier',
      'canalisation',
      'سباك',
      'سباكة',
      'تسرب',
      'حنفية',
      'plumb',
      'leak',
      'pipe',
      'faucet',
    ],
    'Électricité': [
      'electric',
      'prise',
      'court circuit',
      'coupure de courant',
      'كهرباء',
      'كهربائي',
      'electricity',
      'electrical',
      'outlet',
      'power outage',
    ],
    'Ménage': [
      'menage',
      'nettoy',
      'canape',
      'تنظيف',
      'تنظيف المنزل',
      'clean',
      'housekeeping',
      'sofa',
    ],
    'Peinture': ['peint', 'دهان', 'صباغ', 'paint'],
    'Climatisation': [
      'clim',
      'climatisation',
      'مكيف',
      'تكييف',
      'air conditioning',
      'air conditioner',
    ],
    'Jardinage': ['jardin', 'حديقة', 'بستنة', 'garden'],
    'Serrurerie': [
      'serrur',
      'porte bloquee',
      'cle',
      'قفل',
      'مفتاح',
      'locksmith',
      'lock',
    ],
    'Menuiserie': ['menuis', 'bois', 'نجار', 'نجارة', 'carpenter', 'carpentry'],
    'Réfrigérateur': [
      'refrigerateur',
      'frigo',
      'ثلاجة',
      'refrigerator',
      'fridge',
    ],
    'Machine à laver': [
      'machine a laver',
      'lave linge',
      'غسالة',
      'washing machine',
      'washer',
    ],
  };

  Future<AiContext> buildContext({
    required String message,
    required String languageCode,
    String? userLocation,
  }) async {
    final normalizedMessage = _normalize(message);
    final serviceType = detectServiceType(message);
    final bathroomRenovation = _isBathroomRenovationRequest(normalizedMessage);
    final asksForPrice = _containsAny(normalizedMessage, const [
      'prix',
      'tarif',
      'combien',
      'estimation',
      'devis',
      'price',
      'cost',
      'estimate',
      'كم',
      'سعر',
      'ثمن',
      'تكلفة',
    ]);

    if (bathroomRenovation) {
      return AiContext(
        serviceType: 'Rénovation salle de bain',
        asksForPrice: asksForPrice,
        priceEstimate: null,
        recommendations: const [],
        promptContext: _bathroomRenovationGuidance(languageCode),
      );
    }

    if (serviceType == null) {
      return AiContext(
        serviceType: null,
        asksForPrice: asksForPrice,
        priceEstimate: null,
        recommendations: const [],
        promptContext: switch (languageCode) {
          'ar' => 'لم يتم تحديد خدمة واحدة من فئات التطبيق. أجب مباشرة عن السؤال العام المتعلق بخدمات المنزل أو الإصلاحات. إذا كان هناك نقص مهم، اطرح سؤال توضيح واحدًا فقط. لا تخترع محترفين أو أسعارًا، ولا توصي بمحترف دون بيانات حقيقية.',
          'en' => 'No single app service category matches this message. Answer general home-service and renovation questions directly. Ask at most one clarifying question only when important information is missing. Do not invent professionals or prices, and do not recommend a professional without real data.',
          _ => 'Aucune catégorie de service de l’application ne correspond précisément au message. Réponds directement aux questions générales sur les services à domicile ou les travaux. Pose au plus une question de clarification si une information importante manque. N’invente ni professionnels ni tarifs et ne recommande aucun professionnel sans données réelles.',
        },
      );
    }

    final allPros = await _firebaseService.getAiProfessionals();
    final keywords = _serviceKeywords[serviceType]!;
    final matchingPros = allPros.where((pro) {
      final searchable = _normalize(
        [pro['serviceType'], ...(pro['specialties'] as List<String>)].join(' '),
      );
      return keywords.any(searchable.contains);
    }).toList();

    final location = _normalize(userLocation ?? '');
    final wantsAvailable = _containsAny(normalizedMessage, const [
      'maintenant',
      'disponible',
      'aujourd hui',
      'tout de suite',
      'now',
      'available',
      'today',
      'متاح',
      'الآن',
      'اليوم',
    ]);

    matchingPros.removeWhere(
      (pro) => wantsAvailable && pro['available'] != true,
    );
    matchingPros.sort((a, b) {
      final aAvailable = a['available'] == true ? 1 : 0;
      final bAvailable = b['available'] == true ? 1 : 0;
      if (!wantsAvailable && aAvailable != bAvailable) {
        return bAvailable.compareTo(aAvailable);
      }

      final aLocationMatch = _matchesLocation(a, location);
      final bLocationMatch = _matchesLocation(b, location);
      if (aLocationMatch != bLocationMatch) {
        return aLocationMatch ? -1 : 1;
      }

      final aPrice = a['priceValue'] as double?;
      final bPrice = b['priceValue'] as double?;
      if (asksForPrice && aPrice != bPrice) {
        if (aPrice == null) return 1;
        if (bPrice == null) return -1;
        return aPrice.compareTo(bPrice);
      }

      final aRating = a['rating'] as double?;
      final bRating = b['rating'] as double?;
      if (aRating != bRating) {
        if (aRating == null) return 1;
        if (bRating == null) return -1;
        return bRating.compareTo(aRating);
      }
      return 0;
    });

    final recommendations = matchingPros.take(3).toList();
    final priceEstimate = asksForPrice
        ? _buildPriceEstimate(matchingPros, languageCode)
        : null;
    final promptContext = _buildPromptContext(
      serviceType: serviceType,
      pros: recommendations,
      userLocation: userLocation,
      languageCode: languageCode,
      hasStoredPrices: matchingPros.any((pro) => pro['priceValue'] is double),
    );

    return AiContext(
      serviceType: serviceType,
      asksForPrice: asksForPrice,
      priceEstimate: priceEstimate,
      recommendations: recommendations,
      promptContext: promptContext,
    );
  }

  Future<List<Map<String, dynamic>>> loadRecommendations(
    List<String> professionalIds,
  ) async {
    if (professionalIds.isEmpty) return const [];
    final requestedIds = professionalIds.toSet();
    final professionals = await _firebaseService.getAiProfessionals();
    return professionals
        .where((pro) => requestedIds.contains(pro['id']))
        .toList();
  }

  static String? detectServiceType(String message) {
    final normalizedMessage = _normalize(message);
    for (final entry in _serviceKeywords.entries) {
      if (entry.value.any(
        (keyword) => normalizedMessage.contains(_normalize(keyword)),
      )) {
        return entry.key;
      }
    }
    return null;
  }

  static String detectLanguageCode(
    String message, {
    required String fallbackLanguageCode,
  }) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(message)) return 'ar';

    final words = RegExp(r'[a-zA-ZÀ-ÿ]+')
        .allMatches(message.toLowerCase())
        .map((match) => match.group(0)!)
        .toSet();
    const frenchWords = {
      'bonjour',
      'je',
      'j',
      'veux',
      'voudrais',
      'besoin',
      'mon',
      'ma',
      'mes',
      'une',
      'un',
      'des',
      'les',
      'dans',
      'pour',
      'avec',
      'comment',
      'peux',
      'aider',
      'quelle',
      'quels',
      'services',
      'étapes',
      'renover',
      'renovation',
      'salle',
      'bain',
      'travaux',
      'est',
      'sont',
    };
    const englishWords = {
      'hello',
      'i',
      'want',
      'would',
      'like',
      'need',
      'my',
      'the',
      'a',
      'an',
      'which',
      'services',
      'guide',
      'step',
      'steps',
      'bathroom',
      'renovate',
      'renovation',
      'remodel',
      'help',
      'can',
      'you',
      'how',
      'what',
      'is',
      'are',
      'with',
      'for',
      'please',
      'know',
    };
    final frenchScore = words.intersection(frenchWords).length;
    final englishScore = words.intersection(englishWords).length;
    if (frenchScore > englishScore && frenchScore > 0) return 'fr';
    if (englishScore > frenchScore && englishScore > 0) return 'en';
    if (RegExp(r'[àâçéèêëîïôùûüÿœ]').hasMatch(message.toLowerCase())) {
      return 'fr';
    }

    return const {'fr', 'en', 'ar'}.contains(fallbackLanguageCode)
        ? fallbackLanguageCode
        : 'fr';
  }

  bool _isBathroomRenovationRequest(String message) {
    final mentionsBathroom = _containsAny(message, const [
      'bathroom',
      'bath room',
      'salle de bain',
      'salle de bains',
      'حمام',
      'الحمام',
    ]);
    final asksForRenovationGuidance = _containsAny(message, const [
      'renovat',
      'remodel',
      'redesign',
      'step by step',
      'which services',
      'what services',
      'guide',
      'refaire',
      'renover',
      'renovation',
      'travaux',
      'etapes',
      'par ou commencer',
      'quels services',
      'quelles prestations',
      'تجديد',
      'ترميم',
      'خطوة',
      'ما الخدمات',
      'ماذا احتاج',
      'كيف ابدأ',
      'كيف ابدا',
    ]);
    return mentionsBathroom && asksForRenovationGuidance;
  }

  String _bathroomRenovationGuidance(String languageCode) =>
      switch (languageCode) {
        'ar' => 'الطلب هو إرشاد خطوة بخطوة لتجديد حمام. أجب بخطة واضحة: 1) تحديد الميزانية والاحتياجات والقياسات. 2) اختيار التصميم والمواد. 3) استدعاء سباك لفحص الأنابيب والصرف وتغييرها قبل إغلاق الجدران. 4) استدعاء كهربائي لتأمين الإنارة والمقابس المناسبة للمناطق الرطبة. 5) تنفيذ العزل المائي واختباره. 6) تركيب البلاط والتشطيبات. 7) تركيب الأدوات الصحية والخزائن والإنارة. 8) اختبار التسربات والصرف والكهرباء والتنظيف. اذكر أن السباك والكهربائي والعزل والبلاط/البناء والدهان قد تكون الخدمات المطلوبة حسب حالة الحمام. لا تقل إن هناك تسربًا في المطبخ أو تفترض مشكلة لم يذكرها العميل. اختم بسؤال واحد مفيد عن حجم التجديد أو حالة الأنابيب.',
        'en' => 'The client wants step-by-step guidance for a bathroom renovation. Give a clear sequence: 1) Set a budget, needs, and measurements. 2) Choose the layout and materials. 3) Have a plumber inspect and change pipes and drains before closing walls. 4) Have an electrician plan safe lighting and outlets for wet areas. 5) Waterproof and test the floor and shower area. 6) Install tiles and finishes. 7) Fit sanitary fixtures, cabinets, and lighting. 8) Test for leaks, drainage, and electrical safety, then clean. Explain that the likely services are plumbing, electrical work, waterproofing, tiling/masonry, and possibly painting, depending on the bathroom. Do not claim there is a kitchen leak or assume a fault the client did not mention. End with one useful question about renovation scope or pipe condition.',
        _ => 'La demande porte sur un guide étape par étape pour rénover une salle de bain. Donne un ordre clair : 1) Définir le budget, les besoins et les mesures. 2) Choisir le plan et les matériaux. 3) Faire vérifier et remplacer les tuyaux et évacuations par un plombier avant de refermer les murs. 4) Faire prévoir l’éclairage et les prises adaptées aux pièces humides par un électricien. 5) Réaliser et tester l’étanchéité du sol et de la douche. 6) Poser le carrelage et les finitions. 7) Installer les sanitaires, meubles et luminaires. 8) Tester les fuites, l’évacuation et la sécurité électrique, puis nettoyer. Explique que les services possibles sont plomberie, électricité, étanchéité, carrelage/maçonnerie et éventuellement peinture selon l’état de la pièce. N’affirme pas qu’il y a une fuite dans la cuisine et ne suppose pas une panne non signalée. Termine par une question utile sur l’ampleur des travaux ou l’état des canalisations.',
      };

  bool _containsAny(String text, List<String> values) =>
      values.any((value) => text.contains(_normalize(value)));

  bool _matchesLocation(Map<String, dynamic> pro, String location) {
    if (location.isEmpty) return false;
    final proLocation = _normalize(pro['location']?.toString() ?? '');
    return proLocation.isNotEmpty &&
        (proLocation.contains(location) || location.contains(proLocation));
  }

  String _buildPriceEstimate(
    List<Map<String, dynamic>> professionals,
    String languageCode,
  ) {
    final pricedPros = professionals.where(
      (pro) => pro['priceValue'] is double,
    );
    if (pricedPros.isEmpty) {
      return switch (languageCode) {
        'ar' => 'لا توجد أسعار مسجلة لهذا النوع من الخدمة.',
        'en' => 'No rates are recorded for this service.',
        _ => 'Aucun tarif enregistré pour ce service.',
      };
    }

    final prices = pricedPros.map((pro) => pro['priceValue'] as double).toList()
      ..sort();
    final labels = pricedPros
        .map((pro) => pro['priceLabel']?.toString().trim() ?? '')
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
    final units = labels.map(_unitFromLabel).toSet();
    final rawRange = prices.first == prices.last
        ? _formatPrice(prices.first)
        : '${_formatPrice(prices.first)}–${_formatPrice(prices.last)}';

    if (units.length == 1 && units.single.isNotEmpty) {
      return '$rawRange ${units.single}';
    }
    if (labels.isNotEmpty && units.length > 1) {
      return labels.take(3).join(' • ');
    }

    final unitNotSpecified = switch (languageCode) {
      'ar' => 'الوحدة غير محددة',
      'en' => 'unit not specified',
      _ => 'unité non précisée',
    };
    return '$rawRange ($unitNotSpecified)';
  }

  String _formatPrice(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  String _unitFromLabel(String label) {
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(label);
    return match == null
        ? ''
        : label
              .substring(match.end)
              .trim()
              .replaceAll(RegExp(r'^[\s:—-]+'), '');
  }

  String _buildPromptContext({
    required String serviceType,
    required List<Map<String, dynamic>> pros,
    required String? userLocation,
    required String languageCode,
    required bool hasStoredPrices,
  }) {
    final lines = <String>[
      'Service détecté : $serviceType.',
      if (userLocation != null && userLocation.trim().isNotEmpty)
        switch (languageCode) {
          'ar' => 'الموقع التقريبي الذي رُصد للمستخدم: ${userLocation.trim()}. اذكر هذه المنطقة بإيجاز وبشكل طبيعي في إجابتك لتأكيد أنك أخذتها في الاعتبار. لا تدّع معرفة عنوانه الدقيق.',
          'en' => 'Approximate area detected for the user: ${userLocation.trim()}. Briefly and naturally mention this area in your reply to confirm you are taking it into account. Do not claim to know their exact address.',
          _ => 'Zone approximative détectée pour le client : ${userLocation.trim()}. Mentionne cette zone brièvement et naturellement dans ta réponse pour confirmer que tu en tiens compte. Ne prétends pas connaître son adresse exacte.',
        },
      if (userLocation == null || userLocation.trim().isEmpty) 'Aucune zone du client n’est renseignée. Ne suppose aucune ville ou quartier pour le client.',
      if (userLocation == null || userLocation.trim().isEmpty)
        switch (languageCode) {
          'ar' => 'أخبر المستخدم أنك لا تعرف موقعه الحالي، واطلب منه ذكر المدينة أو الحي إذا كان يريد اقتراح محترف قريب.',
          'en' => 'Tell the user you do not have their current location and ask for their city or neighborhood if they want a nearby professional.',
          _ => 'Dis au client que sa position actuelle ne t’est pas accessible et demande-lui sa ville ou son quartier s’il souhaite un professionnel à proximité.',
        },
      if (pros.isEmpty)
        'Aucun professionnel correspondant n’a été trouvé dans les données réelles de Firestore.'
      else
        'Des profils réels correspondants sont affichés par l’application; ne cite aucun nom dans ta réponse.',
      if (!hasStoredPrices) 'Aucun tarif exploitable n’est enregistré pour ce service; ne donne aucun montant.',
    ];
    for (final pro in pros) {
      final facts = <String>[
        'service=${pro['serviceType']}',
        if (pro['location'] != null) 'zone=${pro['location']}',
        if (pro['available'] is bool)
          'disponible=${pro['available'] == true ? 'oui' : 'non'}',
        if (pro['rating'] is double) 'note=${pro['rating']}',
      ];
      lines.add('- ${facts.join(', ')}');
    }
    return lines.join('\n');
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .trim();
  }
}
