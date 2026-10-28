import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/storage_service.dart';

class _TourStep {
  final IconData icon;
  final String title;
  final String text;
  const _TourStep(this.icon, this.title, this.text);
}

/// Guia rapida que se muestra una sola vez al empezar a trabajar con Vaia.
Future<void> mostrarTourConductor(BuildContext context) async {
  final storage = StorageService();
  if (await storage.getTourCompletado()) return;
  if (!context.mounted) return;

  final steps = <_TourStep>[
    const _TourStep(Icons.verified_user_rounded, 'Completa tu perfil y unidad',
        'Sube tus documentos y registra tu vehiculo. Cuando todo este aprobado podras conectarte y recibir servicios.'),
    const _TourStep(Icons.wifi_tethering_rounded, 'Conectate para trabajar',
        'Activa tu disponibilidad desde Inicio. Mantén el GPS y el permiso de ubicacion siempre activos.'),
    const _TourStep(Icons.notifications_active_rounded, 'Recibe y acepta servicios',
        'Cuando llegue una solicitud revisa origen, destino y tarifa. Acepta o rechaza segun tu disponibilidad.'),
    const _TourStep(Icons.navigation_rounded, 'Navega y llega al origen',
        'Usa el mapa o abre Google Maps/Waze. Al llegar, pide el codigo de inicio al pasajero.'),
    const _TourStep(Icons.route_rounded, 'Realiza el viaje',
        'Revisa las preferencias del pasajero (musica, aire, mascotas o accesibilidad) y sigue la ruta hasta el destino.'),
    const _TourStep(Icons.payments_rounded, 'Cobra y finaliza',
        'Cobra el monto indicado, finaliza el servicio y revisa tus ganancias e historial.'),
    const _TourStep(Icons.health_and_safety_rounded, 'Contacto de emergencia',
        'Registra un contacto de emergencia en Ajustes. Es obligatorio para conectarte y activar el SOS.'),
  ];

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TourDialog(steps: steps),
  );
  await storage.setTourCompletado(true);
}

class _TourDialog extends StatefulWidget {
  final List<_TourStep> steps;
  const _TourDialog({required this.steps});

  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_page];
    final last = _page == widget.steps.length - 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: const BoxDecoration(gradient: VaiaColors.primaryGradient),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(step.icon, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 12),
                const Text('Bienvenido a Vaia Conductor',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Paso ${_page + 1} de ${widget.steps.length}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            height: 170,
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.steps.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = widget.steps[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                  child: Column(
                    children: [
                      Text(s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                      const SizedBox(height: 10),
                      Text(s.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, height: 1.5, color: VaiaColors.textSecondary)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.steps.length, (i) {
                    final sel = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: sel ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: sel ? VaiaColors.primary : VaiaColors.borderStrong,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (last) {
                        Navigator.pop(context);
                      } else {
                        _pc.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
                      }
                    },
                    child: Text(last ? 'Empezar a trabajar' : 'Siguiente'),
                  ),
                ),
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Omitir tour'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
