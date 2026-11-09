import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../services/firebase_service.dart';
import '../widgets/pro_avatar_widget.dart';

// Web geolocation via dart:js_interop / conditional import
// On non-web, geolocation falls back to profile address.

class UrgencyScreen extends StatefulWidget {
  const UrgencyScreen({super.key});

  @override
  State<UrgencyScreen> createState() => _UrgencyScreenState();
}

class _UrgencyScreenState extends State<UrgencyScreen> {
  int? _selectedServiceIndex;
  String _currentAddress = '';
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
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('location_web_only')),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isLocating = true);

    try {
      // Use dart:html for web geolocation
      // ignore: avoid_web_libraries_in_flutter
      final dynamic window = (kIsWeb) ? _getWindow() : null;
      if (window == null) throw Exception('not web');

      final completer = _LocationCompleter();
      window['navigator']['geolocation'].callMethod('getCurrentPosition', [
        (pos) {
          final lat = pos['coords']['latitude'];
          final lng = pos['coords']['longitude'];
          completer.complete('$lat, $lng');
        },
        (err) {
          completer.completeError(err.toString());
        },
        {'timeout': 8000, 'enableHighAccuracy': true},
      ]);

      final coords = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('timeout'),
      );

      if (mounted) setState(() => _currentAddress = coords);
    } catch (_) {
      // Fallback : recharger depuis le profil
      await _loadClientAddress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('location_failed')),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  dynamic _getWindow() {
    try {
      // ignore: avoid_web_libraries_in_flutter
      return kIsWeb ? _webWindow() : null;
    } catch (_) {
      return null;
    }
  }

  // ignore: unused_element
  dynamic _webWindow() => null; // replaced at runtime on web by js_util

  // ── Dialog modifier l'adresse ────────────────────────────────────────────
  void _editAddress() async {
    final ctrl = TextEditingController(text: _currentAddress);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('edit_address'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('booking_address'),
            prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'),
                style: TextStyle(color: AppTheme.subtitleColorOf(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _currentAddress = result);
    }
  }

  // ── Confirmation et envoi urgence ────────────────────────────────────────
  Future<void> _confirmUrgency() async {
    if (_selectedServiceIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('urgency_select_type')),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }

    final service = _urgencyServices[_selectedServiceIndex!];
    final serviceTitle = context.tr(service['titleKey'] as String);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 24),
          const SizedBox(width: 8),
          Text(context.tr('urgency_confirm_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: context.tr('urgency_service_label'), value: serviceTitle),
            _ConfirmRow(label: 'ETA', value: service['eta'] as String),
            _ConfirmRow(label: context.tr('booking_address'), value: _currentAddress),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('urgency_fee_warning'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
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
            child: Text(context.tr('cancel'),
                style: TextStyle(color: AppTheme.subtitleColorOf(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('urgency_send')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseService().createBooking(
        proId: 'urgency_auto',
        proName: context.tr('urgency_pro_name'),
        proPhone: '',
        serviceType: service['serviceType'] as String,
        price: context.tr('urgency_price'),
        address: _currentAddress,
        description: '🚨 ${context.tr('urgency_label')} — $serviceTitle',
        scheduledDate: context.tr('slot_asap'),
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('urgency_sent_success')),
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
            content: Text('${context.tr('error')} : $e'),
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
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🚨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('urgency_title'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ]),
                Text(
                  context.tr('urgency_subtitle'),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Row(children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF4ADE80)),
                  SizedBox(width: 5),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
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
                  Row(children: [
                    const Text('⚡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('urgency_which_type'),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── Liste des services ────────────────────────────
                  ..._urgencyServices.asMap().entries.map((entry) {
                    final i = entry.key;
                    final svc = entry.value;
                    final isSelected = _selectedServiceIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedServiceIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFDC2626).withValues(alpha: 0.06)
                                : cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFDC2626) : (isDark ? AppTheme.darkDivider : const Color(0xFFEDE8E1)),
                              width: isSelected ? 1.8 : 1,
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Row(children: [
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(color: svc['bgColor'] as Color, borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.center,
                              child: Icon(svc['icon'] as IconData, color: svc['iconColor'] as Color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(svc['titleKey'] as String),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFDC2626) : titleColor),
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.schedule_rounded, size: 12, color: subColor),
                                  const SizedBox(width: 3),
                                  Text('ETA: ${svc['eta']}', style: TextStyle(fontSize: 12, color: subColor)),
                                  const SizedBox(width: 8),
                                  Text(context.tr('urgency_fee_badge'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDE6D1B))),
                                ]),
                              ],
                            )),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFDC2626) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                  width: 2,
                                ),
                              ),
                              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                            ),
                          ]),
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
                      border: Border.all(color: isDark ? AppTheme.darkDivider : const Color(0xFFEDE8E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Text('📍', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(context.tr('urgency_your_position'),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                            ]),
                            Row(children: [
                              // Bouton GPS
                              _isLocating
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D544E)))
                                  : IconButton(
                                      icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0D544E), size: 20),
                                      tooltip: context.tr('use_my_location'),
                                      onPressed: _detectLocation,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _editAddress,
                                child: Text(context.tr('edit_address_short'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D544E))),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _loadingAddress
                            ? const Center(child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D544E))))
                            : Text(_currentAddress.isEmpty ? context.tr('urgency_no_address') : _currentAddress,
                                style: TextStyle(fontSize: 13, color: subColor)),
                        const SizedBox(height: 10),
                        // Carte simulée
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 110, width: double.infinity,
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(size: const Size(double.infinity, 110), painter: _MapGridPainter(isDark: isDark)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(20)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(context.tr('urgency_my_position'),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ]),
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
                    child: Row(children: [
                      const Text('⚠️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        context.tr('urgency_extra_fees_notice'),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                      )),
                    ]),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _confirmUrgency,
            icon: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.emergency_rounded, size: 22),
            label: Text(
              _isSubmitting ? context.tr('loading') : context.tr('urgency_send_button'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailablePros(bool isDark, Color titleColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamPros(onlyAvailable: true, sortBy: 'rating'),
      builder: (context, snapshot) {
        final pros = snapshot.data ?? [];
        if (pros.isEmpty) return const SizedBox.shrink();
        final displayPros = pros.take(4).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(radius: 5, backgroundColor: Color(0xFF4ADE80)),
              const SizedBox(width: 8),
              Text(context.tr('urgency_pros_available'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor)),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: displayPros.map((pro) {
                final name = (pro['name'] as String? ?? '').split(' ').first;
                final distance = pro['distance'] as String? ?? '? km';
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(children: [
                    ProAvatarWidget(
                      name: pro['name'] as String? ?? '',
                      photoBase64: pro['photoBase64'] as String? ?? '',
                      size: 56, borderRadius: 28, showVerifiedBadge: false,
                    ),
                    const SizedBox(height: 5),
                    Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: titleColor)),
                    Text(distance, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ]),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

// ── Helper pour géolocalisation Web ──────────────────────────────────────────
class _LocationCompleter {
  final _completer = <Function>[];
  Future<String> get future => Future(() async {
    while (_completer.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return _completer.first('') as String;
  });
  void complete(String val) => _completer.add((_) => val);
  void completeError(String err) => throw Exception(err);
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
      Rect.fromLTWH(20, 10, 50, 30), Rect.fromLTWH(90, 25, 40, 40),
      Rect.fromLTWH(160, 5, 60, 25), Rect.fromLTWH(240, 30, 45, 35),
      Rect.fromLTWH(310, 10, 55, 45), Rect.fromLTWH(40, 60, 65, 30),
      Rect.fromLTWH(130, 65, 50, 25), Rect.fromLTWH(220, 70, 70, 30),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), blockPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
