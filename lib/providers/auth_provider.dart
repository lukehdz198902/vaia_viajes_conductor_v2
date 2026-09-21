import 'package:flutter/foundation.dart';
import '../models/conductor_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/signalr_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final SignalRService _signalr;

  AuthProvider(this._signalr);

  Conductor? _conductor;
  bool _loading = false;
  bool _isOnline = false;
  String? _error;

  Conductor? get conductor => _conductor;
  bool get loading => _loading;
  bool get isOnline => _isOnline;
  bool get isLoggedIn => _conductor != null;
  String? get error => _error;
  int get userId => _conductor?.id ?? 0;
  String get sessionToken => _conductor?.uuidsesion ?? '';

  Future<void> tryAutoLogin() async {
    final data = await _storage.getUserData();
    if (data['id'] != 0) {
      _conductor = Conductor.fromJson(data);
      try { await _signalr.iniciar(_conductor!.id); } catch (_) {}
      notifyListeners();
      _registrarToken();
      // Refresca el perfil para traer las banderas actualizadas (correo,
      // telefono, documentacion) y no volver a pedir lo ya validado.
      await refreshPerfil();
    }
  }

  /// Refresca el perfil desde el servidor y lo persiste localmente.
  Future<void> refreshPerfil() async {
    if (_conductor == null) return;
    try {
      final resp = await _api.obtenerPerfil(_conductor!.id);
      if (resp.ok && resp.data != null) {
        _conductor = Conductor.fromJson(resp.data!);
        await _storage.saveUserData(_conductor!.toMap());
        notifyListeners();
      }
    } catch (_) {}
  }

  // ─── VERIFICACION DE TELEFONO / CORREO ───────────────────────

  Future<bool> enviarCodigoVerificacion(String telefono, String codigopaistel) async {
    try {
      final resp = await _api.enviarCodigoVerificacion(telefono, codigopaistel);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> validarCodigoVerificacion(String telefono, String codigopaistel, String codigo) async {
    try {
      final resp = await _api.validarCodigoVerificacion(telefono, codigopaistel, codigo);
      if (!resp.ok) {
        _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Codigo invalido');
        return false;
      }
      await refreshPerfil();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enviarCodigoCorreo() async {
    if (_conductor == null) return false;
    try {
      final resp = await _api.enviarCodigoCorreo(_conductor!.id, _conductor!.correo);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> validarCodigoCorreo(String codigo) async {
    if (_conductor == null) return false;
    try {
      final resp = await _api.validarCodigoCorreo(_conductor!.correo, codigo);
      if (resp.ok) {
        _conductor = Conductor.fromJson({..._conductor!.toMap(), 'correoconfirmado': true});
        await _storage.saveUserData(_conductor!.toMap());
        notifyListeners();
      } else {
        _error = resp.mensaje.isNotEmpty ? resp.mensaje : 'Codigo invalido';
      }
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> actualizarCorreo(String correo) async {
    if (_conductor == null) return false;
    try {
      final resp = await _api.actualizarCorreo(_conductor!.id, correo);
      if (resp.ok) {
        _conductor = Conductor.fromJson({..._conductor!.toMap(), 'correo': correo, 'correoconfirmado': false});
        await _storage.saveUserData(_conductor!.toMap());
        notifyListeners();
      } else {
        _error = resp.mensaje.isNotEmpty ? resp.mensaje : 'No se pudo actualizar el correo';
      }
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  /// Registra el token de notificaciones push (FCM) en el backend.
  Future<void> _registrarToken() async {
    final t = NotificationService.token;
    if (t == null || t.isEmpty || _conductor == null) return;
    try {
      await _api.actualizarToken(_conductor!.id, t);
    } catch (_) {}
  }

  Future<bool> login(String account, String password,
      {String? dispositivoInfo, String? sistemaOperativo}) async {
    _loading = true; _error = null; notifyListeners();
    final resp = await _api.iniciarSesion(account, password,
        dispositivoInfo: dispositivoInfo, sistemaOperativo: sistemaOperativo);
    _loading = false;
    if (resp.ok && resp.data != null) {
      _conductor = Conductor.fromJson(resp.data!);
      await _storage.saveUserData(resp.data!);
      try { await _signalr.iniciar(_conductor!.id); } catch (_) {}
      notifyListeners();
      _registrarToken();
      // Trae el estatus REAL del servidor (correo, telefono, documentacion)
      // para no volver a pedir verificaciones ya realizadas.
      await refreshPerfil();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Error al iniciar sesión');
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    if (_conductor != null) {
      await _api.cerrarSesion(_conductor!.id, _conductor!.uuidsesion ?? '');
    }
    try { await _signalr.detener(); } catch (_) {}
    _conductor = null;
    _isOnline = false;
    await _storage.clearAll();
    notifyListeners();
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _loading = true; _error = null; notifyListeners();
    final resp = await _api.registrarConductor(data);
    _loading = false;
    if (resp.ok) {
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Error al registrar');
    notifyListeners();
    return false;
  }

  Future<bool> toggleOnline() async {
    if (_conductor == null) return false;
    final newStatus = _isOnline ? 'Desconectado' : 'Disponible';
    _error = null;
    final resp = await _api.cambiarEstatus(_conductor!.id, newStatus);
    if (resp.ok) {
      _isOnline = !_isOnline;
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'No se pudo cambiar el estatus');
    notifyListeners();
    return false;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    _loading = true; notifyListeners();
    data['idConductor'] = _conductor?.id.toString() ?? '';
    final resp = await _api.actualizarPerfil(data);
    if (resp.ok && _conductor != null) {
      final refreshed = await _api.obtenerPerfil(_conductor!.id);
      if (refreshed.ok && refreshed.data != null) {
        _conductor = Conductor.fromJson(refreshed.data!);
      }
    }
    _loading = false; notifyListeners();
  }

  void updateConductorFromJson(Map<String, dynamic> json) {
    _conductor = Conductor.fromJson(json);
    notifyListeners();
  }
}
