import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../providers/ai_assistant_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/professional_recommendation_card.dart';
import '../services/gemini_service.dart';
import '../services/ai_context_service.dart';
import '../core/routing/app_routes.dart';
import 'estimate_screen.dart';
import 'service_detail_screen.dart';
import 'urgency_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.userLocation});

  final String? userLocation;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _teal = Color(0xFF0D7772);
  static const _page = Color(0xFFFAF7F4);
  static const _ink = Color(0xFF202235);
  static const _muted = Color(0xFF85879A);
  static const _border = Color(0xFFE5DDD7);

  final TextEditingController _inputController = TextEditingController();
  final GlobalKey<FormState> _inputFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<AiAssistantProvider>();
        provider.startNewConversation();
        provider.loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (_isExistingBookingHelpRequest(text)) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Navigator.of(context).pushNamed(AppRoutes.bookings);
      return;
    }
    if (_isEmergencyRequest(text)) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const UrgencyScreen()));
      return;
    }
    final provider = context.read<AiAssistantProvider>();
    final location = widget.userLocation?.trim().isNotEmpty == true
        ? widget.userLocation!.trim()
        : await _detectUserLocation();
    await provider.sendMessage(
      text,
      languageCode: context.locale.languageCode,
      userLocation: location,
    );
    if (mounted && _scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<String?> _detectUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = <String>{
        if ((place.subLocality ?? '').trim().isNotEmpty)
          place.subLocality!.trim(),
        if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
        if ((place.administrativeArea ?? '').trim().isNotEmpty)
          place.administrativeArea!.trim(),
      }.toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      // Keep chat usable if location permission, GPS, or reverse geocoding fails.
      return null;
    }
  }

  bool _isExistingBookingHelpRequest(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
    final refersToExistingBooking = const [
      'my booking',
      'my bookings',
      'my reservation',
      'my reservations',
      'existing booking',
      'booking status',
      'ma reservation',
      'mes reservations',
      'ma demande',
      'mes demandes',
      'reservation status',
      'حجزي',
      'حجوزاتي',
    ].any(normalized.contains);
    final requestsHelp = const [
      'help',
      'support',
      'status',
      'track',
      'check',
      'manage',
      'problem',
      'issue',
      'aide',
      'assistance',
      'suivi',
      'statut',
      'probleme',
      'consulter',
      'voir',
      'annuler',
    ].any(normalized.contains);
    return (refersToExistingBooking && requestsHelp) ||
        normalized.trim() == 'ma reservation' ||
        normalized.trim() == 'my booking' ||
        normalized.trim() == 'mes reservations' ||
        normalized.trim() == 'my bookings' ||
        normalized.trim() == 'حجزي' ||
        normalized.trim() == 'حجوزاتي';
  }

  void _openProfessional(
    Map<String, dynamic> professional, {
    required bool openBooking,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          proData: professional,
          openBookingOnArrival: openBooking,
        ),
      ),
    );
  }

  void _openEstimate({String? serviceType}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateScreen(initialServiceType: serviceType),
      ),
    );
  }

  bool _isEmergencyRequest(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
    if (const [
      'not an emergency',
      'no emergency',
      'pas une urgence',
      'pas d urgence',
      'غير طارئ',
      'ليس طارئا',
    ].any(normalized.contains)) {
      return false;
    }
    return const [
      'emergency',
      'emergencies',
      'home emergency',
      'urgent',
      'urgence',
      'en urgence',
      'fuite de gaz',
      'gas leak',
      'electric shock',
      'electrocution',
      'flooding',
      'inondation',
      'incendie',
      'fire at home',
      'طوارئ',
      'طارئ',
      'عاجل',
    ].any(normalized.contains);
  }

  Future<void> _showHistory(AiAssistantProvider provider) async {
    await provider.loadConversations();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ai_history'.tr(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ai_new_chat'.tr(),
                      onPressed: () {
                        provider.startNewConversation();
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.add_comment_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: provider.conversations.isEmpty
                    ? Center(child: Text('ai_no_history'.tr()))
                    : ListView.separated(
                        itemCount: provider.conversations.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = provider.conversations[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE6F2E9),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            title: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await provider.openConversation(conversation.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickActions(AiAssistantProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment_outlined, color: _teal),
              title: Text('ai_new_chat'.tr()),
              onTap: () {
                provider.startNewConversation();
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: _teal),
              title: Text('ai_history'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showHistory(provider);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _datePill() => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'ai_today'.tr(),
        style: const TextStyle(
          color: _muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _quickSuggestion({
    required String label,
    required String prompt,
    required IconData icon,
    bool urgent = false,
    VoidCallback? onTap,
  }) {
    final accent = urgent ? const Color(0xFFE5524A) : _teal;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap ?? () => _send(prompt),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: urgent
                      ? const Color(0xFFFFEFEC)
                      : const Color(0xFFE8F2F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: urgent ? accent : _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 20),
      children: [
        _datePill(),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: const BoxDecoration(
                color: _teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ai_welcome_greeting'.tr(),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'ai_welcome_helper'.tr(),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'ai_suggestions_title'.tr(),
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 8.0;
            final itemWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _quickSuggestion(
                    label: 'ai_quick_reservation'.tr(),
                    prompt: 'ai_prompt_reservation'.tr(),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _quickSuggestion(
                    label: 'ai_quick_find_pro'.tr(),
                    prompt: 'ai_prompt_find_pro'.tr(),
                    icon: Icons.search_rounded,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _quickSuggestion(
                    label: 'ai_suggestion_estimate'.tr(),
                    prompt: 'ai_prompt_estimate'.tr(),
                    icon: Icons.monetization_on_outlined,
                    onTap: () => _openEstimate(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _quickSuggestion(
                    label: 'ai_quick_emergency'.tr(),
                    prompt: 'ai_prompt_emergency'.tr(),
                    icon: Icons.warning_amber_rounded,
                    urgent: true,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _datePill(),
          );
        }
        final message = messages[index - 1];
        final precedingMessage = index >= 2 ? messages[index - 2] : null;
        final estimateServiceType =
            message.serviceType ??
            (precedingMessage?.isUser == true
                ? AiContextService.detectServiceType(precedingMessage!.text)
                : null);
        final showEstimateAction =
            !message.isUser &&
            (message.priceEstimate != null ||
                (precedingMessage?.isUser == true &&
                    _isEstimateRequest(precedingMessage!.text))) &&
            _supportsEstimateService(estimateServiceType);
        return _buildMessage(
          message,
          showEstimateAction: showEstimateAction,
          estimateServiceType: estimateServiceType,
        );
      },
    );
  }

  bool _isEstimateRequest(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
    return const [
      'prix',
      'tarif',
      'combien',
      'estimation',
      'devis',
      'cout',
      'price',
      'cost',
      'estimate',
      'كم',
      'سعر',
      'ثمن',
      'تكلفة',
    ].any(normalized.contains);
  }

  bool _supportsEstimateService(String? serviceType) {
    final normalized = (serviceType ?? '')
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ç', 'c');
    return normalized.contains('plomb') ||
        normalized.contains('plumb') ||
        normalized.contains('menage') ||
        normalized.contains('clean') ||
        normalized.contains('nettoy') ||
        normalized.contains('canape') ||
        normalized.contains('sofa') ||
        normalized.contains('peint') ||
        normalized.contains('paint');
  }

  Widget _buildMessage(
    ChatMessage message, {
    bool showEstimateAction = false,
    String? estimateServiceType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatBubble(message: message),
          if (!message.isUser && message.priceEstimate != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 44,
                top: 2,
                bottom: 8,
              ),
              child: Text(
                'ai_tariff_reference'.tr(
                  args: [message.serviceType ?? '', message.priceEstimate!],
                ),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          if (showEstimateAction)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 44,
                top: 2,
                bottom: 10,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openEstimate(serviceType: estimateServiceType),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F1EF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: _teal,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ai_estimate_action'.tr(),
                            style: const TextStyle(
                              color: _teal,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: _teal,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!message.isUser &&
              message.serviceType != null &&
              message.recommendations.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 44,
                top: 2,
                bottom: 10,
              ),
              child: Text(
                'ai_no_professionals'.tr(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
          if (!message.isUser)
            ...message.recommendations.map(
              (professional) => ProfessionalRecommendationCard(
                professional: professional,
                onProfileTap: () =>
                    _openProfessional(professional, openBooking: false),
                onBookTap: () =>
                    _openProfessional(professional, openBooking: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(Object error, AiAssistantProvider provider) {
    final message = error is AiServiceUnavailableException
        ? 'ai_temporarily_unavailable'.tr()
        : error.toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsetsDirectional.only(
        start: 12,
        top: 10,
        bottom: 10,
        end: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${'ai_error'.tr()} $message',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: provider.clearError,
            icon: const Icon(Icons.close, size: 18),
            color: const Color(0xFF991B1B),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          toolbarHeight: 72,
          leadingWidth: 52,
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: _teal,
                      size: 24,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF36C98F),
                        shape: BoxShape.circle,
                        border: Border.all(color: _teal, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ai_screen_title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF36C98F),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'ai_status_available'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Consumer<AiAssistantProvider>(
              builder: (context, provider, _) => IconButton(
                tooltip: 'ai_new_chat'.tr(),
                onPressed: provider.startNewConversation,
                icon: const Icon(Icons.add_comment_outlined, size: 20),
              ),
            ),
            Consumer<AiAssistantProvider>(
              builder: (context, provider, _) => IconButton(
                tooltip: 'ai_history'.tr(),
                onPressed: () => _showHistory(provider),
                icon: const Icon(Icons.history_rounded, size: 21),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14, start: 2),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .4),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ai_assistant_badge'.tr(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Consumer<AiAssistantProvider>(
          builder: (context, provider, _) {
            final messages = provider.messages;
            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? _buildWelcome()
                      : _buildMessageList(messages),
                ),
                if (provider.isSending)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: _teal,
                    backgroundColor: Color(0xFFE9E3DE),
                  ),
                if (provider.errorMessage != null)
                  _buildError(provider.errorMessage!, provider),
                ChatInput(
                  controller: _inputController,
                  formKey: _inputFormKey,
                  isSending: provider.isSending,
                  onSend: _send,
                  onMore: () => _showQuickActions(provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
