import 'package:audioplayers/audioplayers.dart';

/// Reproduce tonos de aviso: nuevo servicio y cambios de estatus del servicio.
class SoundService {
  static final AudioPlayer _player = AudioPlayer(playerId: 'vaia_sfx')
    ..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _speedPlayer = AudioPlayer(playerId: 'vaia_speed')
    ..setReleaseMode(ReleaseMode.stop);

  static bool _habilitado = true;
  static set habilitado(bool v) => _habilitado = v;

  static Future<void> nuevoServicio() => _play('sounds/nuevo_servicio.wav');
  static Future<void> cambioEstatus() => _play('sounds/cambio_estatus.wav');
  static Future<void> mensajeSoporte() => _play('sounds/nuevo_servicio.wav');

  static Future<void> excesoVelocidad() async {
    if (!_habilitado) return;
    try {
      await _speedPlayer.stop();
      await _speedPlayer.play(AssetSource('sounds/exceso_velocidad.wav'), volume: 0.38);
    } catch (_) {}
  }

  static Future<void> _play(String asset) async {
    if (!_habilitado) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: 1.0);
    } catch (_) {}
  }
}
