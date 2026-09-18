import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/servicio_model.dart';
import '../models/parada_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../services/foreground_service.dart';
import '../services/bubble_overlay.dart';

class RideProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SignalRService _signalr;

  RideProvider(this._signalr) {
    _subEventos = _signalr.eventos.listen(_onRealtimeEvent);
    _subConexion = _signalr.estadoConexion.listen((c) {
      _conectadoWs = c;
      notifyListeners();
      _actualizarNotificacion();
    });
  }

  Servicio? _activeRide;
  Servicio? _servicioOfrecido; // solicitud entrante para aceptar/rechazar
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _presenceTimer;
  Timer? _latidoTimer;
  int _idConductorPresencia = 0;
  int _idServicioGps = 0;
  // Taximetro
  bool _taxiActivo = false;
  double _distanciaTaxi = 0;
  double? _ultLatTaxi;
  double? _ultLngTaxi;
  DateTime? _inicioViajeTaxi;
  double? _costoEnCurso;
  DateTime? _ultimaUbicacion;
  bool _hasNewRequest = false;
  List<Servicio> _history = [];
  final List<ParadaModel> _paradas = [];
  bool _conectadoWs = false;
  StreamSubscription? _subEventos;
  StreamSubscription? _subConexion;

  Servicio? get activeRide => _activeRide;
  Servicio? get servicioOfrecido => _servicioOfrecido;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasNewRequest => _hasNewRequest;
  List<Servicio> get history => _history;
  List<ParadaModel> get paradas => _paradas;
  bool get conectadoWs => _conectadoWs;
  double? get costoEnCurso => _costoEnCurso;
  DateTime? get ultimaUbicacion => _ultimaUbicacion;

  // ─── SIGNALR ─────────────────────────────────────────────────

  void _onRealtimeEvent(RealtimeEvent event) {
    switch (event.tipo) {
      case 'NuevoServicio':
      case 'ServicioAsignado':
        // Solicitud entrante para este conductor
        final idServicio = _toInt(event.data['idServicio'] ?? event.data['idservicio']);
        if (idServicio > 0 && (_activeRide == null || _activeRide!.id != idServicio)) {
          _servicioOfrecido = Servicio.fromJson({
            'id': idServicio,
            'idpasajero': event.data['idPasajero'],
            'direccionorigen': event.data['direccionOrigen'] ?? event.data['direccionorigen'] ?? '',
            'latorigen': event.data['latOrigen'] ?? '',
            'lngorigen': event.data['lngOrigen'] ?? '',
            'direcciondestination': event.data['direccionDestino'] ?? '',
            'latdestination': event.data['latDestino'] ?? '',
            'lngdestination': event.data['lngDestino'] ?? '',
            'costoestimado': event.data['costoEstimado'] ?? 0,
            'distanciametros': event.data['distanciaMetros'] ?? 0,
            'segundosparatomar': event.data['segundosParaTomar'] ?? event.data['segundosparatomar'] ?? 30,
            'servicioEstatus': 'Solicitado',
          });
          _hasNewRequest = true;
          notifyListeners();
        }
        break;
      case 'EstatusCambiado':
        final estatus = event.data['estatus']?.toString();
        if (estatus != null && _activeRide != null &&
            estatus != 'ParadaAgregada' && estatus != 'ParadaCompletada') {
          _activeRide = Servicio.fromJson({
            ..._activeRide!.toMap(),
            'servicioEstatus': estatus,
          });
          notifyListeners();
        }
        break;
      case 'ServicioCancelado':
        _activeRide = null;
        _servicioOfrecido = null;
        _hasNewRequest = false;
        _paradas.clear();
        _stopGps();
        notifyListeners();
        break;
    }
  }

  // ─── POLLING (RESPALDO) ──────────────────────────────────────

  void startPolling(int conductorId) {
    _pollTimer?.cancel();
    final intervalo = _conectadoWs ? const Duration(seconds: 20) : const Duration(seconds: 10);
    _pollTimer = Timer.periodic(intervalo, (_) => _checkActiveRide(conductorId));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkActiveRide(int conductorId) async {
    final resp = await _api.obtenerServicioActivo(conductorId);
    if (resp.ok && resp.data != null && resp.data!.isNotEmpty) {
      final servicio = Servicio.fromJson(resp.data!);
      final esNuevo = _activeRide?.id != servicio.id;
      _activeRide = servicio;
      if (esNuevo) {
        _hasNewRequest = true;
        await _signalr.unirseAServicio(servicio.id);
        await listarParadas(servicio.id);
        _startGps(servicio.id, conductorId);
      }
      notifyListeners();
    } else if (resp.ok) {
      if (_activeRide != null) {
        _activeRide = null;
        _paradas.clear();
        _stopGps();
        notifyListeners();
      }
    }
  }

  // ─── PRESENCIA Y GPS ─────────────────────────────────────────
  //
  // El conductor reporta su ubicacion SIEMPRE que esta conectado
  // (disponible o en viaje) y envia un latido para que el sistema
  // sepa que sigue activo. Se usa WebSocket si esta conectado; si no,
  // la API REST como respaldo. La persistencia ocurre en el servidor.

  /// Inicia el reporte continuo de ubicacion y el latido (heartbeat).
  void iniciarPresencia(int conductorId) {
    if (conductorId <= 0) return;
    if (_idConductorPresencia == conductorId && _presenceTimer != null) return;

    _idConductorPresencia = conductorId;
    _latidoTimer?.cancel();

    _reportarPresencia();
    _signalr.latido();

    _reiniciarTimerPresencia();
    _latidoTimer = Timer.periodic(const Duration(seconds: 30), (_) => _signalr.latido());

    // Servicio en primer plano: mantiene la app viva al minimizar/cerrar
    // y muestra el estado de conexion y la ultima ubicacion enviada.
    ForegroundServiceManager.iniciar(
      titulo: 'Vaia Conductor - En servicio',
      texto: _textoNotificacion(),
    );
    _prepararBurbuja();
  }

  /// Verifica el permiso de overlay y muestra la burbuja flotante.
  Future<void> _prepararBurbuja() async {
    try {
      final ok = await BubbleOverlay.tienePermiso();
      if (!ok) {
        await BubbleOverlay.solicitarPermiso();
        return;
      }
      await BubbleOverlay.mostrar(conectado: _conectadoWs, ultima: _horaActual());
    } catch (_) {}
  }

  /// Ajusta la frecuencia de reporte segun el estado: en viaje 12 s
  /// (seguimiento preciso), disponible 30 s (menor carga al servidor).
  void _reiniciarTimerPresencia() {
    _presenceTimer?.cancel();
    if (_idConductorPresencia <= 0) return;
    final segundos = _idServicioGps > 0 ? 12 : 30;
    _presenceTimer = Timer.periodic(Duration(seconds: segundos), (_) => _reportarPresencia());
  }

  /// Detiene el reporte de ubicacion y el latido (al cerrar sesion).
  void detenerPresencia() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _latidoTimer?.cancel();
    _latidoTimer = null;
    _idConductorPresencia = 0;
    _idServicioGps = 0;
    ForegroundServiceManager.detener();
    BubbleOverlay.ocultar();
  }

  Future<void> _reportarPresencia() async {
    if (_idConductorPresencia <= 0) return;
    try {
      final enViaje = _idServicioGps > 0;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: enViaje ? LocationAccuracy.high : LocationAccuracy.medium,
        ),
      );
      if (_conectadoWs) {
        await _signalr.reportarUbicacion(pos.latitude, pos.longitude,
            idServicio: enViaje ? _idServicioGps : null);
      } else {
        await _api.actualizarUbicacion(
            _idConductorPresencia, pos.latitude.toString(), pos.longitude.toString());
      }
      _ultimaUbicacion = DateTime.now();
      _actualizarNotificacion();
      if (_taxiActivo) await _reportarTaximetro(pos);
    } catch (_) {}
  }

  // ─── NOTIFICACION DE ESTADO (servicio en primer plano) ───────

  String _textoNotificacion() {
    final estado = _conectadoWs ? '\u{1F7E2} Conectado' : '\u{26AA} Sin conexion';
    final ult = _ultimaUbicacion != null
        ? 'Ultima ubicacion: ${_hora(_ultimaUbicacion!)}'
        : 'Sin ubicacion enviada';
    return '$estado  -  $ult';
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  String _horaActual() =>
      _ultimaUbicacion != null ? _hora(_ultimaUbicacion!) : '--:--:--';

  void _actualizarNotificacion() {
    if (_presenceTimer == null) return;
    ForegroundServiceManager.actualizar(
      titulo: 'Vaia Conductor - En servicio',
      texto: _textoNotificacion(),
    );
    // Actualiza la burbuja flotante (si el permiso esta concedido)
    BubbleOverlay.mostrar(conectado: _conectadoWs, ultima: _horaActual());
  }

  // ─── TAXIMETRO ───────────────────────────────────────────────

  void iniciarTaximetro() {
    _taxiActivo = true;
    _distanciaTaxi = 0;
    _ultLatTaxi = null;
    _ultLngTaxi = null;
    _inicioViajeTaxi = DateTime.now();
    _costoEnCurso = null;
    notifyListeners();
  }

  void detenerTaximetro() {
    _taxiActivo = false;
    _inicioViajeTaxi = null;
  }

  Future<void> _reportarTaximetro(Position pos) async {
    if (!_taxiActivo || _idServicioGps <= 0 || _inicioViajeTaxi == null) return;
    if (_ultLatTaxi != null && _ultLngTaxi != null) {
      final d = Geolocator.distanceBetween(_ultLatTaxi!, _ultLngTaxi!, pos.latitude, pos.longitude);
      if (d > 3 && d < 500) _distanciaTaxi += d;
    }
    _ultLatTaxi = pos.latitude;
    _ultLngTaxi = pos.longitude;
    final dur = DateTime.now().difference(_inicioViajeTaxi!).inSeconds;
    try {
      final resp = await _api.actualizarTaximetro(
          _idServicioGps, _idConductorPresencia, _distanciaTaxi.round(), dur);
      if (resp.ok && resp.data != null && resp.data!['costo'] != null) {
        _costoEnCurso = double.tryParse(resp.data!['costo'].toString());
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> registrarPago(int servicioId, int conductorId, double monto,
      {String metodo = 'CASH'}) async {
    try {
      final resp = await _api.registrarPago(servicioId, conductorId, monto, metodo: metodo);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  void _startGps(int idServicio, [int? idConductor]) {
    _idServicioGps = idServicio;
    if (idConductor != null && idConductor > 0) _idConductorPresencia = idConductor;
    if (_presenceTimer == null && _idConductorPresencia > 0) {
      iniciarPresencia(_idConductorPresencia);
    } else {
      _reiniciarTimerPresencia();
    }
  }

  void _stopGps() {
    _idServicioGps = 0;
    _reiniciarTimerPresencia();
  }

  // ─── ACCIONES DEL SERVICIO ───────────────────────────────────

  Future<bool> acceptRide(int servicioId, int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.aceptarServicio(servicioId, conductorId);
    _loading = false;
    if (resp.ok && resp.data != null) {
      _activeRide = Servicio.fromJson(resp.data!);
      _servicioOfrecido = null;
      _hasNewRequest = false;
      await _signalr.unirseAServicio(servicioId);
      await listarParadas(servicioId);
      _startGps(servicioId, conductorId);
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> rejectRide(int servicioId, int conductorId, {String? motivo}) async {
    _loading = true; notifyListeners();
    final resp = await _api.rechazarServicio(servicioId, conductorId, motivo: motivo);
    _loading = false;
    if (resp.ok) {
      _servicioOfrecido = null;
      _hasNewRequest = false;
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> llegarAlOrigen(int servicioId, int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.llegarAlOrigen(servicioId, conductorId);
    _loading = false;
    if (resp.ok) {
      if (_activeRide != null) {
        _activeRide = Servicio.fromJson({..._activeRide!.toMap(), 'servicioEstatus': 'Llego al Origen', 'llegoalorigen': true});
      }
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Error');
    notifyListeners();
    return false;
  }

  Future<bool> startTrip(int servicioId, int conductorId, String codigoInicio) async {
    _loading = true; notifyListeners();
    final resp = await _api.iniciarViaje(servicioId, conductorId, codigoInicio);
    _loading = false;
    if (resp.ok) {
      if (resp.data != null && resp.data!.isNotEmpty) {
        _activeRide = Servicio.fromJson(resp.data!);
      } else if (_activeRide != null) {
        _activeRide = Servicio.fromJson({
          ..._activeRide!.toMap(),
          'servicioEstatus': 'En Viaje',
          'servicioiniciado': true,
        });
      }
      iniciarTaximetro();
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Codigo de inicio invalido');
    notifyListeners();
    return false;
  }

  Future<bool> finishTrip(int servicioId, int conductorId,
      {double? costoFinal, String? lat, String? lng, int? rdM, int? rdS}) async {
    _loading = true; notifyListeners();
    final resp = await _api.finalizarViaje(servicioId, conductorId,
        costoFinal: costoFinal, lat: lat, lng: lng, rdM: rdM, rdS: rdS);
    _loading = false;
    if (resp.ok) {
      await _signalr.salirDeServicio(servicioId);
      _stopGps();
      detenerTaximetro();
      _activeRide = null;
      _paradas.clear();
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Error al finalizar');
    notifyListeners();
    return false;
  }

  Future<bool> calificarPasajero(int servicioId, int conductorId, int calificacion, {String? comentarios}) async {
    try {
      final resp = await _api.calificarPasajero(servicioId, conductorId, calificacion, comentarios: comentarios);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  // ─── PARADAS ─────────────────────────────────────────────────

  Future<void> listarParadas(int idServicio) async {
    try {
      final resp = await _api.listarParadas(idServicio);
      _paradas.clear();
      if (resp.ok && resp.list != null) {
        for (final item in resp.list!) {
          if (item is Map) {
            _paradas.add(ParadaModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> completarParada(int idParada) async {
    final conductorId = _activeRide?.idConductor ?? 0;
    try {
      final resp = await _api.completarParada(idParada, conductorId);
      if (resp.ok && _activeRide != null) {
        await listarParadas(_activeRide!.id);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── HISTORIAL ───────────────────────────────────────────────

  Future<void> loadHistory(int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.historialViajes(conductorId);
    if (resp.ok && resp.list != null) {
      _history = resp.list!.map((e) => Servicio.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    _loading = false; notifyListeners();
  }

  Future<Servicio?> getDetail(int servicioId, int conductorId) async {
    final resp = await _api.detalleViaje(servicioId, conductorId);
    if (resp.ok && resp.data != null) {
      return Servicio.fromJson(resp.data!);
    }
    return null;
  }

  void clearServicioOfrecido() {
    _servicioOfrecido = null;
    _hasNewRequest = false;
    notifyListeners();
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    stopPolling();
    detenerPresencia();
    _subEventos?.cancel();
    _subConexion?.cancel();
    super.dispose();
  }
}