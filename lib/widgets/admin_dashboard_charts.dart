import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Graphique spline d'activité de la plateforme (Revenus vs Interventions)
class PlatformActivityChart extends StatelessWidget {
  final List<double> revenues;
  final List<double> interventions;
  final List<String> xLabels;
  final bool isDark;
  final double height;

  const PlatformActivityChart({
    super.key,
    this.revenues = const [10.5, 15.0, 17.5, 25.0, 26.5, 30.0, 31.5],
    this.interventions = const [5.0, 7.5, 7.0, 11.0, 12.5, 11.0, 16.0],
    this.xLabels = const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    this.isDark = false,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PlatformActivityPainter(
          revenues: revenues,
          interventions: interventions,
          xLabels: xLabels,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _PlatformActivityPainter extends CustomPainter {
  final List<double> revenues;
  final List<double> interventions;
  final List<String> xLabels;
  final bool isDark;

  _PlatformActivityPainter({
    required this.revenues,
    required this.interventions,
    required this.xLabels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 36.0;
    const double rightPadding = 12.0;
    const double topPadding = 16.0;
    const double bottomPadding = 26.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Grid lines & Y labels (0 to 40K)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF64748B)).withValues(
        alpha: 0.12,
      )
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    const ySteps = [40, 30, 20, 10, 0];
    for (int i = 0; i < ySteps.length; i++) {
      final y = topPadding + (i / (ySteps.length - 1)) * chartHeight;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final label = ySteps[i] == 0 ? '0' : '${ySteps[i]}K';
      final span = TextSpan(text: label, style: textStyle);
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // X Labels
    final int count = xLabels.length;
    final double stepX = chartWidth / (count - 1);

    for (int i = 0; i < count; i++) {
      final x = leftPadding + i * stepX;
      final span = TextSpan(text: xLabels[i], style: textStyle);
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, size.height - bottomPadding + 6),
      );
    }

    // Helper to get coordinates
    const double maxY = 40.0;
    Offset getPoint(int index, double value) {
      final x = leftPadding + index * stepX;
      final clampedVal = value.clamp(0.0, maxY);
      final y = topPadding + chartHeight * (1.0 - (clampedVal / maxY));
      return Offset(x, y);
    }

    // Path for Revenus (Smooth spline with gradient fill)
    final List<Offset> revPoints = [];
    for (int i = 0; i < revenues.length; i++) {
      revPoints.add(getPoint(i, revenues[i]));
    }

    if (revPoints.isNotEmpty) {
      final path = Path();
      path.moveTo(revPoints[0].dx, revPoints[0].dy);

      for (int i = 0; i < revPoints.length - 1; i++) {
        final p0 = i > 0 ? revPoints[i - 1] : revPoints[i];
        final p1 = revPoints[i];
        final p2 = revPoints[i + 1];
        final p3 = i < revPoints.length - 2 ? revPoints[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 5.5;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 5.5;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 5.5;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 5.5;

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }

      // Gradient Fill
      final fillPath = Path.from(path);
      fillPath.lineTo(revPoints.last.dx, topPadding + chartHeight);
      fillPath.lineTo(revPoints.first.dx, topPadding + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D544E).withValues(alpha: isDark ? 0.35 : 0.20),
            const Color(0xFF0D544E).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      // Line Stroke
      final linePaint = Paint()
        ..color = const Color(0xFF0D544E)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, linePaint);
    }

    // Path for Interventions (Orange dashed curve)
    final List<Offset> intPoints = [];
    for (int i = 0; i < interventions.length; i++) {
      intPoints.add(getPoint(i, interventions[i]));
    }

    if (intPoints.isNotEmpty) {
      final intPath = Path();
      intPath.moveTo(intPoints[0].dx, intPoints[0].dy);

      for (int i = 0; i < intPoints.length - 1; i++) {
        final p0 = i > 0 ? intPoints[i - 1] : intPoints[i];
        final p1 = intPoints[i];
        final p2 = intPoints[i + 1];
        final p3 = i < intPoints.length - 2 ? intPoints[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 5.5;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 5.5;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 5.5;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 5.5;

        intPath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }

      // Draw dashed path
      final orangeLinePaint = Paint()
        ..color = const Color(0xFFDE6D1B)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      _drawDashedPath(canvas, intPath, orangeLinePaint, 5.0, 4.0);
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlatformActivityPainter oldDelegate) => true;
}

/// Modèle pour une tranche du donut de répartition des services
class ServiceSlice {
  final String label;
  final double percentage; // e.g. 32
  final Color color;

  const ServiceSlice({
    required this.label,
    required this.percentage,
    required this.color,
  });
}

/// Donut chart élégant avec trou central et statistiques
class ServicesDonutChart extends StatelessWidget {
  final List<ServiceSlice> slices;
  final String totalCount;
  final String totalLabel;
  final bool isDark;
  final double size;

  const ServicesDonutChart({
    super.key,
    required this.slices,
    this.totalCount = '3 672',
    this.totalLabel = 'services',
    this.isDark = false,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ServicesDonutPainter(slices: slices, isDark: isDark),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalCount,
                style: TextStyle(
                  fontSize: size * 0.14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totalLabel,
                style: TextStyle(
                  fontSize: size * 0.08,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServicesDonutPainter extends CustomPainter {
  final List<ServiceSlice> slices;
  final bool isDark;

  _ServicesDonutPainter({required this.slices, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;
    const gapAngle = 0.04; // small gap between arcs

    for (final slice in slices) {
      final sweepAngle = (slice.percentage / 100.0) * (2 * math.pi) - gapAngle;
      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + gapAngle / 2,
          sweepAngle,
          false,
          paint,
        );
      }
      startAngle += (slice.percentage / 100.0) * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _ServicesDonutPainter oldDelegate) => true;
}
