import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});
  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.activeRide;
    final isEnCamino = s?.servicioEstatus == 'En Camino' || s?.servicioEstatus == null;
    final isEnViaje = s?.servicioEstatus == 'En Viaje';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnViaje ? 'En Viaje' : 'En Camino'),
        automaticallyImplyLeading: false,
      ),
      body: s == null
          ? const Center(child: Text('Viaje finalizado'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: AppTheme.primary, radius: 25, child: Text(s.pasajeroNombre?.isNotEmpty == true ? s.pasajeroNombre![0] : '?', style: const TextStyle(color: Colors.white))),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.pasajeroNombre ?? 'Pasajero', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(s.pasajeroTelefono ?? '', style: const TextStyle(color: AppTheme.textMedium)),
                          ])),
                          IconButton(icon: const Icon(Icons.phone, color: AppTheme.primary), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.chat, color: AppTheme.primary), onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'servicioId': s.id, 'pasajero': s.pasajeroNombre ?? 'Pasajero'})),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _stepRow(Icons.my_location, 'Origen', s.direccionOrigen ?? '', isEnCamino),
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Divider(height: 30, thickness: 2),
                          ),
                          _stepRow(Icons.location_on, 'Destino', s.direccionDestino ?? '', isEnViaje),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isEnCamino)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ride.startTrip(s.id, auth.userId);
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar Viaje'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  if (isEnViaje)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await ride.finishTrip(s.id, auth.userId);
                          if (!mounted) return;
                          navigator.pushReplacementNamed('/rating');
                        },
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('Finalizar Viaje'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _stepRow(IconData icon, String label, String address, bool active) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: active ? AppTheme.primary : AppTheme.textLight, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: active ? AppTheme.primary : AppTheme.textLight, fontWeight: FontWeight.w600)),
          Text(address, style: const TextStyle(color: AppTheme.textDark)),
        ])),
      ],
    );
  }
}
