import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SignalRService _signalr;

  ChatProvider(this._signalr) {
    _subChat = _signalr.chatEventos.listen((event) {
      if (event.tipo == 'NuevoMensaje') {
        final idServicio = _toInt(event.data['idServicio']);
        if (idServicio != _idServicioActivo) return;
        final emisor = event.data['emisor']?.toString() ?? '';
        // Solo agregar los del pasajero (los del conductor ya se agregan localmente)
        if (emisor == 'pasajero') {
          _messages.add(MensajeChat.fromJson({
            'id': event.data['id'] ?? DateTime.now().millisecondsSinceEpoch,
            'idservicio': idServicio,
            'mensaje': event.data['mensaje'] ?? '',
            'desdeapppasajero': true,
            'fechacreacion': event.data['fecha'],
          }));
          notifyListeners();
        }
      }
    });
  }

  List<MensajeChat> _messages = [];
  final bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  int _idServicioActivo = 0;
  int _idConductorActual = 0;
  StreamSubscription? _subChat;

  List<MensajeChat> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;

  /// Inicia el chat: carga mensajes, se une al hub y arranca polling de respaldo.
  void iniciarChat(int servicioId, int conductorId) {
    _idServicioActivo = servicioId;
    _idConductorActual = conductorId;
    loadMessages(servicioId, conductorId);
    _signalr.unirseAlChat(servicioId);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => loadMessages(servicioId, conductorId));
  }

  /// Alias de compatibilidad con el codigo existente.
  void startPolling(int servicioId, int conductorId) => iniciarChat(servicioId, conductorId);

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_idServicioActivo > 0) {
      _signalr.salirDelChat(_idServicioActivo);
      _idServicioActivo = 0;
    }
  }

  Future<void> loadMessages(int servicioId, int conductorId) async {
    final resp = await _api.obtenerMensajes(servicioId, conductorId);
    if (resp.ok && resp.list != null) {
      _messages = resp.list!.map((e) => MensajeChat.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      notifyListeners();
    }
  }

  Future<bool> sendMessage(int servicioId, int conductorId, String mensaje) async {
    if (mensaje.trim().isEmpty) return false;
    final resp = await _api.enviarMensaje(servicioId, conductorId, mensaje.trim());
    if (resp.ok) {
      _messages.add(MensajeChat.fromJson({
        'id': DateTime.now().millisecondsSinceEpoch,
        'idservicio': servicioId,
        'mensaje': mensaje.trim(),
        'desdeappconductor': true,
        'fechacreacion': DateTime.now().toIso8601String(),
      }));
      // Notificar por WebSocket al pasajero
      await _signalr.enviarMensajeChat(servicioId, mensaje.trim(), 'Conductor');
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    return false;
  }

  void notificarEscribiendo() {
    if (_idServicioActivo > 0 && _idConductorActual > 0) {
      _signalr.notificarEscribiendo(_idServicioActivo);
    }
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
    _subChat?.cancel();
    super.dispose();
  }
}