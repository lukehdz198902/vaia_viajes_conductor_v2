import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class ServiceAlertScreen extends StatefulWidget {
  const ServiceAlertScreen({super.key});
  @override
  State<ServiceAlertScreen> createState() => _ServiceAlertScreenState();
}

class _ServiceAlertScreenState extends State<ServiceAlertScreen> {
  bool _procesando = false;
  int _segundosRestantes = 30;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _iniciarContador();
  }

  void _iniciarContador() {
    _countdown?.cancel();
    _segundosRestantes = 30;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segundosRestantes--);
      if (_segundosRestantes <= 0) {
        t.cancel();
        _rechazar(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _rechazar({bool auto = false}) async {
    final ride = context.read<RideProvider>();
    final auth = context.read<AuthProvider>();
    final s = ride.servicioOfrecido ?? ride.activeRide;
    if (s == null || _procesando) return;
    setState(() => _procesando = true);
    await ride.rejectRide(s.id, auth.userId, motivo: auto ? 'Sin respuesta en 30s' : 'Rechazado por conductor');
    if (!mounted) return;
    setState(() => _procesando = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.servicioOfrecido ?? ride.activeRide;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de Servicio')),
      body: s == null
          ? const Center(child: Text('No hay solicitudes activas'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Responde en $_segundosRestantes segundos',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                        ),
                        SizedBox(
                          width: 40, height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _segundosRestantes / 30,
                                strokeWidth: 3,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                              ),
                              Text('$_segundosRestantes', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: AppTheme.primary, radius: 30, child: Text(s.pasajeroNombre?.isNotEmpty == true ? s.pasajeroNombre![0] : '?', style: const TextStyle(fontSize: 24, color: Colors.white))),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.pasajeroNombre ?? 'Pasajero', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                if (s.pasajeroTelefono != null) Text(s.pasajeroTelefono!, style: const TextStyle(color: AppTheme.textMedium)),
                              ])),
                            ],
                          ),
                          const Divider(),
                          _detailRow(Icons.my_location, 'Origen', s.direccionOrigen ?? ''),
                          const SizedBox(height: 8),
                          _detailRow(Icons.location_on, 'Destino', s.direccionDestino ?? ''),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (s.distanciaMetros != null) _infoRow('Distancia', '${(s.distanciaMetros! / 1000).toStringAsFixed(1)} km'),
                          if (s.costoEstimado != null) _infoRow('Costo', '\$${s.costoEstimado!.toStringAsFixed(2)}'),
                          if (s.tipoViaje != null) _infoRow('Tipo', s.tipoViaje!),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _procesando
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _procesando = true);
                              _countdown?.cancel();
                              final ok = await ride.acceptRide(s.id, auth.userId);
                              if (!mounted) return;
                              setState(() => _procesando = false);
                              if (ok) {
                                nav.pushReplacementNamed('/service_status');
                              } else {
                                messenger.showSnackBar(SnackBar(
                                  content: Text(ride.error ?? 'No se pudo aceptar'),
                                  backgroundColor: AppTheme.danger,
                                ));
                              }
                            },
                      icon: _procesando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle),
                      label: const Text('Aceptar Servicio'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _procesando ? null : () => _rechazar(),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ])),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textMedium)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}