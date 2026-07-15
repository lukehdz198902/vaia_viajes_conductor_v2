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
  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.activeRide;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de Servicio')),
      body: s == null
          ? const Center(child: Text('No hay solicitudes activas'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.pasajeroNombre ?? 'Pasajero', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                if (s.pasajeroTelefono != null) Text(s.pasajeroTelefono!, style: const TextStyle(color: AppTheme.textMedium)),
                              ]),
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
                      onPressed: () {
                        ride.acceptRide(s.id, auth.userId);
                        Navigator.pushReplacementNamed(context, '/service_status');
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Aceptar Servicio'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
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
