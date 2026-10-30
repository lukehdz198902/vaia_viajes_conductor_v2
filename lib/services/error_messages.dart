/// Convierte errores tecnicos en mensajes claros para el usuario.
class ErrorMessages {
  static const String fallback =
      'No se pudo completar la operacion. Intenta de nuevo en unos minutos.';

  static String friendly(Object? error, {String fallbackMessage = fallback}) {
    final raw = (error?.toString() ?? '').replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return fallbackMessage;
    final l = raw.toLowerCase();

    final esRed = l.contains('socketexception') ||
        l.contains('clientexception') ||
        l.contains('failed host lookup') ||
        l.contains('connection refused') ||
        l.contains('network is unreachable') ||
        l.contains('connection closed') ||
        l.contains('connection reset') ||
        l.contains('timed out') ||
        l.contains('timeout') ||
        l.contains('handshake') ||
        l.contains('no address associated') ||
        l.contains('nodename nor servname');
    if (esRed) {
      return 'No se pudo conectar con el servidor. Revisa tu conexion a internet e intenta de nuevo.';
    }

    final esInterno = l.contains('sqlexception') ||
        l.contains('internal server') ||
        l.contains('error interno del servidor') ||
        l.contains('error 500') ||
        l.contains('statuscode: 500') ||
        l.contains('stack trace') ||
        l.contains('stacktrace') ||
        l.contains('exception:') ||
        l.contains('runtimebinder') ||
        l.contains('nullreference');
    if (esInterno) {
      return 'Ocurrio un error en el servidor. Intenta de nuevo en unos minutos.';
    }

    // Nunca mostrar URLs, rutas o detalles de infraestructura.
    final tieneDetalleTecnico = l.contains('http://') ||
        l.contains('https://') ||
        l.contains('uri.parse') ||
        l.contains('formatexception') ||
        l.contains('typeerror') ||
        l.contains('nosuchmethod') ||
        l.contains('.dart:') ||
        l.contains('package:');
    if (tieneDetalleTecnico || raw.length > 160) return fallbackMessage;

    return raw;
  }
}
