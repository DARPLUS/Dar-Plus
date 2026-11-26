import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/firebase_service.dart';

class AvailabilityManagementScreen extends StatefulWidget {
  final VoidCallback onClose;

  const AvailabilityManagementScreen({super.key, required this.onClose});

  @override
  State<AvailabilityManagementScreen> createState() =>
      _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState
    extends State<AvailabilityManagementScreen> {
  static const _teal = Color(0xFF0D706D);
  static const _orange = Color(0xFFEF854D);
  static const _red = Color(0xFFEF5146);
  static const _blue = Color(0xFF48A9D6);
  static const _weekDayKeys = [
    'weekday_mon_short',
    'weekday_tue_short',
    'weekday_wed_short',
    'weekday_thu_short',
    'weekday_fri_short',
    'weekday_sat_short',
    'weekday_sun_short',
  ];
  static const _monthKeys = [
    'month_jan_short',
    'month_feb_short',
    'month_mar_short',
    'month_apr_short',
    'month_may_short',
    'month_jun_short',
    'month_jul_short',
    'month_aug_short',
    'month_sep_short',
    'month_oct_short',
    'month_nov_short',
    'month_dec_short',
  ];

  DateTime _weekStart = _monday(DateTime.now());
  DateTime? _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  int _startHour = 9;
  int _endHour = 17;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Set<String> _unavailableSlots = {};
  Set<String> _reservedSlots = {};
  StreamSubscription<List<Map<String, dynamic>>>? _reservedSubscription;

  static DateTime _monday(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final data = await FirebaseService().getCurrentProAvailabilitySettings();
      if (!mounted) return;
      setState(() {
        final start = data['workStartMinutes'];
        final end = data['workEndMinutes'];
        if (start is num)
          _startHour = (start.toInt() ~/ 60).clamp(0, 22).toInt();
        if (end is num) _endHour = (end.toInt() ~/ 60).clamp(1, 23).toInt();
        if (_endHour <= _startHour)
          _endHour = (_startHour + 1).clamp(1, 23).toInt();
        _unavailableSlots = (data['unavailableSlots'] as List? ?? const [])
            .map((value) => value.toString())
            .toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
    _listenReservedSlots();
  }

  void _listenReservedSlots() {
    _reservedSubscription = FirebaseService()
        .streamCurrentProReservedSlots()
        .listen(
          (slots) {
            if (!mounted) return;
            setState(() {
              _reservedSlots = slots.map((slot) {
                final date = slot['dateKey']?.toString() ?? '';
                final time = slot['time']?.toString() ?? '';
                return '${date}_${time.replaceAll(':', '')}';
              }).toSet();
            });
          },
          onError: (Object error) {
            if (mounted) setState(() => _error = error.toString());
          },
        );
  }

  @override
  void dispose() {
    _reservedSubscription?.cancel();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _slotId(DateTime date, int hour) =>
      '${_dateKey(date)}_${hour.toString().padLeft(2, '0')}00';

  String _blockedKey(DateTime date, int hour) =>
      '${_dateKey(date)}_${_timeLabel(hour)}';

  String _timeLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  Future<void> _saveAvailability() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseService().saveCurrentProAvailabilitySettings(
        workStartMinutes: _startHour * 60,
        workEndMinutes: _endHour * 60,
        unavailableSlots: _unavailableSlots.toList()..sort(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('availability_saved'.tr())));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changeHour({required bool isStart, required int delta}) {
    setState(() {
      if (isStart) {
        final next = (_startHour + delta).clamp(0, 22).toInt();
        _startHour = next >= _endHour ? _endHour - 1 : next;
      } else {
        final next = (_endHour + delta).clamp(1, 23).toInt();
        _endHour = next <= _startHour ? _startHour + 1 : next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F4);
    final card = dark ? const Color(0xFF1E293B) : Colors.white;
    final primary = dark ? Colors.white : const Color(0xFF172033);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF7A8194);
    final border = dark ? const Color(0xFF334155) : const Color(0xFFE3DED8);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: primary,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'pro_profile_availability'.tr(),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildLegend(dark),
          Divider(height: 1, color: border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : _error != null && _unavailableSlots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'availability_load_error'.tr(
                          namedArgs: {'error': _error!},
                        ),
                        style: TextStyle(color: primary),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    children: [
                      _buildWorkHours(card, primary, secondary, border),
                      const SizedBox(height: 20),
                      _buildWeekHeader(primary, secondary),
                      const SizedBox(height: 12),
                      _buildCalendar(primary, secondary),
                      const SizedBox(height: 16),
                      if (_selectedDay != null)
                        OutlinedButton.icon(
                          onPressed: _clearSelectedDay,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: Text(
                            'availability_clear_day'.tr(
                              namedArgs: {
                                'day': _dayLabel(_selectedDay!, context),
                              },
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: secondary,
                            backgroundColor: dark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF0EDE9),
                            side: BorderSide(color: border),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: _red, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _loading || _saving ? null : _saveAvailability,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'availability_save'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool dark) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(
      children: [
        _LegendPill(
          label: 'availability_free'.tr(),
          color: const Color(0xFF20B66A),
          background: dark ? const Color(0xFF123B2B) : const Color(0xFFE4F7EC),
        ),
        const SizedBox(width: 9),
        _LegendPill(
          label: 'availability_occupied'.tr(),
          color: _red,
          background: dark ? const Color(0xFF4C1D24) : const Color(0xFFFFE8E4),
        ),
        const Spacer(),
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'availability_reserved'.tr(),
              style: TextStyle(
                color: dark ? const Color(0xFF94A3B8) : const Color(0xFF70798B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildWorkHours(
    Color card,
    Color primary,
    Color secondary,
    Color border,
  ) => Container(
    padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        _buildHourControl(
          'availability_start'.tr(),
          _startHour,
          isStart: true,
          primary: primary,
          secondary: secondary,
        ),
        const SizedBox(height: 4),
        _buildHourControl(
          'availability_end'.tr(),
          _endHour,
          isStart: false,
          primary: primary,
          secondary: secondary,
        ),
      ],
    ),
  );

  Widget _buildHourControl(
    String label,
    int hour, {
    required bool isStart,
    required Color primary,
    required Color secondary,
  }) => Row(
    children: [
      Expanded(
        child: Text(label, style: TextStyle(color: secondary, fontSize: 14)),
      ),
      _RoundAction(
        icon: Icons.remove_rounded,
        onTap: () => _changeHour(isStart: isStart, delta: -1),
      ),
      const SizedBox(width: 12),
      Text(
        _timeLabel(hour),
        style: const TextStyle(
          color: _teal,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 12),
      _RoundAction(
        icon: Icons.add_rounded,
        onTap: () => _changeHour(isStart: isStart, delta: 1),
        filled: true,
      ),
    ],
  );

  Widget _buildWeekHeader(Color primary, Color secondary) {
    final end = _weekStart.add(const Duration(days: 6));
    final month = _monthKeys[_weekStart.month - 1].tr();
    final dateLabel = _weekStart.month == end.month
        ? '${_weekStart.day}–${end.day} $month'
        : '${_weekStart.day} $month – ${end.day} ${_monthKeys[end.month - 1].tr()}';
    return Row(
      children: [
        const Icon(Icons.calendar_month_rounded, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'availability_week_of'.tr(namedArgs: {'date': dateLabel}),
            style: TextStyle(
              color: primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _RoundAction(
          icon: Icons.chevron_left_rounded,
          onTap: () => _moveWeek(-1),
        ),
        const SizedBox(width: 6),
        _RoundAction(
          icon: Icons.chevron_right_rounded,
          onTap: () => _moveWeek(1),
        ),
      ],
    );
  }

  void _moveWeek(int delta) => setState(() {
    _weekStart = _weekStart.add(Duration(days: delta * 7));
    final selected = _selectedDay;
    if (selected == null ||
        selected.isBefore(_weekStart) ||
        !selected.isBefore(_weekStart.add(const Duration(days: 7)))) {
      _selectedDay = _weekStart;
    }
  });

  Widget _buildCalendar(Color primary, Color secondary) {
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final rows = List.generate(
      _endHour - _startHour + 1,
      (index) => _startHour + index,
    );
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 43),
            ...List.generate(7, (index) {
              final day = days[index];
              final selected =
                  _selectedDay != null && _sameDay(day, _selectedDay!);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: SizedBox(
                    height: 54,
                    child: Column(
                      children: [
                        Text(
                          _weekDayKeys[index].tr(),
                          style: TextStyle(
                            color: secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 31,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? _teal : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: selected ? Colors.white : primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        ...rows.map(
          (hour) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 43,
                  child: Text(
                    _timeLabel(hour),
                    style: TextStyle(color: secondary, fontSize: 11),
                  ),
                ),
                ...days.map(
                  (day) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildSlot(day, hour),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlot(DateTime day, int hour) {
    final id = _slotId(day, hour);
    final reserved = _reservedSlots.contains(id);
    final occupied = _unavailableSlots.contains(_blockedKey(day, hour));
    final selected = _selectedDay != null && _sameDay(day, _selectedDay!);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = reserved
        ? _blue
        : occupied
        ? _red
        : (dark ? const Color(0xFF475569) : const Color(0xFFEAE8E5));
    final background = reserved
        ? (dark ? const Color(0xFF123B54) : const Color(0xFFDDF2FB))
        : occupied
        ? (dark ? const Color(0xFF4C1D24) : const Color(0xFFFFE8E4))
        : (dark ? const Color(0xFF334155) : const Color(0xFFF1EFEC));
    return GestureDetector(
      onTap: reserved
          ? null
          : () => setState(() {
              if (occupied) {
                _unavailableSlots.remove(_blockedKey(day, hour));
              } else {
                _unavailableSlots.add(_blockedKey(day, hour));
              }
            }),
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: reserved || occupied && selected ? color : background,
          ),
        ),
      ),
    );
  }

  void _clearSelectedDay() {
    final day = _selectedDay;
    if (day == null) return;
    setState(() {
      final prefix = '${_dateKey(day)}_';
      final blockedForDay = _unavailableSlots
          .where((slot) => slot.startsWith(prefix))
          .toList();
      for (final slot in blockedForDay) {
        _unavailableSlots.remove(slot);
      }
    });
  }

  String _dayLabel(DateTime day, BuildContext context) =>
      '${_weekDayKeys[day.weekday - 1].tr()} ${day.day}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF334155) : const Color(0xFFF0EDE9);
    final foreground = dark ? Colors.white : const Color(0xFF172033);
    return Material(
      color: filled ? const Color(0xFF0D706D) : surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : foreground,
          ),
        ),
      ),
    );
  }
}
