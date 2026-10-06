import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Informacion del dispositivo y de la version de la app.
///
/// Se carga una sola vez en `main()` para poder enviar el nombre real del
/// dispositivo al registrar la sesion (pantalla de dispositivos conectados)
/// y mostrar la version instalada en Configuracion.
class AppInfo {
  static String _dispositivo = '';
  static String _so = '';
  static String _version = '1.0.0';
  static String _build = '';

  static String get dispositivo => _dispositivo.isEmpty ? 'Dispositivo' : _dispositivo;
  static String get sistemaOperativo => _so.isEmpty ? 'Android' : _so;
  static String get version => _version;
  static String get versionCompleta => _build.isEmpty ? _version : '$_version ($_build)';

  static Future<void> cargar() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        _dispositivo = '${a.manufacturer} ${a.model}'.trim();
        _so = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        _dispositivo = i.name.isNotEmpty ? i.name : i.utsname.machine;
        _so = '${i.systemName} ${i.systemVersion}';
      } else {
        _dispositivo = Platform.operatingSystem;
        _so = Platform.operatingSystem;
      }
    } catch (_) {
      _dispositivo = 'Dispositivo';
      _so = Platform.operatingSystem;
    }
    try {
      final p = await PackageInfo.fromPlatform();
      _version = p.version;
      _build = p.buildNumber;
    } catch (_) {}
  }
}
