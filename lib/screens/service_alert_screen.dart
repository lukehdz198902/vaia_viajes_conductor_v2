import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/directions_service.dart';
import '../widgets/vaia_widgets.dart';

/// Tarjeta de servicio entrante: ocupa la mitad inferior de la pantalla, es
/// temporal (se cierra al expirar), se muestra una sola vez y permite aceptar
/// o rechazar/ignorar el servicio.
class ServiceAlertScreen extends StatefulWidget {
  const ServiceAlertScreen({super.key});
  @override
  State<ServiceAlertScreen> createState() => _ServiceAlertScreenState();
}

class _ServiceAlertScreenState extends State<ServiceAlertScreen> {
  bool _procesando = false;
  int _segundosRestantes = 30;
  int _segundosTotales = 30;
  Timer? _countdown;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapCtrl;
  bool _mapaListo = false;

  double? _kmRuta;
  int? _minRuta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ride = context.read<RideProvider>();
      final s = ride.servicioOfrecido ?? ride.activeRide;
      final total = s?.segundosParaTomar ?? 30;
      setState(() {
        _segundosTotales = total > 0 ? total : 30;
        _segundosRestantes = _segundosTotales;
      });
      _prepararMapa();
      _iniciarContador();
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

  /// Prepara el mapa con origen, destino y la ruta estimada.
  Future<void> _prepararMapa() async {
    final ride = context.read<RideProvider>();
    final s = ride.servicioOfrecido ?? ride.activeRide;
    if (s == null) return;

    final latO = double.tryParse(s.latOrigen ?? '');
    final lngO = double.tryParse(s.lngOrigen ?? '');
    final latD = double.tryParse(s.latDestino ?? '');
    final lngD = double.tryParse(s.lngDestino ?? '');
    if (latO == null || lngO == null || latD == null || lngD == null) return;

    final origen = LatLng(latO, lngO);
    final destino = LatLng(latD, lngD);

    setState(() {
      _markers
        ..clear()
        ..add(Marker(
          markerId: const MarkerId('origen'),
          position: origen,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: 'Origen', snippet: s.direccionOrigen ?? ''),
        ))
        ..add(Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(title: 'Destino', snippet: s.direccionDestino ?? ''),
        ));
    });

    final ruta = await DirectionsService.ruta(origen: origen, destino: destino);
    if (!mounted) return;
    if (ruta != null) {
      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('ruta'),
            points: ruta.puntos,
            color: VaiaColors.primary,
            width: 5,
          ));
        _kmRuta = ruta.distanciaMetros / 1000;
        _minRuta = (ruta.duracionSegundos / 60).round();
      });
    }
    _ajustarCamara(origen, destino);
  }

  void _ajustarCamara(LatLng a, LatLng b) {
    if (_mapCtrl == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
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

    final km = _kmRuta ?? (s.distanciaMetros != null ? s.distanciaMetros! / 1000 : null);
    final min = _minRuta ?? (s.distanciaMetros != null ? (s.distanciaMetros! / 8.33 / 60).round() : null);
    final progreso = _segundosTotales > 0 ? (_segundosRestantes / _segundosTotales).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.35),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Mapa (mitad superior) ───────────────────────────
            Expanded(
              flex: 45,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        double.tryParse(s.latOrigen ?? '') ?? 26.0923,
                        double.tryParse(s.lngOrigen ?? '') ?? -98.2789,
                      ),
                      zoom: 13,
                    ),
                    onMapCreated: (c) {
                      _mapCtrl = c;
                      _mapaListo = true;
                      final latO = double.tryParse(s.latOrigen ?? '');
                      final lngO = double.tryParse(s.lngOrigen ?? '');
                      final latD = double.tryParse(s.latDestino ?? '');
                      final lngD = double.tryParse(s.lngDestino ?? '');
                      if (latO != null && lngO != null && latD != null && lngD != null) {
                        _ajustarCamara(LatLng(latO, lngO), LatLng(latD, lngD));
                      }
                    },
                    markers: _markers,
                    polylines: _polylines,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationEnabled: false,
                  ),
                  if (!_mapaListo)
                    const Center(child: CircularProgressIndicator()),
                  // Barra de tiempo restante
                  Positioned(
                    top: 10, left: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: VaiaColors.surface,
                        borderRadius: BorderRadius.circular(VaiaRadius.md),
                        boxShadow: VaiaShadows.card,
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 34, height: 34,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progreso,
                                strokeWidth: 3,
                                backgroundColor: VaiaColors.bgMuted,
                                valueColor: AlwaysStoppedAnimation(
                                  _segundosRestantes <= 10 ? VaiaColors.danger : VaiaColors.primary,
                                ),
                              ),
                              Text('$_segundosRestantes',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Responde antes de que termine el tiempo',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Tarjeta (mitad inferior) ────────────────────────
            Expanded(
              flex: 55,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: VaiaColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.notifications_active_rounded, color: VaiaColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Nuevo servicio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                        // X para rechazar / ignorar
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
                      const SizedBox(height: 14),

                      // Datos del pasajero
                      Row(children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: VaiaColors.primaryGhost,
                          child: Text(
                            (s.pasajeroNombre ?? 'P')[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: VaiaColors.primary, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.pasajeroNombre ?? 'Pasajero',
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

                      // Recorrido
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: VaiaColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VaiaRadius.md),
                          border: Border.all(color: VaiaColors.border),
                        ),
                        child: Column(children: [
                          _punto(Icons.trip_origin, VaiaColors.onlineGreen, 'Origen', s.direccionOrigen ?? '-'),
                          Padding(
                            padding: const EdgeInsets.only(left: 11),
                            child: Container(width: 2, height: 18, color: VaiaColors.border),
                          ),
                          _punto(Icons.location_on_rounded, VaiaColors.danger, 'Destino', s.direccionDestino ?? '-'),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // Metricas
                      Row(children: [
                        _metrica(Icons.straighten_rounded, km != null ? '${km.toStringAsFixed(1)} km' : '--', 'Distancia'),
                        _metrica(Icons.timer_outlined, min != null ? '$min min' : '--', 'Tiempo'),
                        _metrica(Icons.payments_rounded,
                            s.costoEstimado != null ? '\$${s.costoEstimado!.toStringAsFixed(0)}' : '--', 'Estimado'),
                      ]),
                      const SizedBox(height: 16),

                      // Acciones
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
          ],
        ),
      ),
    );
  }

  Widget _punto(IconData icono, Color color, String label, String valor) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted, fontWeight: FontWeight.w700)),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
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
          Text(label, style: const TextStyle(fontSize: 9.5, color: VaiaColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
