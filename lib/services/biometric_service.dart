import 'package:local_auth/local_auth.dart';

/// Seguridad biometrica (huella / rostro) del conductor.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// true si el dispositivo puede autenticar por biometria.
  static Future<bool> disponible() async {
    try {
      final soporta = await _auth.isDeviceSupported();
      final puede = await _auth.canCheckBiometrics;
      return soporta && puede;
    } catch (_) {
      return false;
    }
  }

  /// Solicita la autenticacion. Devuelve true si fue exitosa.
  static Future<bool> autenticar({String motivo = 'Confirma tu identidad para continuar'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
