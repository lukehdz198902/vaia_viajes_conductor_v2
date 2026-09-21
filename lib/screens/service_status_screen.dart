import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/directions_service.dart';
import '../widgets/vaia_widgets.dart';
import 'report_incident_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ride = context.read<RideProvider>();
      final s = ride.activeRide;
      if (s != null) {
        ride.listarParadas(s.id);
        _trazarRuta();
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Dibuja la ruta segun el estado: hacia el origen o hacia el destino.
  Future<void> _trazarRuta() async {
    if (_trazando) return;
    final ride = context.read<RideProvider>();
    final s = ride.activeRide;
    if (s == null) return;

    final latD = double.tryParse(s.latDestino ?? '');
    final lngD = double.tryParse(s.lngDestino ?? '');
    final latO = double.tryParse(s.latOrigen ?? '');
    final lngO = double.tryParse(s.lngOrigen ?? '');
    if (latD == null || lngD == null || latO == null || lngO == null) return;

    final origen = LatLng(latO, lngO);
    final destino = LatLng(latD, lngD);
    final enViaje = (s.servicioEstatus ?? '') == 'En Viaje';

    final inicio = origen;
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

    _trazando = true;
    final ruta = await DirectionsService.ruta(origen: inicio, destino: fin);
    _trazando = false;
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
      });
    }
    _ajustar(inicio, fin);
  }

  void _ajustar(LatLng a, LatLng b) {
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

  /// Abre la navegacion en Google Maps o Waze hacia [destino].
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
    try {
      await launchUrl(Uri.parse('tel:$telefono'));
    } catch (_) {}
  }

  Future<void> _llegarAlOrigen(RideProvider ride, int servicioId, int conductorId) async {
    setState(() => _isLlegando = true);
    await ride.llegarAlOrigen(servicioId, conductorId);
    if (!mounted) return;
    setState(() => _isLlegando = false);
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

  /// Cobro: muestra el corte por tarifa dinamica y exige recapturar el monto
  /// recibido en efectivo (debe coincidir con el total).
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
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar y finalizar')),
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

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.activeRide;
    final estatus = s?.servicioEstatus ?? '';
    final isLlegoOrigen = estatus == 'Llego al Origen';
    final isEnViaje = estatus == 'En Viaje';

    if (s == null) {
      return const Scaffold(body: Center(child: Text('Viaje finalizado')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnViaje ? 'En viaje' : (isLlegoOrigen ? 'En el origen' : 'En camino')),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ─── Mapa ────────────────────────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.30,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(double.tryParse(s.latOrigen ?? '') ?? 26.0923,
                    double.tryParse(s.lngOrigen ?? '') ?? -98.2789),
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
            ),
          ),

          // ─── Panel ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pasajero
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: VaiaColors.surface,
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                      border: Border.all(color: VaiaColors.border),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: VaiaColors.primaryGhost,
                        child: Text((s.pasajeroNombre ?? 'P')[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: VaiaColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.pasajeroNombre ?? 'Pasajero',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          Text(s.pasajeroTelefono ?? '',
                              style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5)),
                        ]),
                      ),
                      // Llamada y mensaje: solo antes de iniciar el viaje.
                      if (!isEnViaje) ...[
                        IconButton(
                          onPressed: () => _llamar(s.pasajeroTelefono ?? ''),
                          icon: const Icon(Icons.phone_rounded, color: VaiaColors.onlineGreen),
                          tooltip: 'Llamar',
                        ),
                        IconButton(
                          onPressed: () => Navigator.pushNamed(context, '/chat',
                              arguments: {'idServicio': s.id, 'conductorNombre': s.pasajeroNombre}),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: VaiaColors.primary),
                          tooltip: 'Mensaje',
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Recorrido
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VaiaColors.surface,
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                      border: Border.all(color: VaiaColors.border),
                    ),
                    child: Column(children: [
                      _paso(Icons.trip_origin, VaiaColors.onlineGreen, 'Origen', s.direccionOrigen ?? '-',
                          activo: !isEnViaje),
                      Padding(
                        padding: const EdgeInsets.only(left: 11),
                        child: Container(width: 2, height: 16, color: VaiaColors.border),
                      ),
                      _paso(Icons.location_on_rounded, VaiaColors.danger, 'Destino', s.direccionDestino ?? '-',
                          activo: isEnViaje),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Navegacion
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final lat = double.tryParse(isEnViaje ? (s.latDestino ?? '') : (s.latOrigen ?? ''));
                          final lng = double.tryParse(isEnViaje ? (s.lngDestino ?? '') : (s.lngOrigen ?? ''));
                          if (lat != null && lng != null) {
                            _mostrarOpcionesNavegacion(
                                isEnViaje ? 'Ir al destino' : 'Ir por el pasajero', lat, lng);
                          }
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: Text(isEnViaje ? 'Ir al destino' : 'Ir al origen'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                      ),
                    ),
                  ]),

                  // Llegue al origen
                  if (!isEnViaje && !isLlegoOrigen) ...[
                    const SizedBox(height: 10),
                    VaiaPrimaryButton(
                      label: 'Llegue al origen',
                      icon: Icons.place_rounded,
                      loading: _isLlegando,
                      onPressed: _isLlegando ? null : () => _llegarAlOrigen(ride, s.id, auth.userId),
                    ),
                  ],

                  // Codigo de inicio
                  if (isLlegoOrigen && !isEnViaje) ...[
                    const SizedBox(height: 12),
                    if (!_showCodeInput)
                      VaiaPrimaryButton(
                        label: 'Ingresar codigo de inicio',
                        icon: Icons.password_rounded,
                        onPressed: () => setState(() => _showCodeInput = true),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: VaiaColors.primaryGhost,
                          borderRadius: BorderRadius.circular(VaiaRadius.md),
                        ),
                        child: Column(children: [
                          const Text('Pide al pasajero su codigo de inicio',
                              style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                            decoration: const InputDecoration(hintText: '000000', counterText: ''),
                            onSubmitted: (_) => _iniciarViaje(ride, s.id, auth.userId),
                          ),
                          const SizedBox(height: 10),
                          VaiaPrimaryButton(
                            label: 'Iniciar viaje',
                            icon: Icons.play_arrow_rounded,
                            loading: _isStarting,
                            onPressed: _isStarting ? null : () => _iniciarViaje(ride, s.id, auth.userId),
                          ),
                        ]),
                      ),
                  ],

                  // Taximetro
                  if (isEnViaje) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: VaiaColors.primaryGradient,
                        borderRadius: BorderRadius.circular(VaiaRadius.lg),
                      ),
                      child: Column(children: [
                        const Text('Cobro hasta el momento (tarifa dinamica)',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('\$${(ride.costoEnCurso ?? s.costoEstimado ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],

                  // Paradas
                  if (ride.paradas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: VaiaColors.surface,
                        borderRadius: BorderRadius.circular(VaiaRadius.md),
                        border: Border.all(color: VaiaColors.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Paradas (${ride.paradas.where((p) => p.completada).length}/${ride.paradas.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 8),
                        ...ride.paradas.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Icon(p.completada ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: p.completada ? VaiaColors.success : VaiaColors.textMuted),
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
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Soporte + SOS
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/support_chat',
                            arguments: {'idServicio': s.id}),
                        icon: const Icon(Icons.support_agent_rounded, size: 18),
                        label: const Text('Soporte'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _SosButton(onActivar: () => _activarSos(ride, s.id, auth.userId))),
                  ]),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ReportIncidentScreen(idServicio: s.id))),
                    icon: const Icon(Icons.report_problem_outlined, size: 18, color: VaiaColors.warning),
                    label: const Text('Reportar incidente', style: TextStyle(color: VaiaColors.warning)),
                  ),

                  // Cobrar
                  if (isEnViaje) ...[
                    const SizedBox(height: 8),
                    VaiaPrimaryButton(
                      label: 'Finalizar y cobrar',
                      icon: Icons.payments_rounded,
                      onPressed: () => _cobrarYFinalizar(ride, s.id, auth.userId),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activarSos(RideProvider ride, int servicioId, int conductorId) async {
    final ok = await ride.activarSOS(servicioId, conductorId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Alerta SOS enviada a los administradores' : 'No se pudo enviar la alerta'),
      backgroundColor: ok ? VaiaColors.danger : VaiaColors.warning,
    ));
  }

  Widget _paso(IconData icono, Color color, String label, String valor, {bool activo = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted, fontWeight: FontWeight.w700)),
          Text(valor,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: activo ? VaiaColors.textPrimary : VaiaColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

/// Boton SOS: exige mantener presionado 3 segundos para activar la alerta.
class _SosButton extends StatefulWidget {
  final Future<void> Function() onActivar;
  const _SosButton({required this.onActivar});
  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  Timer? _timer;
  double _progreso = 0;
  bool _activado = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciar() {
    if (_activado) return;
    _timer?.cancel();
    _progreso = 0;
    const pasos = 30; // 3 s en pasos de 100 ms
    var i = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      setState(() => _progreso = i / pasos);
      if (i >= pasos) {
        t.cancel();
        setState(() => _activado = true);
        widget.onActivar().whenComplete(() {
          if (mounted) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() { _activado = false; _progreso = 0; });
            });
          }
        });
      }
    });
  }

  void _cancelar() {
    _timer?.cancel();
    if (!_activado) setState(() => _progreso = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _iniciar(),
      onTapUp: (_) => _cancelar(),
      onTapCancel: _cancelar,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _activado ? VaiaColors.danger : VaiaColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          border: Border.all(color: VaiaColors.danger, width: 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_progreso > 0 && !_activado)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progreso,
                  child: Container(
                    decoration: BoxDecoration(
                      color: VaiaColors.danger.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                    ),
                  ),
                ),
              ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_activado ? Icons.check_circle_rounded : Icons.sos_rounded,
                  size: 18, color: _activado ? Colors.white : VaiaColors.danger),
              const SizedBox(width: 8),
              Text(
                _activado ? 'Alerta enviada' : 'Mantener 3s',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _activado ? Colors.white : VaiaColors.danger,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
