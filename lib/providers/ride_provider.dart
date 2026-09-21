import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../models/servicio_model.dart';
import '../models/parada_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../services/foreground_service.dart';
import '../services/bubble_overlay.dart';

class RideProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SignalRService _signalr;

  RideProvider(this._signalr) {
    _subEventos = _signalr.eventos.listen(_onRealtimeEvent);
    _subConexion = _signalr.estadoConexion.listen((c) {
      _conectadoWs = c;
      notifyListeners();
      _actualizarNotificacion();
    });
  }

  Servicio? _activeRide;
  Servicio? _servicioOfrecido; // solicitud entrante para aceptar/rechazar
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _presenceTimer;
  Timer? _latidoTimer;
  int _idConductorPresencia = 0;
  int _idServicioGps = 0;
  // Taximetro
  bool _taxiActivo = false;
  double _distanciaTaxi = 0;
  double? _ultLatTaxi;
  double? _ultLngTaxi;
  DateTime? _inicioViajeTaxi;
  double? _costoEnCurso;
  DateTime? _ultimaUbicacion;
  bool _hasNewRequest = false;
  List<Servicio> _history = [];
  final List<ParadaModel> _paradas = [];
  bool _conectadoWs = false;
  bool _permisoUbicacionOk = false;
  bool _permisoSegundoPlano = true;
  int _intervaloSegundos = 15;
  bool _enPrimerPlano = true;
  String _dirDatos = '';
  StreamSubscription? _subEventos;
  StreamSubscription? _subConexion;

  /// Asegura el permiso de ubicacion en tiempo de ejecucion (Android/iOS).
  /// Sin este permiso Geolocator falla y no se reportaba ninguna ubicacion.
  ///
  /// En Android tambien se requiere "Permitir todo el tiempo" para seguir
  /// enviando la ubicacion con la app minimizada (burbuja / segundo plano).
  Future<bool> asegurarPermisoUbicacion() async {
    if (_permisoUbicacionOk && _permisoSegundoPlano) return true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      _permisoUbicacionOk = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
      // En Android, "mientras se usa la app" no basta para el segundo plano.
      _permisoSegundoPlano = !(!kIsWeb && Platform.isAndroid && perm == LocationPermission.whileInUse);
      return _permisoUbicacionOk;
    } catch (_) {
      return false;
    }
  }

  /// true cuando falta conceder "Permitir todo el tiempo" (solo Android).
  bool get necesitaPermisoSegundoPlano => !_permisoSegundoPlano;

  Servicio? get activeRide => _activeRide;
  Servicio? get servicioOfrecido => _servicioOfrecido;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasNewRequest => _hasNewRequest;
  List<Servicio> get history => _history;
  List<ParadaModel> get paradas => _paradas;
  bool get conectadoWs => _conectadoWs;
  double? get costoEnCurso => _costoEnCurso;
  DateTime? get ultimaUbicacion => _ultimaUbicacion;

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ SIGNALR Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  void _onRealtimeEvent(RealtimeEvent event) {
    switch (event.tipo) {
      case 'NuevoServicio':
      case 'ServicioAsignado':
        // Solicitud entrante para este conductor
        final idServicio = _toInt(event.data['idServicio'] ?? event.data['idservicio']);
        if (idServicio > 0 && (_activeRide == null || _activeRide!.id != idServicio)) {
          _servicioOfrecido = Servicio.fromJson({
            'id': idServicio,
            'idpasajero': event.data['idPasajero'],
            'pas_nombre': event.data['pasajeroNombre'] ?? event.data['pasajeronombre'],
            'pasajerocalificacion': event.data['pasajeroCalificacion'],
            'pasajerototalviajes': event.data['pasajeroTotalViajes'],
            'direccionorigen': event.data['direccionOrigen'] ?? event.data['direccionorigen'] ?? '',
            'latorigen': event.data['latOrigen'] ?? '',
            'lngorigen': event.data['lngOrigen'] ?? '',
            'direcciondestination': event.data['direccionDestino'] ?? '',
            'latdestination': event.data['latDestino'] ?? '',
            'lngdestination': event.data['lngDestino'] ?? '',
            'costoestimado': event.data['costoEstimado'] ?? 0,
            'distanciametros': event.data['distanciaMetros'] ?? 0,
            'segundosparatomar': event.data['segundosParaTomar'] ?? event.data['segundosparatomar'] ?? 30,
            'servicioEstatus': 'Solicitado',
          });
          _hasNewRequest = true;
          notifyListeners();
          // Si la app esta en segundo plano (burbuja), se trae al frente para
          // que el conductor vea la tarjeta del servicio.
          if (!_enPrimerPlano) {
            BubbleOverlay.traerAlFrente();
          }
        }
        break;
      case 'EstatusCambiado':
        final estatus = event.data['estatus']?.toString();
        if (estatus != null && _activeRide != null &&
            estatus != 'ParadaAgregada' && estatus != 'ParadaCompletada') {
          _activeRide = Servicio.fromJson({
            ..._activeRide!.toMap(),
            'servicioEstatus': estatus,
          });
          notifyListeners();
        }
        break;
      case 'ServicioCancelado':
        _activeRide = null;
        _servicioOfrecido = null;
        _hasNewRequest = false;
        _paradas.clear();
        _stopGps();
        notifyListeners();
        break;
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ POLLING (RESPALDO) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  void startPolling(int conductorId) {
    _pollTimer?.cancel();
    final intervalo = _conectadoWs ? const Duration(seconds: 20) : const Duration(seconds: 10);
    _pollTimer = Timer.periodic(intervalo, (_) => _checkActiveRide(conductorId));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Consulta de inmediato si hay un servicio activo (al ingresar a la app).
  Future<void> revisarServicioActivo(int conductorId) async {
    await _checkActiveRide(conductorId);
  }

  Future<void> _checkActiveRide(int conductorId) async {
    final resp = await _api.obtenerServicioActivo(conductorId);
    if (resp.ok && resp.data != null && resp.data!.isNotEmpty) {
      final servicio = Servicio.fromJson(resp.data!);
      final esNuevo = _activeRide?.id != servicio.id;
      _activeRide = servicio;
      if (esNuevo) {
        _hasNewRequest = true;
        await _signalr.unirseAServicio(servicio.id);
        await listarParadas(servicio.id);
        _startGps(servicio.id, conductorId);
      }
      notifyListeners();
    } else if (resp.ok) {
      if (_activeRide != null) {
        _activeRide = null;
        _paradas.clear();
        _stopGps();
        notifyListeners();
      }
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ PRESENCIA Y GPS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //
  // El conductor reporta su ubicacion SIEMPRE que esta conectado
  // (disponible o en viaje) y envia un latido para que el sistema
  // sepa que sigue activo. Se usa WebSocket si esta conectado; si no,
  // la API REST como respaldo. La persistencia ocurre en el servidor.

  /// Inicia el reporte continuo de ubicacion y el latido (heartbeat).
  void iniciarPresencia(int conductorId) {
    if (conductorId <= 0) return;
    if (_idConductorPresencia == conductorId && _presenceTimer != null) return;

    _idConductorPresencia = conductorId;
    _latidoTimer?.cancel();

    // Configuracion vigente (intervalo de ubicacion) desde el portal.
    _cargarConfiguracion();

    // Solicita el permiso de ubicacion y comienza a reportar de inmediato.
    asegurarPermisoUbicacion().then((_) => _reportarPresencia());
    _signalr.latido();

    _reiniciarTimerPresencia();
    _latidoTimer = Timer.periodic(const Duration(seconds: 30), (_) => _signalr.latido());

    // Servicio en primer plano: mantiene el reporte de ubicacion incluso con
    // la app en segundo plano o minimizada.
    _iniciarServicioFondo(conductorId);
    _asegurarPermisoBurbuja();
  }

  /// Arranca el servicio en primer plano con el directorio donde se escribe el
  /// estado que consume la burbuja nativa.
  Future<void> _iniciarServicioFondo(int conductorId) async {
    try {
      _dirDatos = (await getApplicationSupportDirectory()).path;
    } catch (_) {}
    BubbleOverlay.dirDatos = _dirDatos;
    await ForegroundServiceManager.iniciar(
      titulo: 'Vaia Conductor - En servicio',
      texto: _textoNotificacion(),
      intervaloSegundos: _intervaloSegundos,
      idConductor: conductorId,
      dirDatos: _dirDatos,
    );
    await ForegroundServiceManager.marcarPrimerPlano(_enPrimerPlano);
  }

  /// Lee el intervalo de envio de ubicacion configurado en el portal.
  Future<void> _cargarConfiguracion() async {
    try {
      final r = await _api.obtenerConfiguracionApp();
      for (final e in (r.list ?? [])) {
        final m = e as Map;
        if (m['claveconfiguracion']?.toString() == 'INTERVALO_ENVIO_UBICACION_SEGUNDOS') {
          final v = int.tryParse(m['valorconfiguracion']?.toString() ?? '');
          if (v != null && v >= 5 && v <= 120) {
            _intervaloSegundos = v;
            _reiniciarTimerPresencia();
          }
        }
      }
    } catch (_) {}
  }

  /// Informa si la app esta visible. El servicio en primer plano reporta la
  /// ubicacion solo cuando la app pasa a segundo plano.
  void marcarPrimerPlano(bool enPrimerPlano) {
    _enPrimerPlano = enPrimerPlano;
    ForegroundServiceManager.marcarPrimerPlano(enPrimerPlano);
    escribirEstadoUbicacion(_dirDatos, _conectadoWs, _ultimaUbicacion);
    if (enPrimerPlano) {
      // Al volver, refresca la hora del ultimo envio hecho en segundo plano.
      ForegroundServiceManager.ultimaUbicacion().then((d) {
        if (d != null) {
          _ultimaUbicacion = d;
          notifyListeners();
        }
      });
    }
  }

  /// Solicita el permiso de overlay. La burbuja NO se muestra al conectar:
  /// solo aparece cuando el conductor minimiza o cierra la app.
  Future<void> _asegurarPermisoBurbuja() async {
    try {
      final ok = await BubbleOverlay.tienePermiso();
      if (!ok) await BubbleOverlay.solicitarPermiso();
    } catch (_) {}
  }

  /// Muestra la burbuja flotante (al minimizar/cerrar la app).
  Future<void> mostrarBurbuja() async {
    if (_idConductorPresencia <= 0) return;
    try {
      if (!await BubbleOverlay.tienePermiso()) {
        await BubbleOverlay.solicitarPermiso();
        return;
      }
      await BubbleOverlay.mostrar(conectado: _conectadoWs, fecha: _fechaActual());
    } catch (_) {}
  }

  /// Oculta la burbuja (al volver a la app).
  Future<void> ocultarBurbuja() async {
    try {
      await BubbleOverlay.ocultar();
    } catch (_) {}
  }

  /// Ajusta la frecuencia de reporte segun el estado: en viaje 12 s
  /// (seguimiento preciso), disponible el intervalo configurado (15 s).
  void _reiniciarTimerPresencia() {
    _presenceTimer?.cancel();
    if (_idConductorPresencia <= 0) return;
    final segundos = _idServicioGps > 0 ? 12 : _intervaloSegundos;
    _presenceTimer = Timer.periodic(Duration(seconds: segundos), (_) => _reportarPresencia());
  }

  /// Detiene el reporte de ubicacion y el latido (al cerrar sesion).
  void detenerPresencia() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _latidoTimer?.cancel();
    _latidoTimer = null;
    _idConductorPresencia = 0;
    _idServicioGps = 0;
    ForegroundServiceManager.detener();
    BubbleOverlay.ocultar();
  }

  Future<void> _reportarPresencia() async {
    if (_idConductorPresencia <= 0) return;
    try {
      if (!await asegurarPermisoUbicacion()) return;
      final enViaje = _idServicioGps > 0;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: enViaje ? LocationAccuracy.high : LocationAccuracy.medium,
        ),
      );
      if (_conectadoWs) {
        await _signalr.reportarUbicacion(pos.latitude, pos.longitude,
            idServicio: enViaje ? _idServicioGps : null);
      } else {
        await _api.actualizarUbicacion(
            _idConductorPresencia, pos.latitude.toString(), pos.longitude.toString());
      }
      _ultimaUbicacion = DateTime.now();
      dirEstadoUbicacion().then((d) => escribirEstadoUbicacion(d, true, _ultimaUbicacion));
      _actualizarNotificacion();
      // Refresca la hora de "ultima ubicacion enviada" en la pantalla.
      notifyListeners();
      if (_taxiActivo) await _reportarTaximetro(pos);
    } catch (_) {}
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ NOTIFICACION DE ESTADO (servicio en primer plano) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  String _textoNotificacion() {
    final estado = _conectadoWs ? '\u{1F7E2} Conectado' : '\u{26AA} Sin conexion';
    final ult = _ultimaUbicacion != null
        ? 'Ultima ubicacion: ${_hora(_ultimaUbicacion!)}'
        : 'Sin ubicacion enviada';
    return '$estado  -  $ult';
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';


  String _fechaActual() {
    final d = _ultimaUbicacion;
    if (d == null) return '--/-- --:--:--';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm ${_hora(d)}';
  }

  void _actualizarNotificacion() {
    if (_presenceTimer == null) return;
    ForegroundServiceManager.actualizar(
      titulo: 'Vaia Conductor - En servicio',
      texto: _textoNotificacion(),
    );
    // Actualiza la burbuja flotante (solo si ya esta visible)
    BubbleOverlay.actualizar(conectado: _conectadoWs, fecha: _fechaActual());
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ TAXIMETRO Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  void iniciarTaximetro() {
    _taxiActivo = true;
    _distanciaTaxi = 0;
    _ultLatTaxi = null;
    _ultLngTaxi = null;
    _inicioViajeTaxi = DateTime.now();
    _costoEnCurso = null;
    notifyListeners();
  }

  void detenerTaximetro() {
    _taxiActivo = false;
    _inicioViajeTaxi = null;
  }

  Future<void> _reportarTaximetro(Position pos) async {
    if (!_taxiActivo || _idServicioGps <= 0 || _inicioViajeTaxi == null) return;
    if (_ultLatTaxi != null && _ultLngTaxi != null) {
      final d = Geolocator.distanceBetween(_ultLatTaxi!, _ultLngTaxi!, pos.latitude, pos.longitude);
      if (d > 3 && d < 500) _distanciaTaxi += d;
    }
    _ultLatTaxi = pos.latitude;
    _ultLngTaxi = pos.longitude;
    final dur = DateTime.now().difference(_inicioViajeTaxi!).inSeconds;
    try {
      final resp = await _api.actualizarTaximetro(
          _idServicioGps, _idConductorPresencia, _distanciaTaxi.round(), dur);
      if (resp.ok && resp.data != null && resp.data!['costo'] != null) {
        _costoEnCurso = double.tryParse(resp.data!['costo'].toString());
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> registrarPago(int servicioId, int conductorId, double monto,
      {String metodo = 'CASH'}) async {
    try {
      final resp = await _api.registrarPago(servicioId, conductorId, monto, metodo: metodo);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  void _startGps(int idServicio, [int? idConductor]) {
    _idServicioGps = idServicio;
    if (idConductor != null && idConductor > 0) _idConductorPresencia = idConductor;
    if (_presenceTimer == null && _idConductorPresencia > 0) {
      iniciarPresencia(_idConductorPresencia);
    } else {
      _reiniciarTimerPresencia();
    }
  }

  void _stopGps() {
    _idServicioGps = 0;
    _reiniciarTimerPresencia();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ ACCIONES DEL SERVICIO Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<bool> acceptRide(int servicioId, int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.aceptarServicio(servicioId, conductorId);
    _loading = false;
    if (resp.ok && resp.data != null) {
      _activeRide = Servicio.fromJson(resp.data!);
      _servicioOfrecido = null;
      _hasNewRequest = false;
      await _signalr.unirseAServicio(servicioId);
      await listarParadas(servicioId);
      _startGps(servicioId, conductorId);
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> rejectRide(int servicioId, int conductorId, {String? motivo}) async {
    _loading = true; notifyListeners();
    final resp = await _api.rechazarServicio(servicioId, conductorId, motivo: motivo);
    _loading = false;
    if (resp.ok) {
      _servicioOfrecido = null;
      _hasNewRequest = false;
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> llegarAlOrigen(int servicioId, int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.llegarAlOrigen(servicioId, conductorId);
    _loading = false;
    if (resp.ok) {
      if (_activeRide != null) {
        _activeRide = Servicio.fromJson({..._activeRide!.toMap(), 'servicioEstatus': 'Llego al Origen', 'llegoalorigen': true});
      }
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Error');
    notifyListeners();
    return false;
  }

  Future<bool> startTrip(int servicioId, int conductorId, String codigoInicio) async {
    _loading = true; notifyListeners();
    final resp = await _api.iniciarViaje(servicioId, conductorId, codigoInicio);
    _loading = false;
    if (resp.ok) {
      if (resp.data != null && resp.data!.isNotEmpty) {
        _activeRide = Servicio.fromJson(resp.data!);
      } else if (_activeRide != null) {
        _activeRide = Servicio.fromJson({
          ..._activeRide!.toMap(),
          'servicioEstatus': 'En Viaje',
          'servicioiniciado': true,
        });
      }
      iniciarTaximetro();
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Codigo de inicio invalido');
    notifyListeners();
    return false;
  }

  Future<bool> finishTrip(int servicioId, int conductorId,
      {double? costoFinal, String? lat, String? lng, int? rdM, int? rdS}) async {
    _loading = true; notifyListeners();
    final resp = await _api.finalizarViaje(servicioId, conductorId,
        costoFinal: costoFinal, lat: lat, lng: lng, rdM: rdM, rdS: rdS);
    _loading = false;
    if (resp.ok) {
      await _signalr.salirDeServicio(servicioId);
      _stopGps();
      detenerTaximetro();
      _activeRide = null;
      _paradas.clear();
      notifyListeners();
      return true;
    }
    _error = resp.mensaje.isNotEmpty ? resp.mensaje : (resp.error ?? 'Error al finalizar');
    notifyListeners();
    return false;
  }

  /// Activa la alarma SOS (avisa a los administradores).
  Future<bool> activarSOS(int servicioId, int conductorId) async {
    try {
      final resp = await _api.activarAlarmaSOS(servicioId, conductorId);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  /// Concluye un servicio pendiente cobrando lo calculado o la tarifa estimada.
  Future<bool> concluirServicioPendiente(int servicioId, int conductorId, {double? costoFinal}) async {
    _loading = true;
    notifyListeners();
    final resp = await _api.concluirServicioPendiente(servicioId, conductorId, costoFinal: costoFinal);
    _loading = false;
    if (resp.ok) {
      try { await _signalr.salirDeServicio(servicioId); } catch (_) {}
      _stopGps();
      detenerTaximetro();
      _activeRide = null;
      _paradas.clear();
      notifyListeners();
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> calificarPasajero(int servicioId, int conductorId, int calificacion, {String? comentarios}) async {
    try {
      final resp = await _api.calificarPasajero(servicioId, conductorId, calificacion, comentarios: comentarios);
      return resp.ok;
    } catch (_) {
      return false;
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ PARADAS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> listarParadas(int idServicio) async {
    try {
      final resp = await _api.listarParadas(idServicio);
      _paradas.clear();
      if (resp.ok && resp.list != null) {
        for (final item in resp.list!) {
          if (item is Map) {
            _paradas.add(ParadaModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> completarParada(int idParada) async {
    final conductorId = _activeRide?.idConductor ?? 0;
    try {
      final resp = await _api.completarParada(idParada, conductorId);
      if (resp.ok && _activeRide != null) {
        await listarParadas(_activeRide!.id);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ HISTORIAL Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> loadHistory(int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.historialViajes(conductorId);
    if (resp.ok && resp.list != null) {
      _history = resp.list!.map((e) => Servicio.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    _loading = false; notifyListeners();
  }

  Future<Servicio?> getDetail(int servicioId, int conductorId) async {
    final resp = await _api.detalleViaje(servicioId, conductorId);
    if (resp.ok && resp.data != null) {
      return Servicio.fromJson(resp.data!);
    }
    return null;
  }

  /// Limpia la solicitud ofrecida (al ignorarla o cerrarla) para que no se
  /// vuelva a mostrar la tarjeta.
  void limpiarOfrecido() {
    _servicioOfrecido = null;
    _hasNewRequest = false;
    notifyListeners();
  }

  void clearServicioOfrecido() {
    _servicioOfrecido = null;
    _hasNewRequest = false;
    notifyListeners();
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    stopPolling();
    detenerPresencia();
    _subEventos?.cancel();
    _subConexion?.cancel();
    super.dispose();
  }
}
