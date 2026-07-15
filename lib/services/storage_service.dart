import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _tokenKey = 'conductor_session_token';
  static const _userIdKey = 'conductor_id';
  static const _userNameKey = 'conductor_name';
  static const _userEmailKey = 'conductor_email';
  static const _userPhoneKey = 'conductor_phone';
  static const _userIdCompaniaKey = 'conductor_id_compania';
  static const _userStatusKey = 'conductor_status';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String?> getSessionToken() => _secure.read(key: _tokenKey);
  Future<void> setSessionToken(String token) => _secure.write(key: _tokenKey, value: token);
  Future<void> removeSessionToken() => _secure.delete(key: _tokenKey);

  Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, user['id'] ?? 0);
    await prefs.setString(_userNameKey, user['nombre'] ?? '');
    await prefs.setString(_userEmailKey, user['correo'] ?? '');
    await prefs.setString(_userPhoneKey, user['telefono'] ?? '');
    await prefs.setInt(_userIdCompaniaKey, user['idcompania'] ?? 0);
    await prefs.setString(_userStatusKey, user['conductorestatus'] ?? '');
    if (user['uuidsesion'] != null) {
      await setSessionToken(user['uuidsesion'].toString());
    }
  }

  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getInt(_userIdKey) ?? 0,
      'nombre': prefs.getString(_userNameKey) ?? '',
      'correo': prefs.getString(_userEmailKey) ?? '',
      'telefono': prefs.getString(_userPhoneKey) ?? '',
      'idcompania': prefs.getInt(_userIdCompaniaKey) ?? 0,
      'conductorestatus': prefs.getString(_userStatusKey) ?? '',
    };
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secure.deleteAll();
  }
}
