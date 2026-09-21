import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/servicio_model.dart';
import '../models/unidad_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/bubble_overlay.dart';
import '../widgets/vaia_widgets.dart';
import '../widgets/email_verification_sheet.dart';
import '../widgets/onboarding_checklist.dart';
import '../providers/profile_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  RideProvider? _ride;
  final _api = ApiService();
  Map<String, dynamic>? _resumen;
  Timer? _resumenTimer;

  // Mapa de zonas de demanda / conexion
  GoogleMapController? _mapController;
  final Set<Marker> _mapMarkers = {};
  final Set<Circle> _mapCircles = {};
  bool _ocultarPaneles = false;
  Position? _miPosicion;
  StreamSubscription<Position>? _posSub;
  bool _siguiendo = true;

  /// Pide permiso de ubicacion, centra el mapa en el conductor y sigue su
  /// movimiento con un stream de posiciones.
  Future<void> _iniciarSeguimiento() async {
    final ride = context.read<RideProvider>();
    final ok = await ride.asegurarPermisoUbicacion();
    if (!ok || !mounted) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _miPosicion = pos;
          _actualizarMarcadorConductor();
        });
        _centrarEnConductor();
      }
    } catch (_) {}

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 8),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _miPosicion = pos;
        _actualizarMarcadorConductor();
      });
      if (_siguiendo) _centrarEnConductor();
    });
  }

  void _centrarEnConductor() {
    final p = _miPosicion;
    if (p == null) return;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 16));
  }

  void _actualizarMarcadorConductor() {
    _mapMarkers.removeWhere((m) => m.markerId.value == 'mi_ubicacion');
    final p = _miPosicion;
    if (p == null) return;
    _mapMarkers.add(Marker(
      markerId: const MarkerId('mi_ubicacion'),
      position: LatLng(p.latitude, p.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: const InfoWindow(title: 'Mi ubicacion'),
      zIndex: 5,
    ));
  }

  /// Carga las zonas de mayor demanda (servicios historicos) y las zonas
  /// donde mas se conectan los pasajeros.
  Future<void> _cargarMapa() async {
    try {
      final rd = await _api.zonasDemanda(dias: 90);
      final rc = await _api.zonasConexion();
      final demanda = rd.list ?? [];
      final conexion = rc.list ?? [];

      int totalDe(dynamic e) => int.tryParse((e as Map)['total']?.toString() ?? '') ?? 0;
      double? latDe(dynamic e) => double.tryParse((e as Map)['lat']?.toString() ?? '');
      double? lngDe(dynamic e) => double.tryParse((e as Map)['lng']?.toString() ?? '');

      final maxD = demanda.fold<int>(1, (m, e) => totalDe(e) > m ? totalDe(e) : m);
      final circles = <Circle>{};
      for (var i = 0; i < demanda.length; i++) {
        final e = demanda[i];
        final lat = latDe(e);
        final lng = lngDe(e);
        if (lat == null || lng == null) continue;
        final ratio = totalDe(e) / maxD;
        circles.add(Circle(
          circleId: CircleId('dem_$i'),
          center: LatLng(lat, lng),
          radius: 250 + ratio * 900,
          fillColor: VaiaColors.danger.withValues(alpha: 0.16 + ratio * 0.26),
          strokeColor: VaiaColors.danger.withValues(alpha: 0.55),
          strokeWidth: 2,
        ));
      }

      final markers = <Marker>{};
      for (var i = 0; i < conexion.length; i++) {
        final e = conexion[i];
        final lat = latDe(e);
        final lng = lngDe(e);
        if (lat == null || lng == null) continue;
        markers.add(Marker(
          markerId: MarkerId('con_$i'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: 'Pasajeros conectados: ${totalDe(e)}'),
        ));
      }

      if (!mounted) return;
      setState(() {
        _mapCircles
          ..clear()
          ..addAll(circles);
        _mapMarkers
          ..clear()
          ..addAll(markers);
      });
    } catch (_) {}
  }

  Future<void> _cargarResumen() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final r = await _api.resumenDia(auth.userId);
      if (!mounted || r.data == null) return;
      setState(() => _resumen = r.data);
    } catch (_) {}
  }

  String _fmtMinutos(dynamic v) {
    final m = int.tryParse(v?.toString() ?? '') ?? 0;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ride = context.read<RideProvider>();
      _ride = ride;
      if (!auth.isLoggedIn) return;
      ride.startPolling(auth.userId);
      ride.iniciarPresencia(auth.userId);
      await context.read<ProfileProvider>().loadUnidades(auth.userId);
      if (!mounted) return;
      await _promptEmailVerification(auth);
      if (!mounted) return;
      await _seleccionarUnidadPredeterminada();
      _cargarMapa();
      _iniciarSeguimiento();
      _cargarResumen();
      _resumenTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cargarResumen());
    });
  }

  /// Muestra la burbuja flotante al minimizar/cerrar la app y la oculta al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ride = _ride;
    if (ride == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // La app pasa a segundo plano: el servicio en primer plano toma el
      // reporte de ubicacion y la burbuja se muestra automaticamente.
      ride.marcarPrimerPlano(false);
      ride.mostrarBurbuja();
    } else if (state == AppLifecycleState.resumed) {
      ride.marcarPrimerPlano(true);
      ride.ocultarBurbuja();
    }
  }

  /// Si el conductor tiene varias unidades aprobadas y ninguna seleccionada,
  /// se le pide elegir con cual va a laborar.
  Future<void> _seleccionarUnidadPredeterminada() async {
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();
    final aprobadas = profile.unidades.where((u) => u.aprobada == true).toList();
    if (aprobadas.isEmpty || aprobadas.any((u) => u.enUso == true)) return;
    if (!mounted) return;

    final elegida = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _UnidadPickerSheet(unidades: aprobadas),
    );
    if (elegida == null || !mounted) return;
    await profile.selectUnidad(auth.userId, elegida);
  }

  /// Solicita verificar el correo si aun no esta confirmado (con opcion de
  /// corregirlo). Se pide cada vez que el conductor ingresa.
  Future<void> _promptEmailVerification(AuthProvider auth) async {
    final c = auth.conductor;
    if (c == null || c.correoConfirmado == true) return;
    if (!mounted) return;

    await EmailVerificationSheet.mostrar(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _resumenTimer?.cancel();
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
          _iconAction(context, Icons.folder_shared_outlined, () => Navigator.pushNamed(context, '/documents')),
          _iconAction(context, Icons.notifications_outlined, () => Navigator.pushNamed(context, '/notifications')),
          _iconAction(context, Icons.picture_in_picture_alt_rounded, () async {
            await context.read<RideProvider>().mostrarBurbuja();
            await BubbleOverlay.minimizar();
          }),
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
    return Stack(
      children: [
        // Mapa con las zonas de mayor demanda y de conexion de pasajeros
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(26.0923, -98.2789), zoom: 12),
          onMapCreated: (c) {
            _mapController = c;
            _centrarEnConductor();
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          markers: _mapMarkers,
          circles: _mapCircles,
        ),
        // Estado de conexion (socket) y ultima ubicacion enviada al servidor
        Positioned(top: 10, left: 10, child: _chipEstado(ride)),
        // Boton para ocultar/mostrar las tarjetas y ver el mapa mas amplio
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: VaiaColors.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(VaiaRadius.md),
            child: InkWell(
              onTap: () => setState(() => _ocultarPaneles = !_ocultarPaneles),
              borderRadius: BorderRadius.circular(VaiaRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_ocultarPaneles ? Icons.map_rounded : Icons.visibility_off_rounded, size: 17, color: VaiaColors.primary),
                  const SizedBox(width: 6),
                  Text(_ocultarPaneles ? 'Ver tarjetas' : 'Ver mapa',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: VaiaColors.primary)),
                ]),
              ),
            ),
          ),
        ),
        // Boton para centrar y seguir al conductor en el mapa
        Positioned(
          right: 14,
          bottom: _ocultarPaneles ? 70 : 122,
          child: FloatingActionButton.small(
            heroTag: 'centrar_mapa',
            backgroundColor: VaiaColors.surface,
            foregroundColor: _siguiendo ? VaiaColors.primary : VaiaColors.textSecondary,
            onPressed: () {
              setState(() => _siguiendo = true);
              _centrarEnConductor();
            },
            child: Icon(_siguiendo ? Icons.my_location_rounded : Icons.location_searching_rounded),
          ),
        ),
        if (!_ocultarPaneles) ...[
          const Positioned(top: 8, left: 0, right: 0, child: OnboardingChecklist()),
          Positioned(bottom: 14, left: 14, right: 14, child: _estadoCard(context, auth)),
        ] else
          Positioned(bottom: 14, left: 14, child: _leyendaMapa()),
      ],
    );
  }

  Widget _chipEstado(RideProvider ride) {
    final conectado = ride.conectadoWs;
    final color = conectado ? VaiaColors.onlineGreen : VaiaColors.warning;
    final ult = ride.ultimaUbicacion;
    final hora = ult != null
        ? '${ult.hour.toString().padLeft(2, '0')}:${ult.minute.toString().padLeft(2, '0')}:${ult.second.toString().padLeft(2, '0')}'
        : '--:--:--';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: VaiaColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(conectado ? 'En vivo' : 'Sin conexion',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 3),
          Text('Ultima ubicacion: $hora', style: const TextStyle(fontSize: 10.5, color: VaiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _estadoCard(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        boxShadow: VaiaShadows.elevated,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (auth.isOnline ? VaiaColors.primary : VaiaColors.textMuted).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(VaiaRadius.md),
            ),
            child: Icon(Icons.local_taxi_rounded, size: 28, color: auth.isOnline ? VaiaColors.primary : VaiaColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.isOnline ? 'Esperando solicitudes' : 'Estas desconectado',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  auth.isOnline ? 'Mantente cerca de las zonas con mas demanda' : 'Conectate para empezar a recibir viajes',
                  style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (auth.isOnline)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VaiaColors.primary)),
        ],
      ),
    );
  }

  Widget _leyendaMapa() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: VaiaColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Zonas de demanda', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: VaiaColors.danger.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(color: VaiaColors.danger),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Mas servicios', style: TextStyle(fontSize: 10.5, color: VaiaColors.textSecondary)),
          ]),
          const SizedBox(height: 4),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, size: 13, color: Color(0xFF3B82F6)),
            SizedBox(width: 6),
            Text('Mas pasajeros conectados', style: TextStyle(fontSize: 10.5, color: VaiaColors.textSecondary)),
          ]),
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
                  _statTile(Icons.monetization_on_rounded, 'Ganancias hoy',
                      '\$${(double.tryParse(_resumen?['gananciasdia']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}', VaiaColors.onlineGreen),
                  _statTile(Icons.route_rounded, 'Servicios hoy', (_resumen?['serviciosdia'] ?? 0).toString(), VaiaColors.primary),
                  _statTile(Icons.timer_outlined, 'Conectado', _fmtMinutos(_resumen?['minutosconectado']), VaiaColors.accent),
                  _statTile(Icons.star_rounded, 'Calificacion', auth.conductor?.calificacionPromedio?.toStringAsFixed(1) ?? '0.0', VaiaColors.warning),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await auth.toggleOnline();
                    if (!mounted) return;
                    if (!ok) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(auth.error ?? 'No se pudo cambiar el estatus'),
                        backgroundColor: VaiaColors.danger,
                      ));
                    } else {
                      _cargarResumen();
                    }
                  },
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


/// Hoja para que el conductor elija con cual unidad aprobada va a laborar.
class _UnidadPickerSheet extends StatelessWidget {
  final List<Unidad> unidades;
  const _UnidadPickerSheet({required this.unidades});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: VaiaColors.primaryGradient, borderRadius: BorderRadius.circular(VaiaRadius.md)),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Elige tu unidad', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text('Selecciona con cual vas a laborar', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VaiaColors.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 18),
              ...unidades.map((u) => _card(context, u)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Unidad u) {
    final detalle = [u.anio?.toString(), u.color].where((e) => e != null && e.isNotEmpty).join(' - ');
    return InkWell(
      onTap: () => Navigator.pop(context, u.id),
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VaiaColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          border: Border.all(color: VaiaColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.directions_car_filled_rounded, color: VaiaColors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            if (detalle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12)),
            ],
          ])),
          const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
        ]),
      ),
    );
  }
}
