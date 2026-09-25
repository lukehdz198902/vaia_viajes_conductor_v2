import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Linea de tiempo animada del proceso de un servicio (conductor).
class StatusTimeline extends StatefulWidget {
  final int pasoActual;
  final bool cancelado;
  final Color colorActivo;
  final Color colorCompletado;
  final List<String> etiquetas;
  final List<IconData> iconos;
  final bool compacto;

  const StatusTimeline({
    super.key,
    required this.pasoActual,
    this.cancelado = false,
    this.colorActivo = VaiaColors.primary,
    this.colorCompletado = VaiaColors.success,
    this.etiquetas = const ['Asignado', 'En camino', 'En el origen', 'En viaje', 'Finalizado'],
    this.iconos = const [
      Icons.assignment_turned_in_rounded,
      Icons.directions_car_filled_rounded,
      Icons.person_pin_circle_rounded,
      Icons.navigation_rounded,
      Icons.flag_rounded,
    ],
    this.compacto = false,
  });

  @override
  State<StatusTimeline> createState() => _StatusTimelineState();
}

class _StatusTimelineState extends State<StatusTimeline> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.pasoActual >= 0 && !widget.cancelado) _pulso.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusTimeline old) {
    super.didUpdateWidget(old);
    if (widget.cancelado || widget.pasoActual < 0) {
      _pulso.stop();
    } else if (!_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paso = widget.cancelado ? -1 : widget.pasoActual;
    final n = widget.etiquetas.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++) ...[
          Expanded(child: _Paso(
            etiqueta: widget.etiquetas[i],
            icono: widget.iconos[i],
            completado: i < paso,
            actual: i == paso && paso >= 0,
            cancelado: widget.cancelado && i == (widget.pasoActual < 0 ? 0 : widget.pasoActual),
            colorActivo: widget.colorActivo,
            colorCompletado: widget.colorCompletado,
            pulso: _pulso,
            compacto: widget.compacto,
          )),
          if (i < n - 1)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: widget.compacto ? 13 : 17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < paso ? widget.colorCompletado : VaiaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final bool completado;
  final bool actual;
  final bool cancelado;
  final Color colorActivo;
  final Color colorCompletado;
  final Animation<double> pulso;
  final bool compacto;

  const _Paso({
    required this.etiqueta,
    required this.icono,
    required this.completado,
    required this.actual,
    required this.cancelado,
    required this.colorActivo,
    required this.colorCompletado,
    required this.pulso,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final size = compacto ? 26.0 : 34.0;
    final iconSize = compacto ? 14.0 : 18.0;

    Color fondo;
    Color borde;
    Color iconColor;
    if (cancelado) {
      fondo = VaiaColors.danger;
      borde = VaiaColors.danger;
      iconColor = Colors.white;
    } else if (completado) {
      fondo = colorCompletado;
      borde = colorCompletado;
      iconColor = Colors.white;
    } else if (actual) {
      fondo = colorActivo.withValues(alpha: 0.16);
      borde = colorActivo;
      iconColor = colorActivo;
    } else {
      fondo = VaiaColors.surface;
      borde = VaiaColors.border;
      iconColor = VaiaColors.textMuted;
    }

    final circulo = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fondo,
        shape: BoxShape.circle,
        border: Border.all(color: borde, width: 2),
        boxShadow: actual ? [BoxShadow(color: colorActivo.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1)] : null,
      ),
      child: Icon(
        cancelado ? Icons.close_rounded : (completado ? Icons.check_rounded : icono),
        size: iconSize,
        color: cancelado ? Colors.white : iconColor,
      ),
    );

    return Column(
      children: [
        actual
            ? AnimatedBuilder(
                animation: pulso,
                builder: (_, child) => Transform.scale(scale: 1 + (pulso.value * 0.12), child: child),
                child: circulo,
              )
            : circulo,
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: compacto ? 9.5 : 10.5,
            height: 1.1,
            fontWeight: actual || completado ? FontWeight.w700 : FontWeight.w500,
            color: cancelado
                ? VaiaColors.danger
                : completado
                    ? VaiaColors.textPrimary
                    : actual
                        ? colorActivo
                        : VaiaColors.textMuted,
          ),
          textAlign: TextAlign.center,
          child: Text(etiqueta, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
