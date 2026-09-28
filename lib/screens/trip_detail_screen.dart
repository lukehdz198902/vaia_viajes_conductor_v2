import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/parada_model.dart';
import '../models/servicio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/directions_service.dart';

/// Detalle completo de un servicio para el conductor: mapa con la ruta y las
/// paradas, datos del pasajero, desglose de cobro/comision, conversacion y la
/// calificacion que el propio conductor otorgo (la del pasajero es confidencial).
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _api = ApiService();
  Servicio? _servicio;
  List<ParadaModel> _paradas = [];
  List<Map<String, dynamic>> _mensajes = [];
  bool _loading = true;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _servicio == null) _loadDetail();
  }

  Future<void> _loadDetail() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final servicioId = args?['servicioId'] as int?;
    if (servicioId == null) {
      setState(() => _loading = false);
      return;
    }
    final auth = context.read<AuthProvider>();
    final s = await context.read<RideProvider>().getDetail(servicioId, auth.userId);

    List<ParadaModel> paradas = [];
    List<Map<String, dynamic>> mensajes = [];
    try {
      final rp = await _api.listarParadas(servicioId);
      if (rp.ok && rp.list != null) {
        paradas = rp.list!.map((e) => ParadaModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    try {
      final rm = await _api.listarMensajes(servicioId);
      if (rm.ok && rm.list != null) {
        mensajes = rm.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _servicio = s;
      _paradas = paradas;
      _mensajes = mensajes;
      _loading = false;
    });
    _construirMapa(s, paradas);
  }

  Future<void> _construirMapa(Servicio? s, List<ParadaModel> paradas) async {
    if (s == null) return;
    final latO = double.tryParse(s.latOrigen ?? '');
    final lngO = double.tryParse(s.lngOrigen ?? '');
    final latD = double.tryParse(s.latDestino ?? '');
    final lngD = double.tryParse(s.lngDestino ?? '');
    if (latO == null || lngO == null) return;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(latO, lngO),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Origen', snippet: s.direccionOrigen ?? ''),
      ),
    };
    if (latD != null && lngD != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(latD, lngD),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: 'Destino', snippet: s.direccionDestino ?? ''),
      ));
    }
    for (var i = 0; i < paradas.length; i++) {
      final p = paradas[i];
      final lat = double.tryParse(p.lat);
      final lng = double.tryParse(p.lng);
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        markerId: MarkerId('parada_${p.id}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: 'Parada ${p.orden}', snippet: p.direccion),
      ));
    }
    if (mounted) setState(() => _markers..clear()..addAll(markers));

    if (latD == null || lngD == null) return;
    final puntosParadas = paradas
        .map((p) => (double.tryParse(p.lat), double.tryParse(p.lng)))
        .where((e) => e.$1 != null && e.$2 != null)
        .map((e) => LatLng(e.$1!, e.$2!))
        .toList();
    final ruta = await DirectionsService.ruta(
      origen: LatLng(latO, lngO),
      destino: LatLng(latD, lngD),
      paradas: puntosParadas,
    );
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

  @override
  Widget build(BuildContext context) {
    final s = _servicio;
    return Scaffold(
      appBar: AppBar(title: Text(s != null ? 'Servicio #${s.id}' : 'Detalle del viaje')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? const Center(child: Text('No se pudo cargar el detalle'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _mapa(s),
                    const SizedBox(height: 12),
                    _encabezado(s),
                    const SizedBox(height: 12),
                    _ruta(s),
                    const SizedBox(height: 12),
                    _pasajero(s),
                    const SizedBox(height: 12),
                    _finanzas(s),
                    const SizedBox(height: 12),
                    if ((s.calificacionPasajero ?? 0) > 0) ...[_miCalificacion(s), const SizedBox(height: 12)],
                    _info(s),
                    const SizedBox(height: 12),
                    if (_paradas.isNotEmpty) ...[_paradasCard(), const SizedBox(height: 12)],
                    _conversacion(),
                    const SizedBox(height: 20),
                  ],
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

  Widget _titulo(IconData icon, String texto, {Color color = VaiaColors.primary}) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary))),
        ],
      );

  Widget _mapa(Servicio s) {
    final latO = double.tryParse(s.latOrigen ?? '');
    final lngO = double.tryParse(s.lngOrigen ?? '');
    if (latO == null || lngO == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(VaiaRadius.lg),
      child: SizedBox(
        height: 200,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(latO, lngO), zoom: 13),
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
        ),
      ),
    );
  }

  Widget _encabezado(Servicio s) {
    final color = _statusColor(s.servicioEstatus);
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Servicio #${s.id}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                const SizedBox(height: 3),
                Text(_fecha(s.fechaCreacion), style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(s.servicioEstatus ?? '--', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? estatus) {
    final e = (estatus ?? '').toLowerCase();
    if (e.contains('finaliz') || e.contains('pagad')) return VaiaColors.success;
    if (e.contains('cancel')) return VaiaColors.danger;
    if (e.contains('camino')) return VaiaColors.primary;
    return VaiaColors.textMuted;
  }

  Widget _ruta(Servicio s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.route_rounded, 'Recorrido'),
            const SizedBox(height: 12),
            _dirRow(Icons.trip_origin, VaiaColors.onlineGreen, 'Origen', s.direccionOrigen ?? '-'),
            Padding(padding: const EdgeInsets.only(left: 5), child: Container(width: 2, height: 16, color: VaiaColors.border)),
            _dirRow(Icons.location_on_rounded, VaiaColors.danger, 'Destino', s.direccionDestino ?? '-'),
          ],
        ),
      );

  Widget _dirRow(IconData icon, Color color, String label, String valor) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: VaiaColors.textMuted, letterSpacing: 0.4)),
                Text(valor, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary)),
              ],
            ),
          ),
        ],
      );

  Widget _pasajero(Servicio s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.person_rounded, 'Pasajero'),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: VaiaColors.primaryGhost,
                  backgroundImage: (s.pasajeroFoto != null && s.pasajeroFoto!.isNotEmpty) ? NetworkImage(s.pasajeroFoto!) : null,
                  child: (s.pasajeroFoto == null || s.pasajeroFoto!.isEmpty)
                      ? Text(s.pasajeroNombreCompleto.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: VaiaColors.primary))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.pasajeroNombreCompleto, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                      if ((s.pasajeroCalificacion ?? 0) > 0)
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 15, color: VaiaColors.accent),
                          const SizedBox(width: 3),
                          Text(s.pasajeroCalificacion!.toStringAsFixed(1), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          if ((s.pasajeroTotalViajes ?? 0) > 0)
                            Text('  -  ${s.pasajeroTotalViajes} viajes', style: const TextStyle(fontSize: 12, color: VaiaColors.textSecondary)),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _finanzas(Servicio s) {
    final cobrado = (s.costoFinal ?? 0) > 0 ? s.costoFinal! : (s.costoEstimado ?? 0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(Icons.receipt_long_rounded, 'Resumen de cobro'),
          const SizedBox(height: 12),
          _fila('Costo estimado', '\$${(s.costoEstimado ?? 0).toStringAsFixed(2)}'),
          if ((s.costoEnCurso ?? 0) > 0) _fila('Costo en curso', '\$${s.costoEnCurso!.toStringAsFixed(2)}'),
          _fila('Total cobrado', '\$${cobrado.toStringAsFixed(2)}'),
          const Divider(height: 20),
          _fila('Tu ganancia', '\$${(s.gananciaConductor ?? 0).toStringAsFixed(2)}', color: VaiaColors.success),
          _fila('Comision', '-\$${(s.comisionAplicada ?? 0).toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _fila('Forma de pago', s.tipoPago ?? '--'),
        ],
      ),
    );
  }

  Widget _miCalificacion(Servicio s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.star_rounded, 'Calificacion que otorgaste', color: VaiaColors.accent),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) => Icon(
                    i < (s.calificacionPasajero ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 26,
                    color: i < (s.calificacionPasajero ?? 0) ? VaiaColors.accent : VaiaColors.borderStrong,
                  )),
            ),
          ],
        ),
      );

  Widget _info(Servicio s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.info_outline_rounded, 'Informacion del viaje'),
            const SizedBox(height: 12),
            _infoRow(Icons.straighten_rounded, 'Distancia', '${((s.distanciaMetros ?? 0) / 1000).toStringAsFixed(1)} km'),
            const SizedBox(height: 8),
            _infoRow(Icons.access_time_rounded, 'Duracion', _duracion(s.duracionSegundos)),
            const SizedBox(height: 8),
            _infoRow(Icons.local_taxi_rounded, 'Tipo', s.tipoViaje ?? '--'),
            const SizedBox(height: 8),
            _infoRow(Icons.event_available_rounded, 'Iniciado', _fecha(s.fechaServicioIniciado)),
            const SizedBox(height: 8),
            _infoRow(Icons.flag_rounded, 'Finalizado', _fecha(s.fechaLlegoDestino)),
          ],
        ),
      );

  Widget _paradasCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.alt_route_rounded, 'Paradas (${_paradas.where((p) => p.completada).length}/${_paradas.length})', color: VaiaColors.accent),
            const SizedBox(height: 10),
            ..._paradas.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(p.completada ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          size: 17, color: p.completada ? VaiaColors.success : VaiaColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${p.orden}. ${p.direccion}',
                            style: TextStyle(
                              fontSize: 12.5,
                              decoration: p.completada ? TextDecoration.lineThrough : null,
                              color: p.completada ? VaiaColors.textMuted : VaiaColors.textPrimary,
                            )),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );

  Widget _conversacion() {
    if (_mensajes.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(Icons.chat_bubble_rounded, 'Conversacion (${_mensajes.length})'),
          const SizedBox(height: 12),
          ..._mensajes.map((m) {
            final esMio = m['desdeappconductor'] == true || m['desdeappconductor']?.toString() == '1' || m['desdeappconductor']?.toString() == 'true';
            return Align(
              alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: esMio ? VaiaColors.primary : VaiaColors.bgSubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['mensaje']?.toString() ?? '', style: TextStyle(fontSize: 13, color: esMio ? Colors.white : VaiaColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(_hora(m['fechacreacion']), style: TextStyle(fontSize: 9.5, color: esMio ? Colors.white70 : VaiaColors.textMuted)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
            Text(valor, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color ?? VaiaColors.textPrimary)),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: VaiaColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary)),
        ],
      );

  String _fecha(String? iso) {
    if (iso == null || iso.isEmpty) return '--';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--';
    }
  }

  String _hora(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _duracion(int? seg) {
    if (seg == null || seg <= 0) return '--';
    final min = (seg / 60).round();
    if (min < 60) return '$min min';
    return '${(min / 60).floor()}h ${min % 60}min';
  }
}
