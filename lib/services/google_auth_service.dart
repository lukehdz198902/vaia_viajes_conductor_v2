import 'package:google_sign_in/google_sign_in.dart';
import 'logger.dart';

/// Autenticacion con Google usando google_sign_in 7.x.
///
/// Para obtener el idToken (que valida el backend) es necesario configurar
/// el "server client ID": el cliente OAuth 2.0 de tipo **Web** del proyecto
/// de Google Cloud / Firebase. Se pasa al compilar:
///
///   flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
class GoogleAuthService {
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
  }

  /// Devuelve el idToken de Google, o null si el usuario cancela.
  static Future<String?> obtenerIdToken() async {
    await _ensureInit();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception(
          'No se obtuvo el token de Google. Verifica el cliente OAuth (GOOGLE_SERVER_CLIENT_ID).',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        Logger.i('GoogleAuth', 'Inicio de sesion cancelado por el usuario');
        return null;
      }
      Logger.e('GoogleAuth', 'GoogleSignInException: ${e.code} ${e.description}');
      throw Exception(e.description ?? 'No se pudo iniciar sesion con Google');
    }
  }
}
