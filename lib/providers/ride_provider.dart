import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/servicio_model.dart';
import '../models/parada_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';

class RideProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SignalRService _signalr;

  RideProvider(this._signalr) {
    _subEventos = _signalr.eventos.listen(_onRealtimeEvent);
    _subConexion = _signalr.estadoConexion.listen((c) {
      _conectadoWs = c;
      notifyListeners();
    });
  }

  Servicio? _activeRide;
  Servicio? _servicioOfrecido; // solicitud entrante para aceptar/rechazar
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _gpsTimer;
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
        _startGps(servicio.id);
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

  // ─── GPS ─────────────────────────────────────────────────────

  void _startGps(int idServicio) {
    _gpsTimer?.cancel();
    _reportarUbicacion(idServicio);
    _gpsTimer = Timer.periodic(const Duration(seconds: 12), (_) => _reportarUbicacion(idServicio));
  }

  void _stopGps() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  Future<void> _reportarUbicacion(int idServicio) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      // Actualizar en BD
      await _api.actualizarUbicacion(_activeRide?.idConductor ?? 0, pos.latitude.toString(), pos.longitude.toString());
      // Emitir por WebSocket
      await _signalr.reportarUbicacion(pos.latitude, pos.longitude, idServicio: idServicio);
    } catch (_) {}
  }

  /// Reporte manual de ubicacion (cuando el conductor esta disponible).
  Future<void> reportarUbicacionDisponible(int idConductor) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _api.actualizarUbicacion(idConductor, pos.latitude.toString(), pos.longitude.toString());
      await _signalr.reportarUbicacion(pos.latitude, pos.longitude);
    } catch (_) {}
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
      _startGps(servicioId);
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
    _stopGps();
    _subEventos?.cancel();
    _subConexion?.cancel();
    super.dispose();
  }
}