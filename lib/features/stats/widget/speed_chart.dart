import 'package:flutter/material.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/stats/notifier/speed_history_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpeedChart extends ConsumerWidget {
  const SpeedChart({super.key, this.height = 44});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(speedHistoryNotifierProvider);
    if (history.length < 2) return SizedBox(height: height);

    return SizedBox(
      height: height,
      child: ClipRect(
        child: CustomPaint(
          painter: _SpeedChartPainter(
            history: history,
            uplinkColor: MelaColors.secondary,
            downlinkColor: MelaColors.connected,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  _SpeedChartPainter({
    required this.history,
    required this.uplinkColor,
    required this.downlinkColor,
  });

  final List<SpeedPoint> history;
  final Color uplinkColor;
  final Color downlinkColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final maxUp = history.fold(0.0, (m, e) => e.uplink > m ? e.uplink : m);
    final maxDown = history.fold(0.0, (m, e) => e.downlink > m ? e.downlink : m);
    final maxVal = [maxUp, maxDown, 1.0].fold(0.0, (a, b) => a > b ? a : b);

    _drawCurve(canvas, size, history.map((e) => e.downlink).toList(), maxVal, downlinkColor);
    _drawCurve(canvas, size, history.map((e) => e.uplink).toList(), maxVal, uplinkColor);
  }

  void _drawCurve(Canvas canvas, Size size, List<double> values, double maxVal, Color color) {
    if (values.length < 2) return;

    final step = size.width / (values.length - 1);

    Offset point(int i) => Offset(
      i * step,
      size.height - (values[i] / maxVal) * size.height * 0.9,
    );

    final linePath = Path();
    final fillPath = Path();

    final p0 = point(0);
    linePath.moveTo(p0.dx, p0.dy);
    fillPath.moveTo(p0.dx, size.height);
    fillPath.lineTo(p0.dx, p0.dy);

    for (var i = 1; i < values.length; i++) {
      final prev = point(i - 1);
      final curr = point(i);
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }

    final last = point(values.length - 1);
    fillPath.lineTo(last.dx, size.height);
    fillPath.close();

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_SpeedChartPainter old) => old.history != history;
}
