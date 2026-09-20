import 'package:flutter/services.dart';
import 'logger.dart';

/// Controla la burbuja flotante nativa (overlay) del conductor. La burbuja es
/// circular, muestra el logotipo, un punto verde/gris segun la conexion y la
/// fecha/hora de la ultima ubicacion enviada al servidor.
///
/// Se muestra **solo al minimizar/cerrar la app**; al volver a la app se oculta.
class BubbleOverlay {
  static const _channel = MethodChannel('vaia/bubble');

  static Future<bool> tienePermiso() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> solicitarPermiso() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// Muestra la burbuja (inicia el overlay nativo).
  static Future<void> mostrar({required bool conectado, required String fecha}) async {
    try {
      await _channel.invokeMethod('show', {'conectado': conectado, 'fecha': fecha});
    } catch (e) {
      Logger.e('Bubble', 'No se pudo mostrar la burbuja: $e');
    }
  }

  /// Actualiza el estado de la burbuja si ya esta visible.
  static Future<void> actualizar({required bool conectado, required String fecha}) async {
    try {
      await _channel.invokeMethod('update', {'conectado': conectado, 'fecha': fecha});
    } catch (_) {}
  }

  static Future<void> ocultar() async {
    try {
      await _channel.invokeMethod('hide');
    } catch (_) {}
  }

  /// Manda la app al fondo (minimizar) para que se vea la burbuja.
  static Future<void> minimizar() async {
    try {
      await _channel.invokeMethod('moveToBack');
    } catch (_) {}
  }
}
