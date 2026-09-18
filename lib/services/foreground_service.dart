import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'logger.dart';

@pragma('vm:entry-point')
void foregroundTaskStart() {
  FlutterForegroundTask.setTaskHandler(_ConductorTaskHandler());
}

class _ConductorTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    Logger.i('FG', 'Servicio en primer plano iniciado');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // El envio de ubicacion lo realiza el isolate principal (presencia).
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    Logger.i('FG', 'Servicio en primer plano detenido');
  }
}

/// Mantiene la app viva en segundo plano (servicio en primer plano) y muestra
/// una notificacion persistente con el estado de conexion y la ultima
/// ubicacion enviada al servidor. Equivale a la "burbuja" que se ve al
/// minimizar la app (en Android se representa como notificacion fija).
class ForegroundServiceManager {
  static bool _inicializado = false;

  static Future<void> _init() async {
    if (_inicializado) return;
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
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _inicializado = true;
  }

  static Future<void> iniciar({required String titulo, required String texto}) async {
    try {
      await _init();
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

  static Future<void> actualizar({required String titulo, required String texto}) async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(notificationTitle: titulo, notificationText: texto);
    } catch (e) {
      Logger.e('FG', 'No se pudo actualizar la notificacion: $e');
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
