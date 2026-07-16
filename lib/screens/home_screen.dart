import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final ride = context.read<RideProvider>();
    if (auth.isLoggedIn) {
      ride.startPolling(auth.userId);
    }
  }

  @override
  void dispose() {
    context.read<RideProvider>().stopPolling();
    super.dispose();
  }

  void _showServiceRequest(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ServiceRequestDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ride = context.watch<RideProvider>();

    if (ride.hasNewRequest && ride.activeRide != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showServiceRequest(context);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.conductor?.nombreCompleto ?? 'Conductor'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.pushNamed(context, '/notifications')),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.pushNamed(context, '/settings')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: AppTheme.bgLight,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 80, color: AppTheme.textLight),
                    const SizedBox(height: 16),
                    Text(ride.activeRide != null ? 'Viaje en curso' : 'Esperando solicitudes', style: const TextStyle(fontSize: 18, color: AppTheme.textMedium)),
                    const SizedBox(height: 8),
                    Text(ride.activeRide != null ? 'Dirígete al punto de origen' : 'Zona de cobertura activa', style: const TextStyle(color: AppTheme.textLight)),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(Icons.star_outline, 'Calificación', auth.conductor?.calificacionPromedio?.toStringAsFixed(1) ?? '0.0'),
                    _buildQuickAction(Icons.monetization_on_outlined, 'Ganancias', ''),
                    _buildQuickAction(Icons.route_outlined, 'Viajes', (auth.conductor?.totalViajes ?? 0).toString()),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.read<AuthProvider>().toggleOnline(),
                    icon: Icon(auth.isOnline ? Icons.power_settings_new : Icons.wifi),
                    label: Text(auth.isOnline ? 'Desconectarse' : 'Conectarse'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: auth.isOnline ? AppTheme.offlineRed : AppTheme.onlineGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Ganancias'),
        ],
        onTap: (i) {
          switch (i) {
            case 1: Navigator.pushNamed(context, '/history');
            case 2: Navigator.pushNamed(context, '/profile');
            case 3: Navigator.pushNamed(context, '/earnings');
          }
        },
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
        if (value.isNotEmpty) Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class ServiceRequestDialog extends StatelessWidget {
  const ServiceRequestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.activeRide;

    if (s == null) return const SizedBox.shrink();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.route, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Nuevo Servicio', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.pasajeroNombre != null) Text('Pasajero: ${s.pasajeroNombre}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.my_location, size: 16, color: AppTheme.accent), const SizedBox(width: 8), Expanded(child: Text(s.direccionOrigen ?? 'Origen no disponible', style: const TextStyle(fontSize: 13)))]),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.location_on, size: 16, color: AppTheme.danger), const SizedBox(width: 8), Expanded(child: Text(s.direccionDestino ?? 'Destino no disponible', style: const TextStyle(fontSize: 13)))]),
          const SizedBox(height: 8),
          if (s.distanciaMetros != null) Text('Distancia: ${(s.distanciaMetros! / 1000).toStringAsFixed(1)} km'),
          if (s.costoEstimado != null) Text('Costo estimado: \$${s.costoEstimado!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
          if (s.tipoViaje != null) Text('Tipo: ${s.tipoViaje}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ride.acceptRide(s.id, auth.userId);
            Navigator.pop(context);
          },
          child: const Text('Aceptar', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }
}
