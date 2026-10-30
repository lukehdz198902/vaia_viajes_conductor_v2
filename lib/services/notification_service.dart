import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'logger.dart';

/// Inicializa Firebase y administra el token de notificaciones push (FCM).
/// No lanza excepcion si Firebase no esta configurado: la app sigue funcionando.
class NotificationService {
  static String? _token;
  static String? get token => _token;

  /// Identificador del servicio cuyo chat esta abierto en este momento.
  /// Mientras coincida no se muestra notificacion por mensajes de ese chat.
  static int idServicioChatAbierto = 0;

  static const MethodChannel _canal = MethodChannel('vaia/notifications');

  /// Se invoca al obtener o renovar el token para actualizarlo en el servidor.
  static Future<void> Function(String token)? onToken;

  static Future<void> inicializar() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      try {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

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

      FirebaseMessaging.onMessage.listen((m) async {
        Logger.i('FCM', 'Mensaje en foreground: ${m.notification?.title}');
        await _mostrarEnPrimerPlano(m);
      });
    } catch (e) {
      Logger.e('FCM', 'No se pudo inicializar Firebase: $e');
    }
  }

  /// En Android, FCM no muestra la notificacion con la app en primer plano,
  /// por eso se publica una notificacion local. En iOS se encarga el sistema
  /// mediante las opciones de presentacion configuradas arriba.
  static Future<void> _mostrarEnPrimerPlano(RemoteMessage m) async {
    final tipo = m.data['type']?.toString() ?? '';
    final idServicio = int.tryParse(m.data['idservicio']?.toString() ?? '') ?? 0;

    // El usuario ya esta viendo el chat de ese servicio: no interrumpir.
    if (tipo == 'chat_message' &&
        idServicio > 0 &&
        idServicio == idServicioChatAbierto) {
      return;
    }

    final title = m.notification?.title ??
        m.data['title']?.toString() ??
        'Vaia';
    final body = m.notification?.body ??
        m.data['body']?.toString() ??
        'Tienes una actualizacion.';
    if (body.isEmpty) return;

    if (Platform.isAndroid) {
      try {
        await _canal.invokeMethod('show', {
          'title': title,
          'body': body,
          'id': DateTime.now().millisecondsSinceEpoch.remainder(100000),
        });
      } catch (_) {}
    }
  }
}
