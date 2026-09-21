import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'logger.dart';

/// Punto de entrada del servicio en primer plano (se ejecuta en su propio
/// isolate, por lo que sigue vivo aunque la app este en segundo plano).
@pragma('vm:entry-point')
void foregroundTaskStart() {
  FlutterForegroundTask.setTaskHandler(_ConductorTaskHandler());
}

/// Reporta la ubicacion al servidor por REST. Se ejecuta siempre, pero solo
/// envia cuando la app NO esta en primer plano (en primer plano el isolate de
/// UI reporta por WebSocket). Asi nunca se deja de reportar y no se duplica.
class _ConductorTaskHandler extends TaskHandler {
  int _idConductor = 0;
  bool _reportando = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _idConductor = await FlutterForegroundTask.getData<int>(key: 'idConductor') ?? 0;
    Logger.i('FG', 'Servicio iniciado (idConductor=$_idConductor)');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_reportando) return;
    _reportando = true;
    _reportar().whenComplete(() => _reportando = false);
  }

  Future<void> _reportar() async {
    if (_idConductor <= 0) return;
    try {
      final enPrimerPlano = await FlutterForegroundTask.getData<bool>(key: 'enPrimerPlano') ?? true;
      if (enPrimerPlano) return;

      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final uri = Uri.parse('${ApiConfig.baseUrl}/ActualizarUbicacion');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idConductor': _idConductor,
          'lat': pos.latitude.toString(),
          'lng': pos.longitude.toString(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final ahora = DateTime.now();
        await FlutterForegroundTask.saveData(key: 'ultimaUbicacion', value: ahora.toIso8601String());
        final hh = '${ahora.hour.toString().padLeft(2, '0')}:'
            '${ahora.minute.toString().padLeft(2, '0')}:'
            '${ahora.second.toString().padLeft(2, '0')}';
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Vaia Conductor - En servicio',
          notificationText: 'Ubicacion enviada $hh',
        );
      }
    } catch (e) {
      Logger.w('FG', 'No se pudo reportar ubicacion: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    Logger.i('FG', 'Servicio detenido');
  }
}

/// Administra el servicio en primer plano y la notificacion persistente.
class ForegroundServiceManager {
  static bool _inicializado = false;
  static int _intervaloSegundos = 15;

  static Future<void> _init(int intervaloSegundos) async {
    if (_inicializado && _intervaloSegundos == intervaloSegundos) return;
    _intervaloSegundos = intervaloSegundos;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'vaia_conductor_presencia',
        channelName: 'Vaia Conductor',
        channelDescription: 'Mantiene tu ubicacion activa mientras estas conectado',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervaloSegundos * 1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _inicializado = true;
  }

  /// Inicia el servicio. [intervaloSegundos] es configurable desde el portal.
  static Future<void> iniciar({
    required String titulo,
    required String texto,
    int intervaloSegundos = 15,
    int idConductor = 0,
  }) async {
    try {
      if (idConductor > 0) {
        await FlutterForegroundTask.saveData(key: 'idConductor', value: idConductor);
      }
      await _init(intervaloSegundos);
      if (await FlutterForegroundTask.isRunningService) {
        await actualizar(titulo: titulo, texto: texto);
        return;
      }
      await FlutterForegroundTask.requestNotificationPermission();
      await FlutterForegroundTask.startService(
        serviceId: 4101,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: titulo,
        notificationText: texto,
        callback: foregroundTaskStart,
      );
    } catch (e) {
      Logger.e('FG', 'No se pudo iniciar el servicio en primer plano: $e');
    }
  }

  /// Marca si la app esta en primer plano (el servicio solo reporta en segundo).
  static Future<void> marcarPrimerPlano(bool enPrimerPlano) async {
    try {
      await FlutterForegroundTask.saveData(key: 'enPrimerPlano', value: enPrimerPlano);
    } catch (_) {}
  }

  static Future<void> actualizar({required String titulo, required String texto}) async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(notificationTitle: titulo, notificationText: texto);
    } catch (e) {
      Logger.e('FG', 'No se pudo actualizar la notificacion: $e');
    }
  }

  /// Ultima ubicacion reportada por el servicio (segundo plano).
  static Future<DateTime?> ultimaUbicacion() async {
    try {
      final s = await FlutterForegroundTask.getData<String>(key: 'ultimaUbicacion');
      if (s == null) return null;
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  static Future<void> detener() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
