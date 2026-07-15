import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<MensajeChat> _messages = [];
  final bool _loading = false;
  String? _error;
  Timer? _pollTimer;

  List<MensajeChat> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;

  void startPolling(int servicioId, int conductorId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => loadMessages(servicioId, conductorId));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadMessages(int servicioId, int conductorId) async {
    final resp = await _api.obtenerMensajes(servicioId, conductorId);
    if (resp.ok && resp.list != null) {
      _messages = resp.list!.map((e) => MensajeChat.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<bool> sendMessage(int servicioId, int conductorId, String mensaje) async {
    final resp = await _api.enviarMensaje(servicioId, conductorId, mensaje);
    if (resp.ok) {
      await loadMessages(servicioId, conductorId);
      return true;
    }
    _error = resp.mensaje;
    return false;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
