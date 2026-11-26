import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../widgets/pro_avatar_widget.dart';

class UrgencyScreen extends StatefulWidget {
  const UrgencyScreen({super.key});

  @override
  State<UrgencyScreen> createState() => _UrgencyScreenState();
}

class _UrgencyScreenState extends State<UrgencyScreen> {
  int? _selectedServiceIndex;
  Map<String, dynamic>? _selectedProfessional;
  String _currentAddress = '';
  double? _clientLatitude;
  double? _clientLongitude;
  bool _loadingAddress = false;
  bool _isLocating = false;
  bool _isSubmitting = false;

  // ── Services d'urgence (titleKey maps to i18n) ───────────────────────────
  static const List<Map<String, dynamic>> _urgencyServices = [
    {
      'titleKey': 'urgency_plumbing',
      'eta': '15–25 min',
      'icon': Icons.build_rounded,
      'bgColor': Color(0xFFE8F4FD),
      'iconColor': Color(0xFF0284C7),
      'serviceType': 'Plomberie',
    },
    {
      'titleKey': 'urgency_electricity',
      'eta': '20–30 min',
      'icon': Icons.bolt_rounded,
      'bgColor': Color(0xFFFEF3C7),
      'iconColor': Color(0xFFD97706),
      'serviceType': 'Électricité',
    },
    {
      'titleKey': 'urgency_ac',
      'eta': '30–45 min',
      'icon': Icons.ac_unit_rounded,
      'bgColor': Color(0xFFE0F2FE),
      'iconColor': Color(0xFF0891B2),
      'serviceType': 'Climatisation',
    },
    {
      'titleKey': 'urgency_water_heater',
      'eta': '25–40 min',
      'icon': Icons.local_fire_department_rounded,
      'bgColor': Color(0xFFFEE2E2),
      'iconColor': Color(0xFFDC2626),
      'serviceType': 'Plomberie',
    },
    {
      'titleKey': 'urgency_fridge',
      'eta': '35–50 min',
      'icon': Icons.kitchen_rounded,
      'bgColor': Color(0xFFE0F2FE),
      'iconColor': Color(0xFF0D544E),
      'serviceType': 'Réfrigérateur',
    },
    {
      'titleKey': 'urgency_painting',
      'eta': '30–45 min',
      'icon': Icons.format_paint_rounded,
      'bgColor': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFEA580C),
      'serviceType': 'Peinture',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadClientAddress();
  }

  // ── Charge l'adresse depuis le profil Firestore ──────────────────────────
  Future<void> _loadClientAddress() async {
    setState(() => _loadingAddress = true);
    try {
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        final addr = data['address'] as String?;
        final city = data['city'] as String?;
        if (addr != null && addr.trim().isNotEmpty) {
          setState(() => _currentAddress = addr.trim());
        } else if (city != null && city.trim().isNotEmpty) {
          setState(() => _currentAddress = city.trim());
        } else {
          setState(() => _currentAddress = 'Tunis, Tunisie');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Tunis, Tunisie');
    }
    if (mounted) setState(() => _loadingAddress = false);
  }

  // ── Géolocalisation via navigateur (Web) ─────────────────────────────────
  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Le service de localisation est désactivé.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Autorisation de localisation refusée.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final latitude = position.latitude;
      final longitude = position.longitude;
      if (mounted) {
        setState(() {
          _clientLatitude = latitude;
          _clientLongitude = longitude;
          _currentAddress =
              '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
        });
      }
    } catch (_) {
      // Fallback : recharger depuis le profil
      await _loadClientAddress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('location_failed'.tr()),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Dialog modifier l'adresse ────────────────────────────────────────────
  void _editAddress() async {
    final ctrl = TextEditingController(text: _currentAddress);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'edit_address'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            validator: (value) => (value ?? '').trim().length < 5
                ? 'booking_address_required'.tr()
                : null,
            decoration: InputDecoration(
              labelText: 'booking_address'.tr(),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFDC2626),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(color: AppTheme.subtitleColorOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _currentAddress = result;
        _clientLatitude = null;
        _clientLongitude = null;
      });
    }
  }

  // ── Confirmation et envoi urgence ────────────────────────────────────────
  Future<void> _confirmUrgency() async {
    if (_selectedServiceIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('urgency_select_type'.tr()),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }

    final service = _urgencyServices[_selectedServiceIndex!];
    final professional = _selectedProfessional;
    if (professional == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('urgency_select_pro'.tr())));
      return;
    }
    final serviceTitle = context.tr(service['titleKey'] as String);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.emergency_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'urgency_confirm_title'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
              label: 'urgency_service_label'.tr(),
              value: serviceTitle,
            ),
            _ConfirmRow(
              label: 'urgency_professional_label'.tr(),
              value: professional['name'] as String? ?? '',
            ),
            _ConfirmRow(label: 'ETA', value: service['eta'] as String),
            _ConfirmRow(label: 'booking_address'.tr(), value: _currentAddress),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'urgency_fee_warning'.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(color: AppTheme.subtitleColorOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('urgency_send'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await FirebaseService().createBooking(
        proId: professional['id'] as String,
        proName: professional['name'] as String? ?? 'Professionnel',
        proPhone: professional['phone'] as String? ?? '',
        proPhotoBase64: professional['photoBase64']?.toString() ?? '',
        proPhotoUrl: professional['photoUrl']?.toString() ?? '',
        proLocation: professional['location']?.toString() ?? '',
        proBio: professional['bio']?.toString() ?? '',
        proExperienceYears: professional['experienceYears'] is num
            ? (professional['experienceYears'] as num).toInt()
            : null,
        serviceType: service['serviceType'] as String,
        price: 'urgency_price'.tr(),
        address: _currentAddress,
        description: '${'urgency_label'.tr()} — $serviceTitle',
        isUrgent: true,
        scheduledDate: 'slot_asap'.tr(),
        clientLatitude: _clientLatitude,
        clientLongitude: _clientLongitude,
      );
      if (result['success'] != true) {
        throw StateError(
          result['message']?.toString() ?? 'booking_failed'.tr(),
        );
      }
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('urgency_sent_success'.tr()),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'error'.tr()} : $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : const Color(0xFFFAF7F4);
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final titleColor = AppTheme.titleColorOf(context);
    final subColor = AppTheme.subtitleColorOf(context);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar rouge urgence ────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emergency_rounded, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'urgency_title'.tr(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  'urgency_subtitle'.tr(),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF4ADE80)),
                    SizedBox(width: 5),
                    Text(
                      'urgency_live_badge'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Titre section ────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'urgency_which_type'.tr(),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Liste des services ────────────────────────────
                  ..._urgencyServices.asMap().entries.map((entry) {
                    final i = entry.key;
                    final svc = entry.value;
                    final isSelected = _selectedServiceIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedServiceIndex = i;
                          _selectedProfessional = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFDC2626)
                                      .withValues(alpha: 0.06)
                                : cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFDC2626)
                                  : (isDark
                                        ? AppTheme.darkDivider
                                        : const Color(0xFFEDE8E1)),
                              width: isSelected ? 1.8 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.15 : 0.03,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: svc['bgColor'] as Color,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  svc['icon'] as IconData,
                                  color: svc['iconColor'] as Color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr(svc['titleKey'] as String),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFFDC2626)
                                            : titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 12,
                                          color: subColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'ETA: ${svc['eta']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'urgency_fee_badge'.tr(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDE6D1B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFFDC2626)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFDC2626)
                                        : (isDark
                                              ? const Color(0xFF475569)
                                              : const Color(0xFFCBD5E1)),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 6),

                  // ── Position actuelle ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkDivider
                            : const Color(0xFFEDE8E1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'urgency_your_position'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Bouton GPS
                                _isLocating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF0D544E),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.my_location_rounded,
                                          color: Color(0xFF0D544E),
                                          size: 20,
                                        ),
                                        tooltip: 'use_my_location'.tr(),
                                        onPressed: _detectLocation,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _editAddress,
                                  child: Text(
                                    'edit_address_short'.tr(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D544E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _loadingAddress
                            ? const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0D544E),
                                  ),
                                ),
                              )
                            : Text(
                                _currentAddress.isEmpty
                                    ? 'urgency_no_address'.tr()
                                    : _currentAddress,
                                style: TextStyle(fontSize: 13, color: subColor),
                              ),
                        if (_clientLatitude != null && _clientLongitude != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              'urgency_location_sharing_notice'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFF0D7A72),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        // Carte simulée
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 110,
                            width: double.infinity,
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFE2E8F0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(double.infinity, 110),
                                  painter: _MapGridPainter(isDark: isDark),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'urgency_my_position'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildAvailablePros(isDark, titleColor),
                  const SizedBox(height: 16),

                  // ── Bandeau avertissement ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFF92400E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'urgency_extra_fees_notice'.tr(),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bouton Envoyer ───────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _confirmUrgency,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.emergency_rounded, size: 22),
            label: Text(
              _isSubmitting ? 'loading'.tr() : 'urgency_send_button'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailablePros(bool isDark, Color titleColor) {
    final serviceType = _selectedServiceIndex == null
        ? null
        : _urgencyServices[_selectedServiceIndex!]['serviceType'] as String;
    if (serviceType == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamPros(
        category: serviceType,
        onlyAvailable: true,
        sortBy: 'rating',
      ),
      builder: (context, snapshot) {
        final pros = snapshot.data ?? [];
        if (pros.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('urgency_no_matching_pro'.tr()),
          );
        }
        final displayPros = pros.take(8).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 5,
                  backgroundColor: Color(0xFF4ADE80),
                ),
                const SizedBox(width: 8),
                Text(
                  'urgency_pros_available'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: displayPros.map((pro) {
                final name = (pro['name'] as String? ?? '').split(' ').first;
                final distance = pro['distance']?.toString() ?? '? km';
                final isSelected = _selectedProfessional?['id'] == pro['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedProfessional = pro),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 88,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFDC2626)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          ProAvatarWidget(
                            name: pro['name'] as String? ?? '',
                            photoBase64: pro['photoBase64'] as String? ?? '',
                            size: 56,
                            borderRadius: 28,
                            showVerifiedBadge: false,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            isSelected ? 'urgency_selected_pro'.tr() : distance,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

// ── Widget helper ─────────────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ── CustomPainter : grille carte simulée ─────────────────────────────────────
class _MapGridPainter extends CustomPainter {
  final bool isDark;
  const _MapGridPainter({required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final blockPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    for (final r in [
      Rect.fromLTWH(20, 10, 50, 30),
      Rect.fromLTWH(90, 25, 40, 40),
      Rect.fromLTWH(160, 5, 60, 25),
      Rect.fromLTWH(240, 30, 45, 35),
      Rect.fromLTWH(310, 10, 55, 45),
      Rect.fromLTWH(40, 60, 65, 30),
      Rect.fromLTWH(130, 65, 50, 25),
      Rect.fromLTWH(220, 70, 70, 30),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        blockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
