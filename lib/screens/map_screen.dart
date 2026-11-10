import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../services/firebase_service.dart';
import '../widgets/pro_avatar_widget.dart';
import 'service_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  String _selectedCategory = 'Tous';
  bool _onlyAvailable = false;
  double _zoom = 1.0;
  Offset _mapOffset = Offset.zero;
  Offset? _lastFocalPoint;
  bool _isLocating = false;

  // Position simulée du client (centre de la carte)
  Offset _clientPos = const Offset(0.5, 0.5); // 0..1 relatif à la carte

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const List<String> _categories = [
    'Tous', 'Plomberie', 'Électricité', 'Climatisation',
    'Peinture', 'Nettoyage', 'Jardinage',
  ];

  static const List<IconData> _catIcons = [
    Icons.apps_rounded,
    Icons.build_rounded,
    Icons.bolt_rounded,
    Icons.ac_unit_rounded,
    Icons.format_paint_rounded,
    Icons.cleaning_services_rounded,
    Icons.yard_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _detectLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        // On reste sur la position centrale simulée
        // Sur Web, on pourrait appeler navigator.geolocation
        setState(() => _clientPos = const Offset(0.5, 0.5));
      }
    } catch (_) {}
    if (mounted) setState(() => _isLocating = false);
  }

  // Génère des positions pseudo-aléatoires mais stables pour chaque pro
  Offset _proPosition(String proId, int index) {
    final rng = math.Random(proId.hashCode + index);
    // Dispersion autour du client (0.5, 0.5)
    final dx = 0.5 + (rng.nextDouble() - 0.5) * 0.35;
    final dy = 0.5 + (rng.nextDouble() - 0.5) * 0.4;
    return Offset(dx.clamp(0.08, 0.92), dy.clamp(0.08, 0.92));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = AppTheme.titleColorOf(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ─────────────────────────────────────────────
            Container(
              color: isDark ? AppTheme.darkBackground : AppTheme.background,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: titleColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('🗺️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(context.tr('map_title'),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleColor)),
                        ]),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: FirebaseService().streamPros(
                            category: _selectedCategory,
                            onlyAvailable: _onlyAvailable,
                          ),
                          builder: (_, snap) {
                            final count = snap.data?.length ?? 0;
                            return Text(
                              '$count ${context.tr('map_pros_found')}',
                              style: TextStyle(fontSize: 12, color: AppTheme.subtitleColorOf(context)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Bouton Dispo
                  GestureDetector(
                    onTap: () => setState(() => _onlyAvailable = !_onlyAvailable),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _onlyAvailable ? const Color(0xFF10B981) : (isDark ? AppTheme.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _onlyAvailable ? const Color(0xFF10B981) : AppTheme.borderColorOf(context),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                      ),
                      child: Text(
                        context.tr('available'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _onlyAvailable ? Colors.white : titleColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filtres catégories ──────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0D544E) : (isDark ? AppTheme.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0D544E) : AppTheme.borderColorOf(context),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_catIcons[i], size: 14, color: isSelected ? Colors.white : const Color(0xFF0D544E)),
                        const SizedBox(width: 5),
                        Text(
                          cat == 'Tous' ? context.tr('cat_all') : cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : titleColor,
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Carte interactive ────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService().streamPros(
                  category: _selectedCategory,
                  onlyAvailable: _onlyAvailable,
                  sortBy: 'rating',
                ),
                builder: (context, snapshot) {
                  final pros = snapshot.data ?? [];

                  return Stack(
                    children: [
                      // Fond carte satellite simulée
                      GestureDetector(
                        onScaleStart: (details) {
                          _lastFocalPoint = details.focalPoint;
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            // Zoom
                            _zoom = (_zoom * details.scale).clamp(0.6, 3.0);
                            // Pan
                            if (_lastFocalPoint != null) {
                              final delta = details.focalPoint - _lastFocalPoint!;
                              _mapOffset += delta / _zoom;
                              _lastFocalPoint = details.focalPoint;
                            }
                          });
                        },
                        onScaleEnd: (_) => _lastFocalPoint = null,
                        child: ClipRect(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _SatelliteMapPainter(
                              isDark: isDark,
                              zoom: _zoom,
                              offset: _mapOffset,
                            ),
                          ),
                        ),
                      ),

                      // Markers pros
                      ...pros.asMap().entries.map((entry) {
                        final i = entry.key;
                        final pro = entry.value;
                        final proId = (pro['id'] ?? pro['uid'] ?? 'pro_$i').toString();
                        final pos = _proPosition(proId, i);
                        final isAvail = pro['available'] == true;
                        final price = pro['price'] as String? ?? '35 TND/h';

                        return _ProMarker(
                          pro: pro,
                          position: pos,
                          zoom: _zoom,
                          mapOffset: _mapOffset,
                          isAvailable: isAvail,
                          price: price,
                          isDark: isDark,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ServiceDetailScreen(proData: pro))),
                        );
                      }),

                      // Marker client (Vous)
                      _ClientMarker(
                        position: _clientPos,
                        zoom: _zoom,
                        mapOffset: _mapOffset,
                        pulseAnim: _pulseAnim,
                        label: context.tr('map_you'),
                      ),

                      // Boutons Zoom + GPS
                      Positioned(
                        right: 14,
                        top: 14,
                        child: Column(children: [
                          _MapButton(
                            icon: Icons.add_rounded,
                            onTap: () => setState(() => _zoom = (_zoom * 1.3).clamp(0.6, 3.0)),
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.remove_rounded,
                            onTap: () => setState(() => _zoom = (_zoom / 1.3).clamp(0.6, 3.0)),
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.my_location_rounded,
                            color: const Color(0xFF0D544E),
                            onTap: () {
                              setState(() {
                                _mapOffset = Offset.zero;
                                _zoom = 1.0;
                              });
                              _detectLocation();
                            },
                          ),
                        ]),
                      ),

                      // Légende
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LegendItem(color: const Color(0xFF10B981), label: context.tr('available')),
                              const SizedBox(height: 4),
                              _LegendItem(color: const Color(0xFFEF4444), label: context.tr('unavailable')),
                            ],
                          ),
                        ),
                      ),

                      // Indicateur chargement GPS
                      if (_isLocating)
                        Positioned(
                          top: 14, left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D544E),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(children: [
                              SizedBox(width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 6),
                              Text('GPS...', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pro Marker ────────────────────────────────────────────────────────────────
class _ProMarker extends StatelessWidget {
  final Map<String, dynamic> pro;
  final Offset position;
  final double zoom;
  final Offset mapOffset;
  final bool isAvailable;
  final String price;
  final bool isDark;
  final VoidCallback onTap;

  const _ProMarker({
    required this.pro,
    required this.position,
    required this.zoom,
    required this.mapOffset,
    required this.isAvailable,
    required this.price,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final cx = (position.dx - 0.5) * w * zoom + w / 2 + mapOffset.dx;
      final cy = (position.dy - 0.5) * h * zoom + h / 2 + mapOffset.dy;

      if (cx < -60 || cx > w + 60 || cy < -40 || cy > h + 40) {
        return const SizedBox.shrink();
      }

      final dotColor = isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      final borderColor = isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444);

      return Positioned(
        left: cx - 55,
        top: cy - 22,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 24, height: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ProAvatarWidget(
                    name: pro['name'] as String? ?? '',
                    photoBase64: pro['photoBase64'] as String? ?? '',
                    size: 24, borderRadius: 12, showVerifiedBadge: false,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(price,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.titleColor,
                  )),
              const SizedBox(width: 4),
              CircleAvatar(radius: 4, backgroundColor: dotColor),
            ]),
          ),
        ),
      );
    });
  }
}

// ── Client Marker ─────────────────────────────────────────────────────────────
class _ClientMarker extends StatelessWidget {
  final Offset position;
  final double zoom;
  final Offset mapOffset;
  final Animation<double> pulseAnim;
  final String label;

  const _ClientMarker({
    required this.position,
    required this.zoom,
    required this.mapOffset,
    required this.pulseAnim,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final cx = (position.dx - 0.5) * w * zoom + w / 2 + mapOffset.dx;
      final cy = (position.dy - 0.5) * h * zoom + h / 2 + mapOffset.dy;

      return Positioned(
        left: cx - 30,
        top: cy - 30,
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              Container(
                width: 60 * pulseAnim.value,
                height: 60 * pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D544E).withValues(alpha: 0.2 / pulseAnim.value),
                ),
              ),
              // Centre
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D544E),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x440D544E), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D544E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(label,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ),
      );
    });
  }
}

// ── Map Button ────────────────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _MapButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color ?? (isDark ? AppTheme.darkCard : Colors.white),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
        ),
        child: Icon(icon, size: 20, color: color != null ? Colors.white : AppTheme.titleColorOf(context)),
      ),
    );
  }
}

// ── Legend Item ───────────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, color: AppTheme.subtitleColorOf(context))),
    ]);
  }
}

// ── Satellite Map Painter ─────────────────────────────────────────────────────
class _SatelliteMapPainter extends CustomPainter {
  final bool isDark;
  final double zoom;
  final Offset offset;

  const _SatelliteMapPainter({required this.isDark, required this.zoom, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Fond principal (couleur satellite)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = isDark ? const Color(0xFF2D3748) : const Color(0xFF4A7C59),
    );

    final cx = size.width / 2 + offset.dx;
    final cy = size.height / 2 + offset.dy;
    final scale = zoom;

    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF4A5568) : const Color(0xFF8B7355)
      ..strokeWidth = 18 * scale
      ..strokeCap = StrokeCap.round;

    final roadLinePaint = Paint()
      ..color = isDark ? const Color(0xFF718096) : const Color(0xFFD4B483)
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    // Route horizontale
    canvas.drawLine(Offset(0, cy - 40 * scale), Offset(size.width, cy - 40 * scale), roadPaint);
    canvas.drawLine(Offset(0, cy - 40 * scale), Offset(size.width, cy - 40 * scale), roadLinePaint);
    // Route verticale
    canvas.drawLine(Offset(cx + 30 * scale, 0), Offset(cx + 30 * scale, size.height), roadPaint);
    canvas.drawLine(Offset(cx + 30 * scale, 0), Offset(cx + 30 * scale, size.height), roadLinePaint);
    // Route diagonale
    canvas.drawLine(Offset(0, cy + 80 * scale), Offset(size.width, cy + 20 * scale),
        roadPaint..strokeWidth = 12 * scale);

    // ── Bâtiments (rectangles colorés) ──
    final buildingPaint = Paint()..color = isDark ? const Color(0xFF4A5568) : const Color(0xFF8B6914);
    final buildingPaint2 = Paint()..color = isDark ? const Color(0xFF553C7B) : const Color(0xFFAA8533);
    final buildingPaint3 = Paint()..color = isDark ? const Color(0xFF285E61) : const Color(0xFF6B7B3A);

    final buildings = [
      (cx - 120 * scale, cy - 120 * scale, 80.0, 60.0, buildingPaint),
      (cx + 80 * scale, cy - 100 * scale, 70.0, 50.0, buildingPaint2),
      (cx - 140 * scale, cy + 60 * scale, 90.0, 70.0, buildingPaint3),
      (cx + 60 * scale, cy + 50 * scale, 100.0, 80.0, buildingPaint),
      (cx - 200 * scale, cy - 60 * scale, 50.0, 40.0, buildingPaint2),
      (cx + 160 * scale, cy + 20 * scale, 60.0, 90.0, buildingPaint3),
      (cx - 80 * scale, cy + 120 * scale, 70.0, 50.0, buildingPaint),
      (cx + 120 * scale, cy - 160 * scale, 80.0, 55.0, buildingPaint2),
      (cx - 160 * scale, cy + 140 * scale, 55.0, 65.0, buildingPaint3),
    ];

    for (final b in buildings) {
      final rect = Rect.fromLTWH(b.$1, b.$2, b.$3 * scale, b.$4 * scale);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(4 * scale)), b.$5);
      // Toit / ombre
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.translate(2 * scale, 2 * scale),
          Radius.circular(4 * scale),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
    }

    // ── Végétation / espaces verts ──
    final greenPaint = Paint()..color = isDark ? const Color(0xFF276749) : const Color(0xFF2D6A4F);
    for (int i = 0; i < 8; i++) {
      final rng = math.Random(i * 17);
      final gx = cx + (rng.nextDouble() - 0.5) * 300 * scale;
      final gy = cy + (rng.nextDouble() - 0.5) * 400 * scale;
      final gr = (20 + rng.nextDouble() * 20) * scale;
      canvas.drawCircle(Offset(gx, gy), gr, greenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SatelliteMapPainter old) =>
      old.isDark != isDark || old.zoom != zoom || old.offset != offset;
}
