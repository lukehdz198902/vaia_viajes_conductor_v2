import 'package:flutter/services.dart';
import 'logger.dart';

/// Controla la burbuja flotante nativa (overlay) del conductor, que muestra
/// el estado de conexion (verde/gris) y la hora de la ultima ubicacion enviada.
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

  /// Muestra/actualiza la burbuja con el estado actual.
  static Future<void> mostrar({required bool conectado, required String ultima}) async {
    try {
      await _channel.invokeMethod('show', {'conectado': conectado, 'ultima': ultima});
    } catch (e) {
      Logger.e('Bubble', 'No se pudo mostrar la burbuja: $e');
    }
  }

  static Future<void> ocultar() async {
    try {
      await _channel.invokeMethod('hide');
    } catch (_) {}
  }
}
