import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/servicio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../widgets/vaia_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RideProvider? _ride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ride = context.read<RideProvider>();
      _ride = ride;
      if (auth.isLoggedIn) {
        ride.startPolling(auth.userId);
        ride.iniciarPresencia(auth.userId);
      }
    });
  }

  @override
  void dispose() {
    _ride?.stopPolling();
    _ride?.detenerPresencia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ride = context.watch<RideProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Servicio entrante via WebSocket -> pantalla de alerta
      if (ride.servicioOfrecido != null && ride.hasNewRequest) {
        Navigator.pushNamed(context, '/service_alert');
      }
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context, auth),
            Expanded(
              child: ride.activeRide != null
                  ? _buildActiveRideView(ride)
                  : _buildIdleView(context, auth, ride),
            ),
            _buildBottomPanel(context, auth, ride),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: VaiaColors.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Ganancias'),
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

  Widget _buildTopBar(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const VaiaLogo(size: 40, showText: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${auth.conductor?.nombre ?? "Conductor"}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                Row(
                  children: [
                    VaiaStatusDot(online: auth.isOnline, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      auth.isOnline ? 'En linea' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 11,
                        color: auth.isOnline ? VaiaColors.onlineGreen : VaiaColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _iconAction(context, Icons.support_agent_rounded, () {
            final s = context.read<RideProvider>().activeRide;
            if (s != null) {
              Navigator.pushNamed(context, '/support_chat', arguments: {'idServicio': s.id});
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('El soporte esta disponible durante un servicio activo'),
                backgroundColor: VaiaColors.warning,
              ));
            }
          }),
          _iconAction(context, Icons.notifications_outlined, () => Navigator.pushNamed(context, '/notifications')),
          _iconAction(context, Icons.settings_outlined, () => Navigator.pushNamed(context, '/settings')),
        ],
      ),
    );
  }

  Widget _iconAction(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: VaiaColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildIdleView(BuildContext context, AuthProvider auth, RideProvider ride) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VaiaColors.primaryGhost,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: VaiaColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: VaiaShadows.card,
            ),
            child: Icon(
              Icons.local_taxi_rounded,
              size: 56,
              color: auth.isOnline ? VaiaColors.primary : VaiaColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            auth.isOnline ? 'Esperando solicitudes' : 'Estas desconectado',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              auth.isOnline
                  ? 'Mantente cerca, los viajes cercanos llegaran pronto'
                  : 'Conectate para empezar a recibir viajes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (auth.isOnline)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VaiaColors.primary),
                ),
                SizedBox(width: 10),
                Text('Buscando viajes...', style: TextStyle(fontSize: 13, color: VaiaColors.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActiveRideView(RideProvider ride) {
    final s = ride.activeRide;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: VaiaColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VaiaBadge(label: 'Viaje activo', color: Colors.white, filled: false),
              const SizedBox(height: 12),
              Text(
                s?.pasajeroNombre ?? 'Pasajero',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 16),
              _rideDetail(Icons.my_location_rounded, 'Origen', s?.direccionOrigen ?? '-'),
              const SizedBox(height: 10),
              _rideDetail(Icons.location_on_rounded, 'Destino', s?.direccionDestino ?? '-'),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (s?.distanciaMetros != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(VaiaRadius.pill),
                      ),
                      child: Text(
                        '${(s!.distanciaMetros! / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  const Spacer(),
                  if (s?.costoEstimado != null)
                    Text(
                      '\$${s!.costoEstimado!.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rideDetail(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context, AuthProvider auth, RideProvider ride) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statTile(Icons.star_rounded, 'Calificacion', auth.conductor?.calificacionPromedio?.toStringAsFixed(1) ?? '0.0', VaiaColors.accent),
                  _statTile(Icons.monetization_on_rounded, 'Ganancias', '\$0', VaiaColors.onlineGreen),
                  _statTile(Icons.route_rounded, 'Viajes', (auth.conductor?.totalViajes ?? 0).toString(), VaiaColors.primary),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.read<AuthProvider>().toggleOnline(),
                  icon: Icon(
                    auth.isOnline ? Icons.power_settings_new_rounded : Icons.wifi_tethering_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    auth.isOnline ? 'Desconectarse' : 'Conectarse',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: auth.isOnline ? VaiaColors.offlineRed : VaiaColors.onlineGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(VaiaRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: VaiaColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class ServiceRequestDialog extends StatelessWidget {
  final Servicio servicio;
  const ServiceRequestDialog({super.key, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = servicio;

    return Dialog(
      backgroundColor: VaiaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_active_rounded, color: VaiaColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Nueva solicitud', style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (s.pasajeroNombre != null)
              Text(s.pasajeroNombre!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _iconRow(context, Icons.my_location_rounded, 'Origen', s.direccionOrigen, VaiaColors.onlineGreen),
            const SizedBox(height: 8),
            _iconRow(context, Icons.location_on_rounded, 'Destino', s.direccionDestino, VaiaColors.danger),
            const SizedBox(height: 16),
            Row(
              children: [
                if (s.distanciaMetros != null) _infoChip(context, '${(s.distanciaMetros! / 1000).toStringAsFixed(1)} km'),
                const SizedBox(width: 8),
                if (s.costoEstimado != null) _infoChip(context, '\$${s.costoEstimado!.toStringAsFixed(2)}', primary: true),
                const Spacer(),
                if (s.tipoViaje != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VaiaColors.primaryGhost,
                      borderRadius: BorderRadius.circular(VaiaRadius.pill),
                    ),
                    child: Text(s.tipoViaje!, style: const TextStyle(fontSize: 11, color: VaiaColors.primary, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ride.rejectRide(s.id, auth.userId);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VaiaColors.danger,
                      side: const BorderSide(color: VaiaColors.danger, width: 1.2),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
                    ),
                    child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ride.acceptRide(s.id, auth.userId);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VaiaColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(BuildContext context, IconData icon, String label, String? value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: VaiaColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value ?? '-', style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip(BuildContext context, String text, {bool primary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary ? VaiaColors.primary : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(VaiaRadius.pill),
        border: primary ? null : Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primary ? Colors.white : VaiaColors.textPrimary,
        ),
      ),
    );
  }
}