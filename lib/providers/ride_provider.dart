import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/servicio_model.dart';
import '../services/api_service.dart';

class RideProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Servicio? _activeRide;
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  bool _hasNewRequest = false;
  List<Servicio> _history = [];

  Servicio? get activeRide => _activeRide;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasNewRequest => _hasNewRequest;
  List<Servicio> get history => _history;

  void startPolling(int conductorId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkActiveRide(conductorId));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkActiveRide(int conductorId) async {
    final resp = await _api.obtenerServicioActivo(conductorId);
    if (resp.ok && resp.data != null && resp.data!.isNotEmpty) {
      _activeRide = Servicio.fromJson(resp.data!);
      _hasNewRequest = true;
      notifyListeners();
    } else if (resp.ok && (resp.data == null || resp.data!.isEmpty)) {
      if (_activeRide != null) {
        _activeRide = null;
        notifyListeners();
      }
    }
  }

  Future<bool> acceptRide(int servicioId, int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.aceptarServicio(servicioId, conductorId);
    _loading = false;
    if (resp.ok && resp.data != null) {
      _activeRide = Servicio.fromJson(resp.data!);
      _hasNewRequest = false;
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> startTrip(int servicioId, int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.iniciarViaje(servicioId, conductorId);
    _loading = false;
    if (resp.ok && resp.data != null) {
      _activeRide = Servicio.fromJson(resp.data!);
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> finishTrip(int servicioId, int conductorId, {double? costoFinal}) async {
    _loading = true; notifyListeners();
    final resp = await _api.finalizarViaje(servicioId, conductorId, costoFinal: costoFinal);
    _loading = false;
    if (resp.ok) {
      _activeRide = null;
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<void> loadHistory(int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.historialViajes(conductorId);
    if (resp.ok && resp.list != null) {
      _history = resp.list!.map((e) => Servicio.fromJson(e)).toList();
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

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
