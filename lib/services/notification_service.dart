import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'logger.dart';

/// Inicializa Firebase y administra el token de notificaciones push (FCM).
/// No lanza excepcion si Firebase no esta configurado: la app sigue funcionando.
class NotificationService {
  static String? _token;
  static String? get token => _token;

  /// Se invoca al obtener o renovar el token para actualizarlo en el servidor.
  static Future<void> Function(String token)? onToken;

  static Future<void> inicializar() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      _token = await messaging.getToken();
      Logger.i('FCM', 'Token obtenido: $_token');
      if (_token != null && _token!.isNotEmpty) {
        try { await onToken?.call(_token!); } catch (_) {}
      }

      messaging.onTokenRefresh.listen((t) async {
        _token = t;
        Logger.i('FCM', 'Token renovado');
        try { await onToken?.call(t); } catch (_) {}
      });

      FirebaseMessaging.onMessage.listen((m) {
        Logger.i('FCM', 'Mensaje en foreground: ${m.notification?.title}');
      });
    } catch (e) {
      Logger.e('FCM', 'No se pudo inicializar Firebase: $e');
    }
  }
}
