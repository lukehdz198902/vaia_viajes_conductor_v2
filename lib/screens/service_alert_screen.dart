import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/marker_icons.dart';
import '../services/sound_service.dart';
import '../widgets/vaia_widgets.dart';

/// Tarjeta de servicio entrante: muestra el origen y la ubicacion actual de la
/// unidad en un mapa pequeno, los datos del pasajero y las acciones para
/// aceptar o rechazar. Se muestra una sola vez y expira con el contador.
class ServiceAlertScreen extends StatefulWidget {
  const ServiceAlertScreen({super.key});
  @override
  State<ServiceAlertScreen> createState() => _ServiceAlertScreenState();
}

class _ServiceAlertScreenState extends State<ServiceAlertScreen> {
  bool _procesando = false;
  bool _preparandoMapa = false;
  int _segundosRestantes = 30;
  int _segundosTotales = 30;
  Timer? _countdown;

  final Set<Marker> _markers = {};
  GoogleMapController? _mapCtrl;
  bool _mapaListo = false;
  LatLng? _miPosicion;

  @override
  void initState() {
    super.initState();
    SoundService.nuevoServicio();
    MarkerIcons.cargar().then((_) { if (mounted) _prepararMapa(); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ride = context.read<RideProvider>();
      final s = ride.servicioOfrecido ?? ride.activeRide;
      if (s == null) return;
      final total = s.segundosParaTomar ?? 30;
      setState(() {
        _segundosTotales = total > 0 ? total : 30;
        _segundosRestantes = _segundosTotales;
      });
      _iniciarContador();
      _prepararMapa();
      // Refresca nombre, calificacion y servicios del pasajero aunque el
      // payload del WebSocket venga incompleto.
      ride.refrescarOferta(s.id);
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _iniciarContador() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segundosRestantes--);
      if (_segundosRestantes <= 0) {
        t.cancel();
        _rechazar(auto: true);
      }
    });
  }

  Future<void> _prepararMapa() async {
    if (_preparandoMapa) return;
    _preparandoMapa = true;
    try {
      final ride = context.read<RideProvider>();
      final s = ride.servicioOfrecido ?? ride.activeRide;
      if (s == null) return;

      final latO = double.tryParse(s.latOrigen ?? '');
      final lngO = double.tryParse(s.lngOrigen ?? '');
      if (latO == null || lngO == null) return;
      final origen = LatLng(latO, lngO);

      LatLng? mi = _miPosicion;
      if (mi == null) {
        try {
          final pos = await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: Duration(seconds: 8),
                ),
              );
          mi = LatLng(pos.latitude, pos.longitude);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _miPosicion = mi;
        _markers
          ..clear()
          ..add(Marker(
            markerId: const MarkerId('origen'),
            position: origen,
            icon: MarkerIcons.origin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(title: 'Origen', snippet: s.direccionOrigen ?? ''),
          ));
        if (mi != null) {
          _markers.add(Marker(
            markerId: const MarkerId('mi_unidad'),
            position: mi,
            icon: MarkerIcons.car ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            anchor: const Offset(0.5, 0.5),
            infoWindow: const InfoWindow(title: 'Mi unidad'),
          ));
        }
      });
      _ajustarMapa(origen, mi);
    } finally {
      _preparandoMapa = false;
    }
  }

  void _ajustarMapa(LatLng origen, LatLng? unidad) {
    if (_mapCtrl == null) return;
    if (unidad == null) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(origen, 16));
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(
        origen.latitude < unidad.latitude ? origen.latitude : unidad.latitude,
        origen.longitude < unidad.longitude ? origen.longitude : unidad.longitude,
      ),
      northeast: LatLng(
        origen.latitude > unidad.latitude ? origen.latitude : unidad.latitude,
        origen.longitude > unidad.longitude ? origen.longitude : unidad.longitude,
      ),
    );
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 55));
  }

  Future<void> _rechazar({bool auto = false}) async {
    final ride = context.read<RideProvider>();
    final auth = context.read<AuthProvider>();
    final s = ride.servicioOfrecido ?? ride.activeRide;
    if (s == null || _procesando) return;
    setState(() => _procesando = true);
    await ride.rejectRide(s.id, auth.userId, motivo: auto ? 'Sin respuesta en el tiempo' : 'Rechazado por conductor');
    if (!mounted) return;
    ride.limpiarOfrecido();
    Navigator.pop(context);
  }

  Future<void> _aceptar() async {
    final ride = context.read<RideProvider>();
    final auth = context.read<AuthProvider>();
    final s = ride.servicioOfrecido ?? ride.activeRide;
    if (s == null || _procesando) return;
    setState(() => _procesando = true);
    _countdown?.cancel();
    final ok = await ride.acceptRide(s.id, auth.userId);
    if (!mounted) return;
    setState(() => _procesando = false);
    if (ok) {
      Navigator.pushReplacementNamed(context, '/service_status');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ride.error ?? 'No se pudo aceptar el servicio'),
        backgroundColor: VaiaColors.danger,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final s = ride.servicioOfrecido ?? ride.activeRide;

    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final km = s.distanciaMetros != null ? s.distanciaMetros! / 1000 : null;
    final min = s.distanciaMetros != null ? (s.distanciaMetros! / 8.33 / 60).round() : null;
    final progreso = _segundosTotales > 0 ? (_segundosRestantes / _segundosTotales).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: VaiaColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: VaiaColors.primaryGhost,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: VaiaColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Nuevo servicio',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  InkWell(
                    onTap: _procesando ? null : () => _rechazar(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: VaiaColors.bgMuted, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 18, color: VaiaColors.textSecondary),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _mapaCompacto(s.latOrigen, s.lngOrigen, progreso),
                const SizedBox(height: 14),
                Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: VaiaColors.primaryGhost,
                    child: Text(
                      (s.pasajeroNombre ?? '').trim().isEmpty
                          ? 'P'
                          : (s.pasajeroNombre ?? '').trim()[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: VaiaColors.primary, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.pasajeroNombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.star_rounded, size: 15, color: VaiaColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          (s.pasajeroCalificacion ?? 0) > 0
                              ? s.pasajeroCalificacion!.toStringAsFixed(1)
                              : 'Sin calificacion',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.route_rounded, size: 14, color: VaiaColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${s.pasajeroTotalViajes ?? 0} servicios',
                            style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5)),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VaiaColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VaiaRadius.md),
                    border: Border.all(color: VaiaColors.border),
                  ),
                  child: Column(children: [
                    _punto(const MarkerIcon(origin: true), 'Origen', s.direccionOrigen ?? '-'),
                    Padding(
                      padding: const EdgeInsets.only(left: 11),
                      child: Container(width: 2, height: 18, color: VaiaColors.border),
                    ),
                    _punto(const MarkerIcon(origin: false), 'Destino', s.direccionDestino ?? '-'),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _metrica(Icons.straighten_rounded, km != null ? '${km.toStringAsFixed(1)} km' : '--', 'Distancia'),
                  _metrica(Icons.timer_outlined, min != null ? '$min min' : '--', 'Tiempo'),
                  _metrica(Icons.payments_rounded,
                      s.costoEstimado != null ? '\$${s.costoEstimado!.toStringAsFixed(0)}' : '--', 'Estimado'),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _procesando ? null : () => _rechazar(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Ignorar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VaiaColors.danger,
                        side: const BorderSide(color: VaiaColors.danger),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: VaiaPrimaryButton(
                      label: 'Aceptar servicio',
                      icon: Icons.check_rounded,
                      loading: _procesando,
                      onPressed: _procesando ? null : _aceptar,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapaCompacto(String? lat, String? lng, double progreso) {
    final latO = double.tryParse(lat ?? '') ?? 26.0923;
    final lngO = double.tryParse(lng ?? '') ?? -98.2789;
    return ClipRRect(
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: SizedBox(
        height: 150,
        child: Stack(children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(latO, lngO), zoom: 15.5),
            onMapCreated: (c) {
              _mapCtrl = c;
              _mapaListo = true;
              final origen = LatLng(latO, lngO);
              _ajustarMapa(origen, _miPosicion);
            },
            markers: _markers,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            myLocationEnabled: false,
          ),
          if (!_mapaListo) const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: VaiaColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(VaiaRadius.pill),
                boxShadow: VaiaShadows.card,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: progreso,
                      strokeWidth: 2.5,
                      backgroundColor: VaiaColors.bgMuted,
                      valueColor: AlwaysStoppedAnimation(
                        _segundosRestantes <= 10 ? VaiaColors.danger : VaiaColors.primary,
                      ),
                    ),
                    Text('$_segundosRestantes',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 6),
                const Text('Responde', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _punto(Widget icono, String label, String valor) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 18, height: 18, child: Center(child: icono)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted, fontWeight: FontWeight.w700)),
          Text(valor,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }

  Widget _metrica(IconData icono, String valor, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: VaiaColors.bgSubtle, borderRadius: BorderRadius.circular(VaiaRadius.md)),
        child: Column(children: [
          Icon(icono, size: 17, color: VaiaColors.primary),
          const SizedBox(height: 3),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          Text(label,
              style: const TextStyle(fontSize: 9.5, color: VaiaColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
