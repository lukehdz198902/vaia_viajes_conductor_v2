import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/soporte_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import 'auth_provider.dart';

class SoporteProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SignalRService _signalr;
  AuthProvider _auth;

  SoporteProvider(this._signalr, this._auth) {
    _subSoporte = _signalr.soporteEventos.listen(_onEvent);
  }

  void updateAuth(AuthProvider auth) => _auth = auth;

  final List<SoporteSolicitudModel> _solicitudes = [];
  final List<SoporteMensajeModel> _mensajes = [];
  SoporteSolicitudModel? _solicitudActiva;
  bool _loading = false;
  bool _enviando = false;
  String? _error;
  StreamSubscription? _subSoporte;

  List<SoporteSolicitudModel> get solicitudes => _solicitudes;
  List<SoporteMensajeModel> get mensajes => _mensajes;
  SoporteSolicitudModel? get solicitudActiva => _solicitudActiva;
  bool get loading => _loading;
  bool get enviando => _enviando;
  String? get error => _error;

  void _onEvent(RealtimeEvent event) {
    if (event.tipo == 'NuevoMensajeSoporte') {
      final idSol = _toInt(event.data['idSolicitud']);
      if (idSol == _solicitudActiva?.id) {
        final emisor = event.data['emisor']?.toString() ?? '';
        if (emisor == 'soporte') {
          _mensajes.add(SoporteMensajeModel(
            id: _toInt(event.data['id'] ?? 0),
            idSolicitud: idSol,
            emisor: emisor,
            idEmisor: event.data['idEmisor'] != null ? _toInt(event.data['idEmisor']) : null,
            nombreEmisor: event.data['nombreEmisor']?.toString(),
            mensaje: event.data['mensaje']?.toString() ?? '',
            fechaCreacion: event.data['fecha']?.toString(),
          ));
          notifyListeners();
        }
      }
    } else if (event.tipo == 'SolicitudActualizada') {
      final idSol = _toInt(event.data['idSolicitud']);
      if (idSol == _solicitudActiva?.id) cargarSolicitud(idSol);
    }
  }

  Future<int?> crearSolicitud({
    required int idServicio,
    required String asunto,
    required String descripcion,
    String prioridad = 'Normal',
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.crearSolicitudSoporte(idServicio, _auth.userId, asunto, descripcion, prioridad: prioridad);
      _loading = false;
      if (res.ok) {
        notifyListeners();
        return res.id > 0 ? res.id : null;
      }
      _error = res.mensaje;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Error de conexion';
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> cargarSolicitud(int idSolicitud) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.obtenerSolicitudSoporte(idSolicitud);
      if (res.ok && res.data != null) {
        _solicitudActiva = SoporteSolicitudModel.fromJson(res.data!);
      }
      await _cargarMensajes(idSolicitud);
      await _signalr.unirseASolicitudSoporte(idSolicitud);
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> _cargarMensajes(int idSolicitud) async {
    final res = await _api.listarMensajesSoporte(idSolicitud);
    _mensajes.clear();
    if (res.ok && res.list != null) {
      for (final item in res.list!) {
        if (item is Map) {
          _mensajes.add(SoporteMensajeModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
  }

  Future<bool> enviarMensaje(String texto) async {
    if (_solicitudActiva == null || texto.trim().isEmpty) return false;
    _enviando = true;
    notifyListeners();
    try {
      final res = await _api.enviarMensajeSoporte(
        _solicitudActiva!.id, 'conductor', _auth.userId, _auth.conductor?.nombreCompleto ?? 'Conductor', texto.trim());
      if (res.ok) {
        _mensajes.add(SoporteMensajeModel(
          id: DateTime.now().millisecondsSinceEpoch,
          idSolicitud: _solicitudActiva!.id,
          emisor: 'conductor',
          idEmisor: _auth.userId,
          nombreEmisor: _auth.conductor?.nombreCompleto,
          mensaje: texto.trim(),
          fechaCreacion: DateTime.now().toIso8601String(),
        ));
        await _signalr.enviarMensajeSoporte(
            _solicitudActiva!.id, _auth.userId, _auth.conductor?.nombreCompleto ?? 'Conductor', texto.trim());
        _enviando = false;
        notifyListeners();
        return true;
      }
      _error = res.mensaje;
    } catch (e) {
      _error = 'Error al enviar';
    }
    _enviando = false;
    notifyListeners();
    return false;
  }

  Future<void> salirDeSolicitud() async {
    if (_solicitudActiva != null) {
      await _signalr.salirDeSolicitudSoporte(_solicitudActiva!.id);
    }
    _solicitudActiva = null;
    _mensajes.clear();
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
    _subSoporte?.cancel();
    super.dispose();
  }
}