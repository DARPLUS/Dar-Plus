import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'catalog_search_screen.dart';
import '../services/gemini_service.dart';

class EstimateScreen extends StatefulWidget {
  const EstimateScreen({super.key, this.initialServiceType});

  final String? initialServiceType;

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  static const _ink = Color(0xFF202338);
  static const _muted = Color(0xFF85869A);
  static const _teal = Color(0xFF0D7774);
  static const _surface = Color(0xFFFAF8F6);

  static const _services = <_EstimateService>[
    _EstimateService(
      'plumbing',
      'estimate_service_plumbing',
      Icons.plumbing_rounded,
      40,
      120,
    ),
    _EstimateService(
      'cleaning',
      'estimate_service_cleaning',
      Icons.cleaning_services_rounded,
      25,
      60,
    ),
    _EstimateService(
      'sofa',
      'estimate_service_sofa',
      Icons.weekend_rounded,
      30,
      90,
    ),
    _EstimateService(
      'painting',
      'estimate_service_painting',
      Icons.format_paint_rounded,
      40,
      120,
    ),
  ];

  static const _zones = <_EstimateZone>[
    _EstimateZone('grand_tunis', 'estimate_zone_grand_tunis', 1.0),
    _EstimateZone('banlieue', 'estimate_zone_banlieue', 1.1),
    _EstimateZone('sfax', 'estimate_zone_sfax', 1.2),
    _EstimateZone('sousse', 'estimate_zone_sousse', 1.2),
  ];

  static const _urgencies = <_EstimateUrgency>[
    _EstimateUrgency(
      'normal',
      'estimate_urgency_normal',
      Icons.event_available_rounded,
      1.0,
      Color(0xFF12B76A),
    ),
    _EstimateUrgency(
      'urgent',
      'estimate_urgency_urgent',
      Icons.bolt_rounded,
      1.3,
      Color(0xFFF79009),
    ),
    _EstimateUrgency(
      'super_urgent',
      'estimate_urgency_super',
      Icons.emergency_rounded,
      1.6,
      Color(0xFFEF4444),
    ),
  ];

  String _selectedService = 'plumbing';
  String _selectedZone = 'grand_tunis';
  int _selectedUrgency = 0;
  int _hours = 2;
  String? _aiPriceEstimate;
  String? _estimateError;
  bool _isEstimating = false;

  @override
  void initState() {
    super.initState();
    final service = (widget.initialServiceType ?? '')
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ç', 'c');
    if (service.contains('plomb') || service.contains('plumb')) {
      _selectedService = 'plumbing';
    } else if (service.contains('menage') ||
        service.contains('clean') ||
        service.contains('nettoy')) {
      _selectedService = 'cleaning';
    } else if (service.contains('canape') || service.contains('sofa')) {
      _selectedService = 'sofa';
    } else if (service.contains('peint') || service.contains('paint')) {
      _selectedService = 'painting';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _estimateWithAi();
    });
  }

  _EstimateService get _service =>
      _services.firstWhere((item) => item.id == _selectedService);
  _EstimateZone get _zone =>
      _zones.firstWhere((item) => item.id == _selectedZone);
  _EstimateUrgency get _urgency => _urgencies[_selectedUrgency];

  Future<void> _estimateWithAi() async {
    setState(() {
      _isEstimating = true;
      _estimateError = null;
      _aiPriceEstimate = null;
    });
    try {
      final result = await GeminiService().estimatePrice(
        service: _service.titleKey.tr(),
        hours: _hours,
        urgency: _urgency.titleKey.tr(),
        area: _zone.titleKey.tr(),
        hourlyMinimum: _service.minimum,
        hourlyMaximum: _service.maximum,
        areaFactor: _zone.multiplier,
        urgencyFactor: _urgency.multiplier,
        languageCode: context.locale.languageCode,
      );
      if (!mounted) return;
      setState(() => _aiPriceEstimate = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _estimateError = 'estimate_ai_error'.tr());
    } finally {
      if (mounted) setState(() => _isEstimating = false);
    }
  }

  Future<void> _reserve() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CatalogSearchScreen(initialCategory: _service.catalogCategory),
      ),
    );
    if (result == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF101820) : _surface;
    final cardColor = isDark ? const Color(0xFF1D2935) : Colors.white;
    final ink = isDark ? Colors.white : _ink;
    final muted = isDark ? const Color(0xFFA7B0BC) : _muted;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: IconButton.filledTonal(
            tooltip: 'estimate_back'.tr(),
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF28343E)
                  : const Color(0xFFF0ECE8),
              foregroundColor: ink,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'estimate_title'.tr(),
              style: TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'estimate_subtitle'.tr(),
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white12 : const Color(0xFFEAE5E0),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
              children: [
                _buildEstimateCard(isDark),
                const SizedBox(height: 20),
                _buildSectionTitle(
                  'estimate_service_heading'.tr(),
                  Icons.handyman_rounded,
                  ink,
                ),
                const SizedBox(height: 9),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _services
                        .map(
                          (service) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: _buildServiceChip(service, isDark),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(
                  'estimate_hours_heading'.tr(),
                  Icons.timer_outlined,
                  ink,
                ),
                const SizedBox(height: 9),
                _buildHoursControl(cardColor, isDark, ink, muted),
                const SizedBox(height: 20),
                _buildSectionTitle(
                  'estimate_urgency_heading'.tr(),
                  Icons.bolt_rounded,
                  ink,
                ),
                const SizedBox(height: 9),
                Row(
                  children: _urgencies
                      .asMap()
                      .entries
                      .map(
                        (entry) => Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: entry.key == _urgencies.length - 1 ? 0 : 8,
                            ),
                            child: _buildUrgencyCard(
                              entry.key,
                              isDark,
                              cardColor,
                              ink,
                              muted,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(
                  'estimate_zone_heading'.tr(),
                  Icons.location_on_outlined,
                  ink,
                ),
                const SizedBox(height: 9),
                _buildZones(isDark, cardColor, ink, muted),
                const SizedBox(height: 20),
                if (_aiPriceEstimate != null)
                  _buildCalculationCard(isDark, cardColor, ink, muted),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: muted, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'estimate_disclaimer'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _reserve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'estimate_reserve'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F7774), Color(0xFF12A99C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            'estimate_indicative'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          if (_isEstimating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_aiPriceEstimate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _aiPriceEstimate!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            )
          else ...[
            Text(
              'estimate_ai_idle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _estimateWithAi,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('estimate_ai_calculate'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
            ),
          ],
          if (_estimateError != null) ...[
            const SizedBox(height: 6),
            Text(
              _estimateError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            TextButton(
              onPressed: _estimateWithAi,
              child: Text('estimate_ai_retry'.tr()),
            ),
          ],
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: [
              _multiplierPill(
                'estimate_quantity_short'.tr(),
                '×${_hours.toStringAsFixed(1)}',
              ),
              _multiplierPill(
                'estimate_zone_short'.tr(),
                '×${_zone.multiplier.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _multiplierPill(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildSectionTitle(String title, IconData icon, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 7),
      Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _buildServiceChip(_EstimateService service, bool isDark) {
    final selected = _selectedService == service.id;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => setState(() {
        _selectedService = service.id;
        _aiPriceEstimate = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2297E5)
              : (isDark ? const Color(0xFF1D2935) : Colors.white),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? const Color(0xFF2297E5)
                : (isDark ? Colors.white24 : const Color(0xFFE4DDD7)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              service.icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFFED795E),
            ),
            const SizedBox(width: 5),
            Text(
              service.titleKey.tr(),
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : _muted),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursControl(
    Color cardColor,
    bool isDark,
    Color ink,
    Color muted,
  ) => Container(
    height: 88,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFE4DDD7),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepButton(Icons.remove_rounded, () {
          if (_hours > 1) {
            setState(() {
              _hours--;
              _aiPriceEstimate = null;
            });
          }
        }, isDark),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_hours',
              style: const TextStyle(
                color: _teal,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'estimate_hours_unit'.tr(),
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        _stepButton(
          Icons.add_rounded,
          () {
            if (_hours < 12) {
              setState(() {
                _hours++;
                _aiPriceEstimate = null;
              });
            }
          },
          isDark,
          filled: true,
        ),
      ],
    ),
  );

  Widget _stepButton(
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool filled = false,
  }) => IconButton.filled(
    onPressed: onTap,
    style: IconButton.styleFrom(
      backgroundColor: filled
          ? _teal
          : (isDark ? const Color(0xFF28343E) : const Color(0xFFF1EEEA)),
      foregroundColor: filled ? Colors.white : const Color(0xFF24283A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(icon, size: 20),
  );

  Widget _buildUrgencyCard(
    int index,
    bool isDark,
    Color cardColor,
    Color ink,
    Color muted,
  ) {
    final item = _urgencies[index];
    final selected = index == _selectedUrgency;
    return InkWell(
      onTap: () => setState(() {
        _selectedUrgency = index;
        _aiPriceEstimate = null;
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 96,
        decoration: BoxDecoration(
          color: selected ? item.color.withValues(alpha: 0.1) : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? item.color
                : (isDark ? Colors.white24 : const Color(0xFFE4DDD7)),
            width: selected ? 1.8 : 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 20),
            const SizedBox(height: 4),
            Text(
              item.titleKey.tr(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? item.color : muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '×${item.multiplier.toStringAsFixed(1)}',
              style: TextStyle(
                color: selected ? item.color : muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZones(bool isDark, Color cardColor, Color ink, Color muted) {
    return Column(
      children: [
        Row(
          children: [
            for (final zone in _zones.take(2))
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: zone.id == _zones[0].id ? 8 : 0,
                  ),
                  child: _zoneButton(zone, isDark, cardColor, muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final zone in _zones.skip(2))
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: zone.id == _zones[2].id ? 8 : 0,
                  ),
                  child: _zoneButton(zone, isDark, cardColor, muted),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _zoneButton(
    _EstimateZone zone,
    bool isDark,
    Color cardColor,
    Color muted,
  ) {
    final selected = _selectedZone == zone.id;
    return SizedBox(
      height: 43,
      child: OutlinedButton(
        onPressed: () => setState(() {
          _selectedZone = zone.id;
          _aiPriceEstimate = null;
        }),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? _teal : cardColor,
          foregroundColor: selected ? Colors.white : muted,
          side: BorderSide(
            color: selected
                ? _teal
                : (isDark ? Colors.white24 : const Color(0xFFE4DDD7)),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          zone.titleKey.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCalculationCard(
    bool isDark,
    Color cardColor,
    Color ink,
    Color muted,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFE4DDD7),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calculate_outlined, size: 16),
            const SizedBox(width: 7),
            Text(
              'estimate_calculation_title'.tr(),
              style: TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _calculationRow(
          'estimate_base_price'.tr(),
          '${_service.minimum}–${_service.maximum} TND',
          ink,
          muted,
        ),
        const SizedBox(height: 9),
        _calculationRow(
          'estimate_quantity'.tr(args: ['$_hours']),
          '×$_hours',
          ink,
          muted,
        ),
        const SizedBox(height: 9),
        _calculationRow(
          'estimate_zone_factor'.tr(),
          '×${_zone.multiplier.toStringAsFixed(2)}',
          ink,
          muted,
        ),
        const SizedBox(height: 9),
        _calculationRow(
          'estimate_urgency_factor'.tr(),
          '×${_urgency.multiplier.toStringAsFixed(1)}',
          ink,
          muted,
        ),
      ],
    ),
  );

  Widget _calculationRow(String label, String amount, Color ink, Color muted) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: muted, fontSize: 11.5)),
          ),
          Text(
            amount,
            style: TextStyle(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _EstimateService {
  final String id;
  final String titleKey;
  final IconData icon;
  final int minimum;
  final int maximum;

  const _EstimateService(
    this.id,
    this.titleKey,
    this.icon,
    this.minimum,
    this.maximum,
  );

  String get catalogCategory => switch (id) {
    'plumbing' => 'Plomberie',
    'cleaning' => 'Ménage',
    'sofa' => 'Nettoyage Canapé',
    _ => 'Peinture',
  };
}

class _EstimateZone {
  final String id;
  final String titleKey;
  final double multiplier;
  const _EstimateZone(this.id, this.titleKey, this.multiplier);
}

class _EstimateUrgency {
  final String id;
  final String titleKey;
  final IconData icon;
  final double multiplier;
  final Color color;
  const _EstimateUrgency(
    this.id,
    this.titleKey,
    this.icon,
    this.multiplier,
    this.color,
  );
}
