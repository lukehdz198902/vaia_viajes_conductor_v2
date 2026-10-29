import '../services/foto_util.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/recorrido_model.dart';
import '../models/servicio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/marker_icons.dart';
import '../widgets/ruta_timeline.dart';
import '../widgets/slide_to_confirm.dart';
import '../services/sound_service.dart';
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
  List<LatLng> _recorrido = const [];
  Map<String, dynamic>? _prefsPasajero;
  bool _cargandoPrefs = false;
  Timer? _recorridoTimer;
  bool _cargandoRecorrido = false;
  String? _recorridoMensaje;
  int _ultimoPasoCamara = -99;
  RideProvider? _rideRef;
  String? _ultimoEstado;

  @override
  void initState() {
    super.initState();
    MarkerIcons.cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rideRef = context.read<RideProvider>();
      _rideRef!.addListener(_onRideChanged);
      final s = _rideRef!.activeRide;
      if (s != null) {
        _rideRef!.listarParadas(s.id);
        _cargarPreferencias(s.id);
        _rideRef!.cargarTarifasServicio(s.id);
        _actualizarMapa(forzar: true);
        _cargarRecorrido();
      }
      _recorridoTimer = Timer.periodic(const Duration(seconds: 12), (_) => _cargarRecorrido());
    });
  }

  void _onRideChanged() {
    if (!mounted) return;
    // Sonido al cambiar de estatus el servicio.
    final nuevo = context.read<RideProvider>().activeRide?.servicioEstatus;
    final cambioEstado = nuevo != _ultimoEstado;
    if (nuevo != null && cambioEstado) {
      if (_ultimoEstado != null) SoundService.cambioEstatus();
      _ultimoEstado = nuevo;
    }
    if (cambioEstado) {
      _actualizarMapa(forzar: true);
      _cargarRecorrido();
      final s = context.read<RideProvider>().activeRide;
      if (s != null) {
        _cargarPreferencias(s.id);
        _rideRef?.cargarTarifasServicio(s.id);
      }
    }
  }

  @override
  void dispose() {
    _rideRef?.removeListener(_onRideChanged);
    _recorridoTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ─── Ruta en el mapa ──────────────────────────────────────────

  void _actualizarMapa({bool forzar = false}) {
    final s = context.read<RideProvider>().activeRide;
    if (s == null) return;

    final latD = double.tryParse(s.latDestino ?? '');
    final lngD = double.tryParse(s.lngDestino ?? '');
    final latO = double.tryParse(s.latOrigen ?? '');
    final lngO = double.tryParse(s.lngOrigen ?? '');
    if (latO == null || lngO == null) return;

    final origen = LatLng(latO, lngO);
    final destino = (latD != null && lngD != null) ? LatLng(latD, lngD) : null;

    setState(() {
      _markers
        ..clear()
        ..add(Marker(
          markerId: const MarkerId('origen'),
          position: origen,
          icon: MarkerIcons.origin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: 'Origen', snippet: s.direccionOrigen ?? ''),
        ));
      if (destino != null) {
        _markers.add(Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          icon: MarkerIcons.destination ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: 'Destino', snippet: s.direccionDestino ?? ''),
        ));
      }

      _polylines.clear();
      if (s.esEnViaje && _recorrido.length >= 2) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('recorrido_real'),
          points: _recorrido,
          color: VaiaColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      }
    });

    final paso = s.pasoActual;
    if (forzar || _ultimoPasoCamara != paso) {
      _ultimoPasoCamara = paso;
      _ajustar(origen, destino ?? origen);
    }
  }

  Future<void> _cargarRecorrido() async {
    if (!mounted || _cargandoRecorrido) return;
    final rideProv = context.read<RideProvider>();
    final s = rideProv.activeRide;
    if (s == null) return;

    if (!s.esEnViaje) {
      if (_recorrido.isNotEmpty || _recorridoMensaje != null) {
        setState(() {
          _recorrido = const [];
          _recorridoMensaje = null;
        });
        _actualizarMapa();
      }
      return;
    }

    _cargandoRecorrido = true;
    try {
      final res = await rideProv.obtenerRecorrido(s.id);
      if (!mounted) return;
      final recorrido = RecorridoModel.fromRows(res.list);
      final primeraVez = _recorrido.length < 2;
      setState(() {
        _recorrido = recorrido.puntos;
        if (!recorrido.disponible) {
          _recorridoMensaje = recorrido.mensaje ?? 'El recorrido no esta disponible.';
        } else if (recorrido.puntos.length < 2) {
          _recorridoMensaje = recorrido.mensaje ?? 'Aun no hay puntos suficientes del recorrido.';
        } else {
          _recorridoMensaje = null;
        }
      });
      _actualizarMapa(forzar: primeraVez && recorrido.tieneRuta);
    } catch (_) {
      if (mounted) {
        setState(() => _recorridoMensaje = 'No se pudo cargar el recorrido real.');
      }
    } finally {
      _cargandoRecorrido = false;
    }
  }

  void _ajustar(LatLng a, LatLng b) {
    if (_mapCtrl == null) return;
    final puntos = <LatLng>[a, b, ..._recorrido];
    var minLat = puntos.first.latitude, maxLat = puntos.first.latitude;
    var minLng = puntos.first.longitude, maxLng = puntos.first.longitude;
    for (final p in puntos) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
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
            padding: const EdgeInsets.all(12),
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
    _actualizarMapa(forzar: true);
    _cargarRecorrido();
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
      _actualizarMapa(forzar: true);
      _cargarRecorrido();
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
              onMapCreated: (c) {
                _mapCtrl = c;
                _actualizarMapa(forzar: true);
              },
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
          const SizedBox(height: 10),

          _tituloEstatus(s),
          const SizedBox(height: 18),
          StatusTimeline(pasoActual: s.pasoActual, cancelado: s.cancelado, compacto: true),
          const SizedBox(height: 12),

          _tarjetaPasajero(s, isEnViaje),
          const SizedBox(height: 14),
          _tarjetaPreferencias(),
          const SizedBox(height: 14),
          _tarjetaRuta(s),
          if (_recorridoMensaje != null) ...[
            const SizedBox(height: 10),
            _avisoRecorrido(),
          ],
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
                  : const MarkerIcon(origin: true, size: 18),
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
                padding: const EdgeInsets.all(12),
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

          const SizedBox(height: 10),
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
            SlideToConfirm(
              label: 'Desliza para finalizar y cobrar',
              onConfirm: () => _cobrarYFinalizar(ride, s.id, auth.userId),
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


  Future<void> _cargarPreferencias(int idServicio) async {
    if (_cargandoPrefs) return;
    _cargandoPrefs = true;
    try {
      final res = await context.read<RideProvider>().obtenerPreferenciasServicio(idServicio);
      if (!mounted) return;
      if (res.ok && res.list != null && res.list!.isNotEmpty) {
        final p = Map<String, dynamic>.from(res.list!.first as Map);
        final disponible = p['disponible'] == true || p['disponible']?.toString() == '1';
        setState(() => _prefsPasajero = disponible ? p : null);
      }
    } catch (_) {
    } finally {
      _cargandoPrefs = false;
    }
  }

  Widget _tarjetaPreferencias() {
    final p = _prefsPasajero;
    if (p == null) return const SizedBox.shrink();
    bool b(dynamic v) => v == true || v == 1 || v?.toString() == '1';
    final configurado = b(p['configurado']);
    if (!configurado) {
      return _card(
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: VaiaColors.textMuted, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('El pasajero no configuro preferencias para este viaje.',
                  style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    final chips = <Widget>[];
    Widget chip(IconData icon, String text) => Container(
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: VaiaColors.primaryGhost,
            borderRadius: BorderRadius.circular(VaiaRadius.pill),
            border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.22)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: VaiaColors.primary),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VaiaColors.textSecondary)),
          ]),
        );

    chips.add(chip(Icons.music_note_rounded, b(p['musica']) ? 'Con musica' : 'Sin musica'));
    chips.add(chip(Icons.ac_unit_rounded, b(p['aireacondicionado']) ? 'Aire encendido' : 'Aire apagado'));
    if (b(p['ventanasabajo'])) chips.add(chip(Icons.window_rounded, 'Ventanas abajo'));
    if (b(p['viajacomascotas'])) chips.add(chip(Icons.pets_rounded, 'Con mascotas'));
    if (b(p['discapacidadauditiva'])) chips.add(chip(Icons.hearing_disabled_rounded, 'Disc. auditiva'));
    if (b(p['discapacidadvisual'])) chips.add(chip(Icons.visibility_off_rounded, 'Disc. visual'));

    final alergias = (p['alergias'] ?? '').toString().trim();
    final discapacidad = (p['discapacidad'] ?? '').toString().trim();
    final notas = (p['notas'] ?? '').toString().trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: VaiaColors.primary),
              SizedBox(width: 8),
              Text('Preferencias del pasajero',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(children: chips),
          if (alergias.isNotEmpty) _prefDetalle('Alergias', alergias, Icons.warning_amber_rounded),
          if (discapacidad.isNotEmpty) _prefDetalle('Apoyo requerido', discapacidad, Icons.accessible_rounded),
          if (notas.isNotEmpty) _prefDetalle('Indicaciones', notas, Icons.edit_note_rounded),
        ],
      ),
    );
  }

  Widget _prefDetalle(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: VaiaColors.textMuted),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: VaiaColors.textMuted)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: VaiaColors.textSecondary))),
        ],
      ),
    );
  }
  Widget _tarjetaPasajero(Servicio s, bool isEnViaje) {
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: VaiaColors.primaryGhost,
            backgroundImage: providerFoto(s.pasajeroFoto),
            child: (s.pasajeroFoto == null || s.pasajeroFoto!.isEmpty)
                ? Text((s.pasajeroNombreCompleto.trim().isEmpty ? 'P' : s.pasajeroNombreCompleto.trim().substring(0, 1)).toUpperCase(),
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

  Widget _avisoRecorrido() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VaiaColors.primaryGhost,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, size: 17, color: VaiaColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _recorridoMensaje!,
              style: const TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaRuta(Servicio s) {
    return _card(
      child: Column(
        children: [
          RutaTimeline(origen: s.direccionOrigen ?? '-', destino: s.direccionDestino ?? '-'),
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

  Widget _renglonRuta(Widget icon, String label, String valor, {bool activo = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: icon)),
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
    final tarifa = ride.tarifasServicio;
    final tMin = _toDouble(tarifa?['costominimo']);
    final tKm = _toDouble(tarifa?['costoporkm']);
    final tMinuto = _toDouble(tarifa?['costoporminuto']);
    final tieneTarifa = tMin > 0 || tKm > 0 || tMinuto > 0;
    final esProveedor = _esPagoProveedor(s.tipoPago);
    final comision = s.comisionAplicada ?? 0;
    final ganancia = s.gananciaConductor ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: VaiaColors.primaryGradient, borderRadius: BorderRadius.circular(VaiaRadius.lg)),
      child: Column(children: [
        Text(s.esFinalizado ? 'COBRO FINAL DEL SERVICIO' : 'COBRO HASTA EL MOMENTO',
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: monto, end: monto),
          duration: const Duration(milliseconds: 500),
          builder: (_, v, __) => Text('\$${v.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 4),
        Text(
          s.esFinalizado ? 'Monto total cobrado al pasajero' : 'Tarifa dinamica segun distancia y tiempo',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statTarifa(Icons.route_rounded, '${((s.distanciaMetros ?? 0) / 1000).toStringAsFixed(1)} km', 'Recorrido')),
            Expanded(child: _statTarifa(Icons.timer_outlined, _fmtDuracion(s.duracionSegundos), 'Tiempo')),
            Expanded(child: _statTarifa(Icons.account_balance_wallet_outlined, s.tipoPago ?? '--', 'Pago')),
          ],
        ),
        if (tieneTarifa) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statTarifa(Icons.flag_rounded, '\$${tMin.toStringAsFixed(2)}', 'Tarifa minima')),
              Expanded(child: _statTarifa(Icons.speed_rounded, '\$${tKm.toStringAsFixed(2)}', 'Por km')),
              Expanded(child: _statTarifa(Icons.timer_outlined, '\$${tMinuto.toStringAsFixed(2)}', 'Por minuto')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total = tarifa minima + (km x costo por km) + (minutos x costo por minuto).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9.5, height: 1.35, color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
        if (comision > 0 || ganancia > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: _datoCobro('Comision Vaia', '\$${comision.toStringAsFixed(2)}')),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.24)),
                Expanded(child: _datoCobro('Tu ganancia', '\$${ganancia.toStringAsFixed(2)}')),
              ],
            ),
          ),
        ],
        if (esProveedor) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_outlined, size: 15, color: Colors.white),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${s.tipoPago} cobra su propia comision por la transaccion. '
                    'Corresponde al proveedor y no forma parte del cobro de Vaia.',
                    style: TextStyle(fontSize: 10.5, height: 1.4, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _datoCobro(String label, String valor) => Column(
        children: [
          Text(valor, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9.5)),
        ],
      );

  Widget _statTarifa(IconData icon, String value, String label) => Column(
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
        ],
      );

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  bool _esPagoProveedor(String? tipoPago) {
    final t = (tipoPago ?? '').toLowerCase();
    return t.contains('paypal') || t.contains('mercado');
  }

  String _fmtDuracion(int? segundos) {
    final min = ((segundos ?? 0) / 60).ceil();
    if (min <= 0) return '--';
    return min >= 60 ? '${min ~/ 60}h ${min % 60}m' : '$min min';
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
        padding: const EdgeInsets.all(12),
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
