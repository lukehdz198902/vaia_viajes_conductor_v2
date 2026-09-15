import 'dart:async';
import 'dart:convert';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/api_config.dart';
import 'logger.dart';

/// Evento generico recibido desde el WebSocket.
class RealtimeEvent {
  final String tipo;
  final Map<String, dynamic> data;
  final DateTime fecha;
  RealtimeEvent(this.tipo, this.data) : fecha = DateTime.now();

  @override
  String toString() => 'RealtimeEvent($tipo)';
}

/// Servicio central de WebSocket (SignalR) para la app de conductor.
class SignalRService {
  HubConnection? _servicioConn;
  HubConnection? _chatConn;
  HubConnection? _soporteConn;

  int _idConductor = 0;
  int _idServicioActivo = 0;
  bool _iniciado = false;

  final _eventos = StreamController<RealtimeEvent>.broadcast();
  final _chatEventos = StreamController<RealtimeEvent>.broadcast();
  final _soporteEventos = StreamController<RealtimeEvent>.broadcast();
  final _estadoConexion = StreamController<bool>.broadcast();

  Stream<RealtimeEvent> get eventos => _eventos.stream;
  Stream<RealtimeEvent> get chatEventos => _chatEventos.stream;
  Stream<RealtimeEvent> get soporteEventos => _soporteEventos.stream;
  Stream<bool> get estadoConexion => _estadoConexion.stream;

  bool get conectado => _servicioConn?.state == HubConnectionState.Connected;
  int get idServicioActivo => _idServicioActivo;

  Future<void> iniciar(int idConductor) async {
    if (_iniciado && _idConductor == idConductor) return;
    _idConductor = idConductor;
    _iniciado = true;
    await _conectarServicio();
  }

  Future<void> _conectarServicio() async {
    try {
      if (_servicioConn != null && _servicioConn!.state == HubConnectionState.Connected) return;

      _servicioConn = HubConnectionBuilder()
          .withUrl(ApiConfig.servicioHubUrl)
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000])
          .build();

      _registrarHandlersServicio();

      _servicioConn!.onreconnecting(({error}) {
        Logger.w('SignalR', 'ServicioHub reconectando: $error');
        _estadoConexion.add(false);
      });
      _servicioConn!.onreconnected(({connectionId}) {
        Logger.i('SignalR', 'ServicioHub reconectado');
        _estadoConexion.add(true);
        _registrarConductor();
      });
      _servicioConn!.onclose(({error}) {
        Logger.w('SignalR', 'ServicioHub cerrado: $error');
        _estadoConexion.add(false);
      });

      await _servicioConn!.start();
      Logger.i('SignalR', 'ServicioHub conectado');
      _estadoConexion.add(true);
      await _registrarConductor();
    } catch (e) {
      Logger.e('SignalR', 'Error conectando ServicioHub: $e');
      _estadoConexion.add(false);
    }
  }

  Future<void> _registrarConductor() async {
    try {
      await _servicioConn?.invoke('RegistrarConexion', args: ['conductor', _idConductor]);
    } catch (e) {
      Logger.e('SignalR', 'Error registrando conductor: $e');
    }
  }

  void _registrarHandlersServicio() {
    if (_servicioConn == null) return;
    const eventos = [
      'NuevoServicio',
      'ServicioAsignado',
      'EstatusCambiado',
      'ServicioCancelado',
      'UbicacionActualizada',
      'DisponibilidadActualizada',
      'ServicioRechazado',
    ];
    for (final nombre in eventos) {
      _servicioConn!.on(nombre, (args) {
        final data = _parseArgs(args);
        Logger.i('SignalR', 'Evento: $nombre -> $data');
        _eventos.add(RealtimeEvent(nombre, data));
      });
    }
  }

  // ─── SERVICIO ACTIVO ─────────────────────────────────────────

  Future<void> unirseAServicio(int idServicio) async {
    _idServicioActivo = idServicio;
    try {
      await _servicioConn?.invoke('UnirseAServicio', args: [idServicio]);
      await unirseAlChat(idServicio);
      Logger.i('SignalR', 'Conductor unido al servicio $idServicio');
    } catch (e) {
      Logger.e('SignalR', 'Error uniendo al servicio: $e');
    }
  }

  Future<void> salirDeServicio(int idServicio) async {
    try {
      await _servicioConn?.invoke('SalirDeServicio', args: [idServicio]);
      await salirDelChat(idServicio);
      if (_idServicioActivo == idServicio) _idServicioActivo = 0;
    } catch (_) {}
  }

  /// Reporta la ubicacion GPS del conductor (se emite a los interesados).
  Future<void> reportarUbicacion(double lat, double lng, {int? idServicio}) async {
    try {
      await _servicioConn?.invoke('ActualizarUbicacion',
          args: [_idConductor, lat.toString(), lng.toString(), idServicio ?? _idServicioActivo]);
    } catch (_) {}
  }

  Future<void> latido() async {
    try {
      await _servicioConn?.invoke('LatidoConductor', args: [_idConductor]);
    } catch (_) {}
  }

  // ─── CHAT CON PASAJERO ───────────────────────────────────────

  Future<void> _conectarChat() async {
    try {
      if (_chatConn != null && _chatConn!.state == HubConnectionState.Connected) return;

      _chatConn = HubConnectionBuilder()
          .withUrl(ApiConfig.chatHubUrl)
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000])
          .build();

      _chatConn!.on('NuevoMensaje', (args) {
        _chatEventos.add(RealtimeEvent('NuevoMensaje', _parseArgs(args)));
      });
      _chatConn!.on('Escribiendo', (args) {
        _chatEventos.add(RealtimeEvent('Escribiendo', _parseArgs(args)));
      });

      await _chatConn!.start();
      Logger.i('SignalR', 'ChatHub conectado');
    } catch (e) {
      Logger.e('SignalR', 'Error conectando ChatHub: $e');
    }
  }

  Future<void> unirseAlChat(int idServicio) async {
    await _conectarChat();
    try {
      await _chatConn?.invoke('UnirseAlChat', args: [idServicio]);
    } catch (e) {
      Logger.e('SignalR', 'Error uniendo al chat: $e');
    }
  }

  Future<void> salirDelChat(int idServicio) async {
    try {
      await _chatConn?.invoke('SalirDelChat', args: [idServicio]);
    } catch (_) {}
  }

  Future<void> enviarMensajeChat(int idServicio, String mensaje, String nombreEmisor) async {
    try {
      await _chatConn?.invoke('EnviarMensaje', args: [idServicio, 'conductor', mensaje, nombreEmisor]);
    } catch (e) {
      Logger.e('SignalR', 'Error enviando mensaje: $e');
    }
  }

  Future<void> notificarEscribiendo(int idServicio) async {
    try {
      await _chatConn?.invoke('Escribiendo', args: [idServicio, 'conductor']);
    } catch (_) {}
  }

  // ─── SOPORTE ─────────────────────────────────────────────────

  Future<void> _conectarSoporte() async {
    try {
      if (_soporteConn != null && _soporteConn!.state == HubConnectionState.Connected) return;

      _soporteConn = HubConnectionBuilder()
          .withUrl(ApiConfig.soporteHubUrl)
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000])
          .build();

      _soporteConn!.on('NuevoMensajeSoporte', (args) {
        _soporteEventos.add(RealtimeEvent('NuevoMensajeSoporte', _parseArgs(args)));
      });
      _soporteConn!.on('SolicitudActualizada', (args) {
        _soporteEventos.add(RealtimeEvent('SolicitudActualizada', _parseArgs(args)));
      });

      await _soporteConn!.start();
      Logger.i('SignalR', 'SoporteHub conectado');
    } catch (e) {
      Logger.e('SignalR', 'Error conectando SoporteHub: $e');
    }
  }

  Future<void> unirseASolicitudSoporte(int idSolicitud) async {
    await _conectarSoporte();
    try {
      await _soporteConn?.invoke('UnirseASolicitud', args: [idSolicitud]);
    } catch (e) {
      Logger.e('SignalR', 'Error uniendo a solicitud: $e');
    }
  }

  Future<void> salirDeSolicitudSoporte(int idSolicitud) async {
    try {
      await _soporteConn?.invoke('SalirDeSolicitud', args: [idSolicitud]);
    } catch (_) {}
  }

  Future<void> enviarMensajeSoporte(int idSolicitud, int idEmisor, String nombreEmisor, String mensaje) async {
    try {
      await _soporteConn?.invoke('EnviarMensajeSoporte',
          args: [idSolicitud, 'conductor', idEmisor, nombreEmisor, mensaje]);
    } catch (e) {
      Logger.e('SignalR', 'Error enviando mensaje soporte: $e');
    }
  }

  // ─── CIERRE ──────────────────────────────────────────────────

  Future<void> detener() async {
    try {
      await _servicioConn?.stop();
      await _chatConn?.stop();
      await _soporteConn?.stop();
    } catch (_) {}
    _servicioConn = null;
    _chatConn = null;
    _soporteConn = null;
    _iniciado = false;
    _idServicioActivo = 0;
  }

  Map<String, dynamic> _parseArgs(List<Object?>? args) {
    if (args == null || args.isEmpty) return {};
    final first = args.first;
    if (first is Map) return Map<String, dynamic>.from(first);
    if (first is String) {
      try {
        final decoded = json.decode(first);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {'valor': first};
  }

  void dispose() {
    _eventos.close();
    _chatEventos.close();
    _soporteEventos.close();
    _estadoConexion.close();
    detener();
  }
}