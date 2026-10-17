import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Linea de tiempo vertical de la ruta (solo lectura): destino arriba,
/// paradas al centro y origen abajo, con un riel animado. Reutilizable en
/// historial, detalle de viaje y servicio en curso.
class RutaTimeline extends StatefulWidget {
  final String origen;
  final String destino;
  final List<String> paradas;
  const RutaTimeline({super.key, required this.origen, required this.destino, this.paradas = const []});

  @override
  State<RutaTimeline> createState() => _RutaTimelineState();
}

class _RutaTimelineState extends State<RutaTimeline> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodos = <Widget>[
      _nodo('Destino', widget.destino, VaiaColors.danger, Icons.flag_rounded),
      for (var i = widget.paradas.length - 1; i >= 0; i--)
        _nodo('Parada ${i + 1}', widget.paradas[i], VaiaColors.accent, Icons.circle, numero: i + 1),
      _nodo('Origen', widget.origen, VaiaColors.primary, Icons.my_location_rounded),
    ];
    return Stack(
      children: [
        Positioned(left: 10, top: 12, bottom: 12, width: 3, child: _riel()),
        Column(children: nodos),
      ],
    );
  }

  Widget _riel() {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [VaiaColors.primary, VaiaColors.accent, VaiaColors.danger],
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Align(
            alignment: Alignment(0, 1 - 2 * _c.value),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: VaiaColors.primary, width: 1.6),
                boxShadow: [BoxShadow(color: VaiaColors.primary.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nodo(String titulo, String valor, Color color, IconData icono, {int? numero}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: VaiaColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: numero != null
                      ? Text('$numero', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color))
                      : Icon(icono, size: 10, color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
                Text(valor.isEmpty ? '-' : valor,
                    style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
