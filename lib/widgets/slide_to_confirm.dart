import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Boton deslizable para confirmar acciones criticas (p. ej. finalizar el
/// servicio) y evitar ejecutarlas por error.
class SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onConfirm;
  final Color? color;
  final bool enabled;
  final bool loading;
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.color,
    this.enabled = true,
    this.loading = false,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    const thumb = 50.0;
    final base = widget.color ?? VaiaColors.primary;
    final habilitado = widget.enabled && !widget.loading;
    return LayoutBuilder(builder: (context, c) {
      final maxDrag = (c.maxWidth - thumb - 8).clamp(1.0, double.infinity);
      final progreso = _drag * maxDrag;
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: habilitado ? base : VaiaColors.textMuted,
          borderRadius: BorderRadius.circular(28),
          boxShadow: habilitado
              ? [BoxShadow(color: base.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 5))]
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    width: thumb + 8 + progreso,
                    height: double.infinity,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Center(
              child: widget.loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: _drag > 0.05 ? 0.7 : 1),
                      ),
                    ),
            ),
            Positioned(
              left: 4 + progreso,
              top: 4,
              child: GestureDetector(
                onHorizontalDragUpdate: habilitado
                    ? (d) => setState(() => _drag = (_drag + d.delta.dx / maxDrag).clamp(0.0, 1.0))
                    : null,
                onHorizontalDragEnd: (_) {
                  if (_drag > 0.85 && habilitado) widget.onConfirm();
                  setState(() => _drag = 0);
                },
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    widget.loading ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
                    color: base,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
