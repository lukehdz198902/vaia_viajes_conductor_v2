import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Definicion de un permiso/requisito para las pantallas de onboarding.
class PermisoDef {
  final String id;
  final IconData icono;
  final Color color;
  final String titulo;
  final String descripcion;
  final List<String> puntos;

  /// Permiso del sistema a solicitar (null si solo es un aviso/activacion).
  final Permission? permiso;

  /// Si es indispensable para operar.
  final bool obligatorio;

  /// Solo informativo (p.ej. mantener la pantalla activa).
  final bool soloAviso;

  const PermisoDef({
    required this.id,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.descripcion,
    required this.puntos,
    this.permiso,
    this.obligatorio = false,
    this.soloAviso = false,
  });
}

/// Permisos que requiere la app del conductor, en orden de solicitud.
class PermissionService {
  static List<PermisoDef> conductor() => const [
        PermisoDef(
          id: 'notificaciones',
          icono: Icons.notifications_active_rounded,
          color: Color(0xFFF59E0B),
          titulo: 'Notificaciones',
          descripcion: 'Te avisamos al instante cuando tengas un nuevo servicio.',
          puntos: [
            'Recibe solicitudes de viaje en tiempo real',
            'Avisos de aprobacion de documentos y pagos',
          ],
          permiso: Permission.notification,
          obligatorio: true,
        ),
        PermisoDef(
          id: 'ubicacion',
          icono: Icons.my_location_rounded,
          color: Color(0xFF16A34A),
          titulo: 'Ubicacion',
          descripcion: 'Tu ubicacion permite asignarte viajes cercanos y guiarte.',
          puntos: [
            'El pasajero y el administrador ven donde estas',
            'Se calculan distancias y tarifas correctas',
          ],
          permiso: Permission.location,
          obligatorio: true,
        ),
        PermisoDef(
          id: 'ubicacion_segundo_plano',
          icono: Icons.location_on_rounded,
          color: Color(0xFF0EA5E9),
          titulo: 'Ubicacion en segundo plano',
          descripcion: 'Sigue enviando tu ubicacion aunque la app este minimizada.',
          puntos: [
            'Permite mostrar la burbuja con tu ultimo envio',
            'No pierdes viajes mientras usas otra app',
          ],
          permiso: Permission.locationAlways,
          obligatorio: true,
        ),
        PermisoDef(
          id: 'camara',
          icono: Icons.photo_camera_rounded,
          color: Color(0xFF8B5CF6),
          titulo: 'Camara',
          descripcion: 'Necesaria para subir tu documentacion y la de tu unidad.',
          puntos: [
            'Toma fotos de tus documentos desde la app',
            'Agrega fotos de tu vehiculo',
          ],
          permiso: Permission.camera,
        ),
        PermisoDef(
          id: 'telefono',
          icono: Icons.phone_in_talk_rounded,
          color: Color(0xFFEC4899),
          titulo: 'Llamadas',
          descripcion: 'Para comunicarte con el pasajero durante un servicio.',
          puntos: [
            'Llama al pasajero desde la app',
            'Coordina el punto de encuentro',
          ],
          permiso: Permission.phone,
        ),
        PermisoDef(
          id: 'superposicion',
          icono: Icons.picture_in_picture_alt_rounded,
          color: Color(0xFFF97316),
          titulo: 'Mostrar sobre otras apps',
          descripcion: 'Permite mostrar la burbuja flotante al minimizar la app.',
          puntos: [
            'La burbuja muestra tu estado y ultima ubicacion',
            'Vuelve a la app con un toque',
          ],
          permiso: Permission.systemAlertWindow,
        ),
        PermisoDef(
          id: 'bateria',
          icono: Icons.battery_charging_full_rounded,
          color: Color(0xFF22C55E),
          titulo: 'Bateria',
          descripcion: 'Evita que el sistema cierre la app cuando estas trabajando.',
          puntos: [
            'Desactiva la optimizacion de bateria para Vaia',
            'Mantiene tu conexion estable',
          ],
          permiso: Permission.ignoreBatteryOptimizations,
        ),
        PermisoDef(
          id: 'pantalla',
          icono: Icons.brightness_high_rounded,
          color: Color(0xFF6366F1),
          titulo: 'Pantalla activa',
          descripcion: 'Mantenemos la pantalla encendida mientras usas la app.',
          puntos: [
            'Evita que el telefono se bloquee durante un viaje',
            'Solo se activa mientras usas Vaia Conductor',
          ],
          soloAviso: true,
        ),
      ];

  /// Estado actual de un permiso (concedido / denegado / no aplica).
  static Future<PermissionStatus> estado(PermisoDef def) async {
    if (def.permiso == null) return PermissionStatus.granted;
    try {
      return await def.permiso!.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// Solicita el permiso. Devuelve true si quedo concedido.
  static Future<bool> solicitar(PermisoDef def) async {
    if (def.permiso == null) return true;
    try {
      final r = await def.permiso!.request();
      return r.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Abre los ajustes de la app (para permisos concedidos manualmente).
  static Future<void> abrirAjustes() => openAppSettings();
}
