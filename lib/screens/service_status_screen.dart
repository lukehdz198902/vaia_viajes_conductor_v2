import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/servicio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/directions_service.dart';
import '../widgets/status_timeline.dart';
import 'report_incident_screen.dart';

/// Pantalla del servicio en curso del conductor.
///
/// Mapa a pantalla completa + panel deslizable con linea de tiempo animada,
/// datos completos del pasajero, recorrido, tarifa en vivo, paradas y acciones
/// (navegacion, codigo de inicio, cobro, soporte y SOS).
class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});
  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  final _codeCtrl = TextEditingController();
  bool _showCodeInput = false;
  bool _isStarting = false;
  bool _isLlegando = false;

  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _trazando = false;
  String _claveTrazo = '';
  int _ultimoPasoCamara = -99;
  RideProvider? _rideRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rideRef = context.read<RideProvider>();
      _rideRef!.addListener(_onRideChanged);
      final s = _rideRef!.activeRide;
      if (s != null) {
        _rideRef!.listarParadas(s.id);
        _trazarRuta();
      }
    });
  }

  void _onRideChanged() {
    if (mounted) _trazarRuta();
  }

  @override
  void dispose() {
    _rideRef?.removeListener(_onRideChanged);
    _codeCtrl.dispose();
    super.dispose();
  }

  // ─── Ruta en el mapa ──────────────────────────────────────────

  Future<void> _trazarRuta() async {
    final ride = context.read<RideProvider>();
    final s = ride.activeRide;
    if (s == null || _trazando) return;

    final latD = double.tryParse(s.latDestino ?? '');
    final lngD = double.tryParse(s.lngDestino ?? '');
    final latO = double.tryParse(s.latOrigen ?? '');
    final lngO = double.tryParse(s.lngOrigen ?? '');
    if (latD == null || lngD == null || latO == null || lngO == null) return;

    final origen = LatLng(latO, lngO);
    final destino = LatLng(latD, lngD);
    final enViaje = s.esEnViaje;

    // Ruta: hacia el origen mientras no inicia; hacia el destino en viaje.
    final inicio = enViaje ? origen : await _miPosicion(origen);
    final fin = enViaje ? destino : origen;

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

    final clave = '${s.id}|$enViaje';
    final debeRetrazar = clave != _claveTrazo;
    _claveTrazo = clave;

    if (debeRetrazar || _polylines.isEmpty) {
      _trazando = true;
      final ruta = await DirectionsService.ruta(origen: inicio, destino: fin);
      _trazando = false;
      if (!mounted) return;
      if (ruta != null && ruta.puntos.isNotEmpty) {
        setState(() {
          _polylines
            ..clear()
            ..add(Polyline(
              polylineId: const PolylineId('ruta'),
              points: ruta.puntos,
              color: VaiaColors.primary,
              width: 5,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ));
        });
      }
    }

    final paso = s.pasoActual;
    if (_ultimoPasoCamara != paso) {
      _ultimoPasoCamara = paso;
      _ajustar(inicio, fin);
    }
  }

  Future<LatLng> _miPosicion(LatLng fallback) async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) return LatLng(pos.latitude, pos.longitude);
    } catch (_) {}
    return fallback;
  }

  void _ajustar(LatLng a, LatLng b) {
    if (_mapCtrl == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(math.min(a.latitude, b.latitude), math.min(a.longitude, b.longitude)),
      northeast: LatLng(math.max(a.latitude, b.latitude), math.max(a.longitude, b.longitude)),
    );
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  Future<void> _navegar(String app, double lat, double lng) async {
    Uri uri;
    if (app == 'waze') {
      uri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    } else {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la app de navegacion'), backgroundColor: VaiaColors.warning),
        );
      }
    }
  }

  void _mostrarOpcionesNavegacion(String titulo, double lat, double lng) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(VaiaRadius.xl))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          ListTile(
            leading: const Icon(Icons.map_rounded, color: VaiaColors.primary),
            title: const Text('Google Maps'),
            subtitle: const Text('Abrir el recorrido en Google Maps'),
            onTap: () { Navigator.pop(ctx); _navegar('google', lat, lng); },
          ),
          ListTile(
            leading: const Icon(Icons.navigation_rounded, color: VaiaColors.accent),
            title: const Text('Waze'),
            subtitle: const Text('Abrir el recorrido en Waze'),
            onTap: () { Navigator.pop(ctx); _navegar('waze', lat, lng); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _llamar(String telefono) async {
    if (telefono.isEmpty) return;
    try { await launchUrl(Uri.parse('tel:$telefono')); } catch (_) {}
  }

  Future<void> _llegarAlOrigen(RideProvider ride, int servicioId, int conductorId) async {
    setState(() => _isLlegando = true);
    await ride.llegarAlOrigen(servicioId, conductorId);
    if (!mounted) return;
    setState(() { _isLlegando = false; _showCodeInput = true; });
    _trazarRuta();
  }

  Future<void> _iniciarViaje(RideProvider ride, int servicioId, int conductorId) async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _isStarting = true);
    final ok = await ride.startTrip(servicioId, conductorId, code);
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (ok) {
      setState(() => _showCodeInput = false);
      _trazarRuta();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ride.error ?? 'Codigo incorrecto'),
        backgroundColor: VaiaColors.danger,
      ));
    }
  }

  Future<void> _cobrarYFinalizar(RideProvider ride, int servicioId, int conductorId) async {
    final total = ride.costoEnCurso ?? ride.activeRide?.costoEstimado ?? 0;
    final recibidoCtrl = TextEditingController(text: total.toStringAsFixed(2));

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        title: const Text('Cobrar servicio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(VaiaRadius.md)),
                child: Column(children: [
                  const Text('Corte por tarifa dinamica',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VaiaColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: VaiaColors.primary)),
                ]),
              ),
              const SizedBox(height: 14),
              const Text('Captura el monto recibido en efectivo',
                  style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: recibidoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto recibido', prefixText: '\$ '),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar y finalizar')),
        ],
      ),
    );
    if (confirmar != true) return;

    final recibido = double.tryParse(recibidoCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if ((recibido - total).abs() > 0.01) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El monto recibido debe ser igual al total a cobrar'),
        backgroundColor: VaiaColors.danger,
      ));
      return;
    }

    final nav = Navigator.of(context);
    final ok = await ride.finishTrip(servicioId, conductorId, costoFinal: total);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo finalizar el servicio'), backgroundColor: VaiaColors.danger,
      ));
      return;
    }
    await ride.registrarPago(servicioId, conductorId, total, metodo: 'CASH');
    if (!mounted) return;
    nav.pushReplacementNamed('/rating', arguments: {'servicioId': servicioId});
  }

  Future<void> _activarSos(RideProvider ride, int servicioId, int conductorId) async {
    final ok = await ride.activarSOS(servicioId, conductorId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Alerta SOS enviada a los administradores' : 'No se pudo enviar la alerta'),
      backgroundColor: ok ? VaiaColors.danger : VaiaColors.warning,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.activeRide;

    if (s == null) {
      return const Scaffold(body: Center(child: Text('Viaje finalizado')));
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(double.tryParse(s.latOrigen ?? '') ?? 26.0923, double.tryParse(s.lngOrigen ?? '') ?? -98.2789),
                zoom: 13,
              ),
              onMapCreated: (c) { _mapCtrl = c; _trazarRuta(); },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              padding: EdgeInsets.only(bottom: size.height * 0.42, top: 100),
            ),
          ),
          _barraSuperior(s),
          DraggableScrollableSheet(
            initialChildSize: 0.46,
            minChildSize: 0.28,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.46, 0.92],
            builder: (ctx, scrollCtrl) => _panel(scrollCtrl, s, ride, auth),
          ),
        ],
      ),
    );
  }

  Widget _barraSuperior(Servicio s) {
    final conectado = context.watch<RideProvider>().conectadoWs;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(VaiaRadius.lg),
              boxShadow: VaiaShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_taxi_rounded, size: 18, color: VaiaColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Servicio #${s.id}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                      Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: conectado ? VaiaColors.success : VaiaColors.textMuted, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(conectado ? 'Tiempo real' : 'Reconectando...',
                            style: TextStyle(fontSize: 11, color: conectado ? VaiaColors.success : VaiaColors.textMuted)),
                      ]),
                    ],
                  ),
                ),
                if ((s.tipoPago ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: VaiaColors.bgSubtle, borderRadius: BorderRadius.circular(VaiaRadius.pill)),
                    child: Text(s.tipoPago!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: VaiaColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(ScrollController scrollCtrl, Servicio s, RideProvider ride, AuthProvider auth) {
    final isLlegoOrigen = s.esLlegoOrigen;
    final isEnViaje = s.esEnViaje;

    return Container(
      decoration: const BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: Container(
              width: 42, height: 5,
              decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 16),

          _tituloEstatus(s),
          const SizedBox(height: 18),
          StatusTimeline(pasoActual: s.pasoActual, cancelado: s.cancelado, compacto: true),
          const SizedBox(height: 20),

          _tarjetaPasajero(s, isEnViaje),
          const SizedBox(height: 14),
          _tarjetaRuta(s),
          const SizedBox(height: 14),

          // Navegacion
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final lat = double.tryParse(isEnViaje ? (s.latDestino ?? '') : (s.latOrigen ?? ''));
                  final lng = double.tryParse(isEnViaje ? (s.lngDestino ?? '') : (s.lngOrigen ?? ''));
                  if (lat != null && lng != null) {
                    _mostrarOpcionesNavegacion(isEnViaje ? 'Ir al destino' : 'Ir por el pasajero', lat, lng);
                  }
                },
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: Text(isEnViaje ? 'Ir al destino' : 'Ir al origen'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ]),

          // Llegue al origen
          if (!isEnViaje && !isLlegoOrigen) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLlegando ? null : () => _llegarAlOrigen(ride, s.id, auth.userId),
              icon: _isLlegando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.place_rounded),
              label: const Text('Llegue al origen'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],

          // Codigo de inicio
          if (isLlegoOrigen && !isEnViaje) ...[
            const SizedBox(height: 12),
            if (!_showCodeInput)
              ElevatedButton.icon(
                onPressed: () => setState(() => _showCodeInput = true),
                icon: const Icon(Icons.password_rounded),
                label: const Text('Ingresar codigo de inicio'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VaiaColors.primaryGhost,
                  borderRadius: BorderRadius.circular(VaiaRadius.lg),
                  border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.35)),
                ),
                child: Column(children: [
                  const Text('Pide al pasajero su codigo de inicio',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: VaiaColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 10),
                    decoration: const InputDecoration(hintText: '000000', counterText: ''),
                    onSubmitted: (_) => _iniciarViaje(ride, s.id, auth.userId),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isStarting ? null : () => _iniciarViaje(ride, s.id, auth.userId),
                    icon: _isStarting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar viaje'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                ]),
              ),
          ],

          // Taximetro
          if (isEnViaje) ...[
            const SizedBox(height: 14),
            _tarjetaTarifa(ride, s),
          ],

          // Paradas
          if (ride.paradas.isNotEmpty) ...[
            const SizedBox(height: 14),
            _tarjetaParadas(ride, isEnViaje),
          ],

          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/support_chat', arguments: {'idServicio': s.id}),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('Soporte'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _SosButton(onCompletar: () => _activarSos(ride, s.id, auth.userId))),
          ]),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportIncidentScreen(idServicio: s.id))),
            icon: const Icon(Icons.report_problem_outlined, size: 18, color: VaiaColors.warning),
            label: const Text('Reportar incidente', style: TextStyle(color: VaiaColors.warning)),
          ),

          if (isEnViaje) ...[
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: () => _cobrarYFinalizar(ride, s.id, auth.userId),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Finalizar y cobrar'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _tituloEstatus(Servicio s) {
    final (titulo, subtitulo) = _textoEstatus(s);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim), child: child),
      ),
      child: Column(
        key: ValueKey('${s.servicioEstatus}-${s.pasoActual}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(subtitulo, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }

  (String, String) _textoEstatus(Servicio s) {
    if (s.cancelado) return ('Servicio cancelado', 'El servicio ya no esta activo');
    switch (s.pasoActual) {
      case 0:
        return ('Servicio asignado', 'Dirigete al punto de recogida');
      case 1:
        return ('En camino al origen', s.direccionOrigen ?? '');
      case 2:
        return ('Llegaste al origen', 'Solicita el codigo de inicio al pasajero');
      case 3:
        return ('Viaje en curso', 'Conduce a ${s.direccionDestino ?? 'el destino'}');
      case 4:
        return ('Servicio finalizado', 'Buen trabajo');
      default:
        return (s.servicioEstatus ?? 'Servicio', s.servicioEstatusDescripcion ?? '');
    }
  }

  Widget _tarjetaPasajero(Servicio s, bool isEnViaje) {
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: VaiaColors.primaryGhost,
            backgroundImage: (s.pasajeroFoto != null && s.pasajeroFoto!.isNotEmpty) ? NetworkImage(s.pasajeroFoto!) : null,
            child: (s.pasajeroFoto == null || s.pasajeroFoto!.isEmpty)
                ? Text(s.pasajeroNombreCompleto.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: VaiaColors.primary))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.pasajeroNombreCompleto,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: VaiaColors.accent),
                  const SizedBox(width: 3),
                  Text(
                    (s.pasajeroCalificacion ?? 0) > 0 ? s.pasajeroCalificacion!.toStringAsFixed(1) : 'Nuevo',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
                  ),
                  if ((s.pasajeroTotalViajes ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: VaiaColors.textMuted, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${s.pasajeroTotalViajes} viajes', style: const TextStyle(fontSize: 12, color: VaiaColors.textSecondary)),
                  ],
                ]),
              ],
            ),
          ),
          if (!isEnViaje) ...[
            _accionCircular(Icons.phone_rounded, VaiaColors.onlineGreen, () => _llamar(s.pasajeroTelefono ?? '')),
            const SizedBox(width: 8),
            _accionCircular(Icons.chat_bubble_rounded, VaiaColors.primary,
                () => Navigator.pushNamed(context, '/chat', arguments: {'idServicio': s.id, 'conductorNombre': s.pasajeroNombreCompleto})),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaRuta(Servicio s) {
    return _card(
      child: Column(
        children: [
          _renglonRuta(Icons.trip_origin, VaiaColors.onlineGreen, 'Origen', s.direccionOrigen ?? '-', activo: !s.esEnViaje),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 2, height: 18, color: VaiaColors.border),
          ),
          _renglonRuta(Icons.location_on_rounded, VaiaColors.danger, 'Destino', s.direccionDestino ?? '-', activo: s.esEnViaje),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(children: [
            _metrica(Icons.route_rounded, '${((s.distanciaMetros ?? 0) / 1000).toStringAsFixed(1)} km', 'Distancia'),
            _separador(),
            _metrica(Icons.timer_rounded,
                (s.duracionSegundos ?? 0) > 0 ? '${((s.duracionSegundos ?? 0) / 60).ceil()} min' : '--', 'Duracion'),
            _separador(),
            _metrica(Icons.local_taxi_rounded, s.tipoViaje ?? '--', 'Tipo'),
          ]),
        ],
      ),
    );
  }

  Widget _renglonRuta(IconData icon, Color color, String label, String valor, {bool activo = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: VaiaColors.textMuted, letterSpacing: 0.4)),
              Text(valor, style: TextStyle(fontSize: 13.5, fontWeight: activo ? FontWeight.w800 : FontWeight.w600, color: VaiaColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metrica(IconData icon, String valor, String label) {
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 18, color: VaiaColors.primary),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted)),
      ]),
    );
  }

  Widget _separador() => Container(width: 1, height: 30, color: VaiaColors.border);

  Widget _tarjetaTarifa(RideProvider ride, Servicio s) {
    final monto = ride.costoEnCurso ?? s.costoEstimado ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: VaiaColors.primaryGradient, borderRadius: BorderRadius.circular(VaiaRadius.lg)),
      child: Column(children: [
        const Text('COBRO HASTA EL MOMENTO',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: monto, end: monto),
          duration: const Duration(milliseconds: 500),
          builder: (_, v, __) => Text('\$${v.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 4),
        Text('Tarifa dinamica segun distancia y tiempo',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
      ]),
    );
  }

  Widget _tarjetaParadas(RideProvider ride, bool isEnViaje) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Paradas (${ride.paradas.where((p) => p.completada).length}/${ride.paradas.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: VaiaColors.textPrimary)),
        const SizedBox(height: 8),
        ...ride.paradas.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(p.completada ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 18, color: p.completada ? VaiaColors.success : VaiaColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${p.orden}. ${p.direccion}',
                      style: TextStyle(
                        fontSize: 12.5,
                        decoration: p.completada ? TextDecoration.lineThrough : null,
                        color: p.completada ? VaiaColors.textMuted : VaiaColors.textPrimary,
                      )),
                ),
                if (!p.completada && !isEnViaje)
                  TextButton(
                    onPressed: () => ride.completarParada(p.id),
                    child: const Text('Llegue', style: TextStyle(fontSize: 12)),
                  ),
              ]),
            )),
      ]),
    );
  }

  Widget _accionCircular(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: color)),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VaiaColors.surface,
          borderRadius: BorderRadius.circular(VaiaRadius.lg),
          border: Border.all(color: VaiaColors.border),
          boxShadow: VaiaShadows.card,
        ),
        child: child,
      );
}

/// Boton SOS: exige mantener presionado ~1.8 s para activar la alerta.
class _SosButton extends StatefulWidget {
  final Future<void> Function() onCompletar;
  const _SosButton({required this.onCompletar});
  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  Timer? _timer;
  double _progreso = 0;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _iniciar() {
    _timer?.cancel();
    _progreso = 0;
    const pasos = 18;
    var i = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      setState(() => _progreso = i / pasos);
      if (i >= pasos) {
        t.cancel();
        HapticFeedback.heavyImpact();
        widget.onCompletar();
        setState(() => _progreso = 0);
      }
    });
  }

  void _cancelar() { _timer?.cancel(); if (mounted) setState(() => _progreso = 0); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _iniciar(),
      onTapUp: (_) => _cancelar(),
      onTapCancel: _cancelar,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VaiaColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          border: Border.all(color: VaiaColors.danger, width: 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_progreso > 0)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progreso,
                  child: Container(
                    decoration: BoxDecoration(
                      color: VaiaColors.danger.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                    ),
                  ),
                ),
              ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.sos_rounded, size: 20, color: VaiaColors.danger),
              const SizedBox(width: 8),
              Text('Mantener SOS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: VaiaColors.danger)),
            ]),
          ],
        ),
      ),
    );
  }
}
