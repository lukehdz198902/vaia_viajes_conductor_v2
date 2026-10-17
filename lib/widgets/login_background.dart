import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fondo animado para la pantalla de login: rutas suaves con "unidades"
/// viajando por ellas y particulas flotando. La opacidad es baja para no
/// afectar la legibilidad del formulario.
class LoginBackground extends StatefulWidget {
  final Color accent;
  final Color accent2;
  const LoginBackground({super.key, required this.accent, required this.accent2});

  @override
  State<LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<LoginBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _RutasPainter(_c.value, widget.accent, widget.accent2),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RutasPainter extends CustomPainter {
  final double t;
  final Color c1;
  final Color c2;
  _RutasPainter(this.t, this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rutas = <List<Offset>>[
      [Offset(-0.1 * w, 0.82 * h), Offset(0.30 * w, 0.52 * h), Offset(0.55 * w, 0.90 * h), Offset(1.10 * w, 0.48 * h)],
      [Offset(-0.1 * w, 0.30 * h), Offset(0.40 * w, 0.10 * h), Offset(0.60 * w, 0.46 * h), Offset(1.10 * w, 0.16 * h)],
      [Offset(-0.1 * w, 0.58 * h), Offset(0.50 * w, 0.74 * h), Offset(0.70 * w, 0.28 * h), Offset(1.10 * w, 0.62 * h)],
    ];

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < rutas.length; i++) {
      final r = rutas[i];
      final p = Path()
        ..moveTo(r[0].dx, r[0].dy)
        ..cubicTo(r[1].dx, r[1].dy, r[2].dx, r[2].dy, r[3].dx, r[3].dy);
      final color = i.isEven ? c1 : c2;
      linePaint.color = color.withValues(alpha: 0.10);
      canvas.drawPath(p, linePaint);

      final metric = p.computeMetrics().first;
      for (var k = 0; k < 3; k++) {
        final prog = (t + k / 3 + i * 0.15) % 1.0;
        final pos = metric.getTangentForOffset(metric.length * prog)?.position;
        if (pos == null) continue;
        canvas.drawCircle(pos, 7, Paint()..color = color.withValues(alpha: 0.16));
        canvas.drawCircle(pos, 3, Paint()..color = color.withValues(alpha: 0.45));
      }
    }

    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final bx = rnd.nextDouble();
      final by = rnd.nextDouble();
      final radius = 1.5 + rnd.nextDouble() * 3;
      final dx = math.sin((t * 2 * math.pi) + i) * 12;
      final dy = -((t + bx) % 1.0) * 40 + 20;
      canvas.drawCircle(
        Offset(bx * w + dx, by * h + dy),
        radius,
        Paint()..color = (i.isEven ? c1 : c2).withValues(alpha: 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RutasPainter old) => old.t != t;
}
