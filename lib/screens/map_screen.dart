import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pro_avatar_widget.dart';
import 'service_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  /// Centre de repli (Tunis) lorsque la position réelle n'est pas disponible.
  static const LatLng _fallbackCenter = LatLng(36.8065, 10.1815);
  // Zone de prospection assez large pour couvrir une région entière
  // (ex. les délégations de Bizerte), pas uniquement le centre-ville.
  static const double _nearbyRadiusKm = 160;
  static const Distance _distance = Distance();

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;

  String _selectedCategory = 'Tous';
  bool _onlyAvailable = false;
  bool _isLocating = true;
  bool _locationDenied = false;
  bool _hasRealPosition = false;
  bool _mapReady = false;
  LatLng _clientPosition = _fallbackCenter;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const List<String> _categories = [
    'Tous',
    'Plomberie',
    'Électricité',
    'Climatisation',
    'Peinture',
    'Nettoyage',
    'Nettoyage Canapé',
    'Ménage',
    'Jardinage',
    'Serrurerie',
    'Bricolage',
    'Menuiserie',
    'Réfrigérateur',
    'Machine à laver',
    'Coiffure',
  ];

  static const List<IconData> _catIcons = [
    Icons.apps_rounded,
    Icons.build_rounded,
    Icons.bolt_rounded,
    Icons.ac_unit_rounded,
    Icons.format_paint_rounded,
    Icons.cleaning_services_rounded,
    Icons.chair_alt_rounded,
    Icons.home_rounded,
    Icons.yard_rounded,
    Icons.lock_rounded,
    Icons.handyman_rounded,
    Icons.door_sliding_rounded,
    Icons.kitchen_rounded,
    Icons.local_laundry_service_rounded,
    Icons.content_cut_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnim = Tween<double>(
      begin: 0.8,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _locateClient();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateClient({bool moveMap = true}) async {
    if (mounted) setState(() => _isLocating = true);

    LatLng? found;
    var denied = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        denied = true;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          denied = true;
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 30),
            ),
          );
          found = LatLng(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      denied = true;
    }

    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _locationDenied = denied;
      if (found != null) {
        _clientPosition = found;
        _hasRealPosition = true;
      }
    });

    if (moveMap && _mapReady) {
      _mapController.move(_clientPosition, 15);
    }

    if (found != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Position mise à jour : ${found.latitude.toStringAsFixed(5)}, ${found.longitude.toStringAsFixed(5)}',
          ),
          backgroundColor: const Color(0xFF0D544E),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Suivi en temps réel de la position pour une localisation exacte.
    _positionSub?.cancel();
    _positionSub = null;
    if (!denied) {
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 2,
            ),
          ).listen((position) {
            if (!mounted) return;
            final next = LatLng(position.latitude, position.longitude);
            if (next.latitude == _clientPosition.latitude &&
                next.longitude == _clientPosition.longitude) {
              return;
            }
            setState(() {
              _clientPosition = next;
              _hasRealPosition = true;
              _locationDenied = false;
            });
          }, onError: (_) {});
    }
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  LatLng _demoPointNearClient(double distanceKm, double bearingDegrees) {
    final bearing = bearingDegrees * math.pi / 180;
    final latitudeRadians = _clientPosition.latitude * math.pi / 180;
    final latitudeOffset = distanceKm * math.cos(bearing) / 111.32;
    final longitudeOffset =
        distanceKm * math.sin(bearing) / (111.32 * math.cos(latitudeRadians));
    return LatLng(
      _clientPosition.latitude + latitudeOffset,
      _clientPosition.longitude + longitudeOffset,
    );
  }

  List<_NearbyPro> _nearbyPros(List<Map<String, dynamic>> pros) {
    final result = <_NearbyPro>[];
    for (final pro in pros) {
      final isDemo = pro['demoProfile'] == true;
      late final LatLng point;
      if (isDemo) {
        final distance = pro['demoDistanceKm'];
        final bearing = pro['demoBearingDegrees'];
        point = _demoPointNearClient(
          distance is num ? distance.toDouble() : 10,
          bearing is num ? bearing.toDouble() : 0,
        );
      } else {
        final lat = pro['latitude'];
        final lng = pro['longitude'];
        if (lat is! num || lng is! num) continue;
        point = LatLng(lat.toDouble(), lng.toDouble());
      }
      final km = _distance.as(LengthUnit.Kilometer, _clientPosition, point);
      if (km > _nearbyRadiusKm) continue;

      result.add(
        _NearbyPro(
          pro: isDemo
              ? {
                  ...pro,
                  'location': 'Zone de test',
                  'distance': _formatDistance(km),
                }
              : pro,
          point: point,
          distanceKm: km,
        ),
      );
    }
    result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return result;
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'map_title'.tr(),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: FirebaseService().streamPros(
                            category: _selectedCategory,
                            onlyAvailable: _onlyAvailable,
                          ),
                          builder: (_, snap) {
                            final count = snap.data?.length ?? 0;
                            return Text(
                              '$count ${'map_pros_found'.tr()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleColorOf(context),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Bouton Dispo
                  GestureDetector(
                    onTap: () =>
                        setState(() => _onlyAvailable = !_onlyAvailable),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _onlyAvailable
                            ? const Color(0xFF10B981)
                            : (isDark ? AppTheme.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _onlyAvailable
                              ? const Color(0xFF10B981)
                              : AppTheme.borderColorOf(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        'available'.tr(),
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
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0D544E)
                            : (isDark ? AppTheme.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D544E)
                              : AppTheme.borderColorOf(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _catIcons[i],
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF0D544E),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cat == 'Tous' ? 'cat_all'.tr() : cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected ? Colors.white : titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Carte interactive (OpenStreetMap) ────────────────────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService().streamPros(
                  category: _selectedCategory,
                  onlyAvailable: _onlyAvailable,
                  sortBy: 'rating',
                ),
                builder: (context, snapshot) {
                  final pros = snapshot.data ?? const <Map<String, dynamic>>[];
                  final nearby = _nearbyPros(pros);

                  return Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _clientPosition,
                          initialZoom: 13.5,
                          minZoom: 3,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () {
                            _mapReady = true;
                            _centerOnClient();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.darplus.dar_plus',
                            maxNativeZoom: 19,
                          ),
                          MarkerLayer(
                            markers: [
                              // Position du client
                              Marker(
                                point: _clientPosition,
                                width: 100,
                                height: 100,
                                child: _ClientMarker(
                                  pulseAnim: _pulseAnim,
                                  label: 'map_you'.tr(),
                                  accurate: _hasRealPosition,
                                ),
                              ),
                              // Pros à proximité
                              ...nearby.map((entry) {
                                final pro = entry.pro;
                                final isAvail = pro['available'] == true;
                                final price =
                                    pro['price'] as String? ?? '35 TND/h';
                                return Marker(
                                  point: entry.point,
                                  width: 150,
                                  height: 72,
                                  child: _ProMarkerChip(
                                    pro: pro,
                                    price: price,
                                    distanceLabel: _formatDistance(
                                      entry.distanceKm,
                                    ),
                                    isAvailable: isAvail,
                                    isDark: isDark,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ServiceDetailScreen(
                                          proData: {
                                            ...pro,
                                            'distance': _formatDistance(
                                              entry.distanceKm,
                                            ),
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),

                      // Boutons Zoom + GPS
                      Positioned(
                        right: 14,
                        top: 14,
                        child: Column(
                          children: [
                            _MapButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                if (!_mapReady) return;
                                final zoom = _mapController.camera.zoom * 1.3;
                                _mapController.move(
                                  _mapController.camera.center,
                                  zoom.clamp(3, 18),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _MapButton(
                              icon: Icons.remove_rounded,
                              onTap: () {
                                if (!_mapReady) return;
                                final zoom = _mapController.camera.zoom / 1.3;
                                _mapController.move(
                                  _mapController.camera.center,
                                  zoom.clamp(3, 18),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _MapButton(
                              icon: Icons.my_location_rounded,
                              color: const Color(0xFF0D544E),
                              onTap: _locateClient,
                            ),
                          ],
                        ),
                      ),

                      // Légende + attribution
                      Positioned(
                        left: 12,
                        bottom: 128,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? AppTheme.darkCard : Colors.white)
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LegendItem(
                                color: const Color(0xFF10B981),
                                label: 'available'.tr(),
                              ),
                              const SizedBox(height: 4),
                              _LegendItem(
                                color: const Color(0xFFEF4444),
                                label: 'unavailable'.tr(),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '© OpenStreetMap',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.subtitleColorOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Indicateur chargement GPS
                      if (_isLocating)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D544E),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'GPS...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bandeau localisation refusée
                      if (!_isLocating && _locationDenied)
                        Positioned(
                          top: 14,
                          left: 14,
                          right: 70,
                          child: GestureDetector(
                            onTap: () async {
                              final permission =
                                  await Geolocator.checkPermission();
                              if (permission ==
                                  LocationPermission.deniedForever) {
                                await Geolocator.openAppSettings();
                              } else {
                                await _locateClient();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_off_rounded,
                                    size: 16,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'map_location_denied'.tr(),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Liste des pros à proximité
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _NearbyProsPanel(
                          nearby: nearby,
                          isDark: isDark,
                          formatDistance: _formatDistance,
                          onOpenPro: (pro) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailScreen(proData: pro),
                            ),
                          ),
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

  void _centerOnClient() {
    if (_mapReady) {
      _mapController.move(_clientPosition, 15);
    }
  }
}

class _NearbyPro {
  final Map<String, dynamic> pro;
  final LatLng point;
  final double distanceKm;

  const _NearbyPro({
    required this.pro,
    required this.point,
    required this.distanceKm,
  });
}

// ── Panneau « Pros à proximité » ─────────────────────────────────────────────
class _NearbyProsPanel extends StatelessWidget {
  final List<_NearbyPro> nearby;
  final bool isDark;
  final String Function(double) formatDistance;
  final void Function(Map<String, dynamic> pro) onOpenPro;

  const _NearbyProsPanel({
    required this.nearby,
    required this.isDark,
    required this.formatDistance,
    required this.onOpenPro,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.titleColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'map_nearby_title'.tr()} (${nearby.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          if (nearby.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_searching_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'map_no_nearby'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtitleColorOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nearby.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final entry = nearby[index];
                  final pro = entry.pro;
                  return GestureDetector(
                    onTap: () => onOpenPro({
                      ...pro,
                      'distance': formatDistance(entry.distanceKm),
                    }),
                    child: Container(
                      width: 230,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          ProAvatarWidget(
                            name: pro['name'] as String? ?? '',
                            photoBase64: pro['photoBase64'] as String? ?? '',
                            size: 40,
                            borderRadius: 12,
                            showVerifiedBadge: false,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pro['name'] as String? ?? ''}${pro['demoProfile'] == true ? ' • DÉMO' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.place_rounded,
                                      size: 12,
                                      color: Color(0xFF0D544E),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      formatDistance(entry.distanceKm),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D544E),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        pro['serviceType'] as String? ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppTheme.subtitleColorOf(
                                            context,
                                          ),
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
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pro Marker ────────────────────────────────────────────────────────────────
class _ProMarkerChip extends StatelessWidget {
  final Map<String, dynamic> pro;
  final String price;
  final String distanceLabel;
  final bool isAvailable;
  final bool isDark;
  final VoidCallback onTap;

  const _ProMarkerChip({
    required this.pro,
    required this.price,
    required this.distanceLabel,
    required this.isAvailable,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isAvailable
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: dotColor, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProAvatarWidget(
                      name: pro['name'] as String? ?? '',
                      photoBase64: pro['photoBase64'] as String? ?? '',
                      size: 24,
                      borderRadius: 12,
                      showVerifiedBadge: false,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.titleColor,
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(radius: 4, backgroundColor: dotColor),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0D544E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              distanceLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Client Marker ─────────────────────────────────────────────────────────────
class _ClientMarker extends StatelessWidget {
  final Animation<double> pulseAnim;
  final String label;
  final bool accurate;

  const _ClientMarker({
    required this.pulseAnim,
    required this.label,
    required this.accurate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          // Halo
          Container(
            width: 60 * pulseAnim.value,
            height: 60 * pulseAnim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D544E)
                  .withValues(alpha: 0.2 / pulseAnim.value),
            ),
          ),
          // Pin
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D544E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x440D544E),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  accurate
                      ? Icons.person_rounded
                      : Icons.location_searching_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D544E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color ?? (isDark ? AppTheme.darkCard : Colors.white),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: color != null ? Colors.white : AppTheme.titleColorOf(context),
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.subtitleColorOf(context),
          ),
        ),
      ],
    );
  }
}
