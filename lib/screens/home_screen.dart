import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/servicio_model.dart';
import '../models/unidad_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/bubble_overlay.dart';
import '../services/marker_icons.dart';
import '../services/sound_service.dart';
import '../widgets/vaia_widgets.dart';
import '../widgets/email_verification_sheet.dart';
import '../widgets/onboarding_checklist.dart';
import '../widgets/app_tour_dialog.dart';
import '../providers/profile_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  RideProvider? _ride;
  AuthProvider? _authRef;
  final _api = ApiService();
  Map<String, dynamic>? _resumen;
  Timer? _resumenTimer;
  Timer? _gpsTimer;
  Timer? _batteryTimer;
  Timer? _horaTimer;
  int _horaActual = 0;
  bool _horaManual = false;
  final _battery = Battery();
  bool _wakelockActivo = false;
  bool _alertaAbierta = false;

  // Mapa de zonas de demanda / conexion
  GoogleMapController? _mapController;
  final Set<Marker> _mapMarkers = {};
  final Set<Circle> _mapCircles = {};
  double _bearing = 0;
  int? _diaDemanda;
  int? _horaDemanda;
  bool _ocultarPaneles = false;
  Position? _miPosicion;
  StreamSubscription<Position>? _posSub;
  bool _siguiendo = true;
  double _velocidadKmh = 0;
  DateTime? _ultimaMuestraVelocidad;
  DateTime? _ultimoAvisoVelocidad;
  Position? _posVelocidadAnterior;
  DateTime? _fechaVelocidadAnterior;
  Timer? _velocidadTimer;

  /// Pide permiso de ubicacion, centra el mapa en el conductor y sigue su
  /// movimiento con un stream de posiciones.
  Future<void> _iniciarSeguimiento() async {
    final ride = context.read<RideProvider>();
    final ok = await ride.asegurarPermisoUbicacion();
    if (!ok || !mounted) return;

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos != null && mounted) {
      setState(() {
        _miPosicion = pos;
        _actualizarMarcadorConductor();
      });
      _actualizarVelocidad(pos);
      _centrarEnConductor();
    }

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 8),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _miPosicion = pos;
        _actualizarMarcadorConductor();
      });
      _actualizarVelocidad(pos);
      if (_siguiendo) _centrarEnConductor();
    });
  }

  void _actualizarVelocidad(Position pos) {
    final ahora = DateTime.now();
    double? kmh;
    if (pos.speed.isFinite && pos.speed >= 0) {
      kmh = pos.speed * 3.6;
    }

    final anterior = _posVelocidadAnterior;
    final fechaAnterior = _fechaVelocidadAnterior;
    if ((kmh == null || kmh <= 0.5) && anterior != null && fechaAnterior != null) {
      final segundos = ahora.difference(fechaAnterior).inMilliseconds / 1000.0;
      if (segundos > 0.75 && segundos < 12) {
        final metros = Geolocator.distanceBetween(
          anterior.latitude,
          anterior.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (metros > 2) kmh = (metros / segundos) * 3.6;
      }
    }

    _posVelocidadAnterior = pos;
    _fechaVelocidadAnterior = ahora;

    if (kmh == null || !kmh.isFinite) return;
    final valor = kmh.clamp(0, 250).toDouble();
    _ultimaMuestraVelocidad = ahora;
    setState(() => _velocidadKmh = valor);
    _evaluarExcesoVelocidad(ahora);
  }

  void _evaluarExcesoVelocidad(DateTime ahora) {
    if (_velocidadKmh > 85) {
      final ultimo = _ultimoAvisoVelocidad;
      if (ultimo == null || ahora.difference(ultimo) >= const Duration(seconds: 10)) {
        _ultimoAvisoVelocidad = ahora;
        SoundService.excesoVelocidad();
      }
    } else if (_velocidadKmh < 82) {
      _ultimoAvisoVelocidad = null;
    }
  }

  void _centrarEnConductor() {
    final p = _miPosicion;
    if (p == null) return;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 15.5));
  }

  void _actualizarMarcadorConductor() {
    _mapMarkers.removeWhere((m) => m.markerId.value == 'mi_ubicacion');
    final p = _miPosicion;
    if (p == null) return;
    if (!p.heading.isNaN && p.heading >= 0) _bearing = p.heading;
    _mapMarkers.add(Marker(
      markerId: const MarkerId('mi_ubicacion'),
      position: LatLng(p.latitude, p.longitude),
      icon: MarkerIcons.car ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      rotation: _bearing,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(title: 'Mi ubicacion'),
      zIndex: 5,
    ));
  }

  /// Carga las zonas de mayor demanda (servicios historicos) y las zonas
  /// donde mas se conectan los pasajeros.
  Future<void> _cargarMapa() async {
    try {
      final p = _miPosicion;
      final rd = await _api.zonasDemanda(
        dias: 30,
        lat: p?.latitude.toString(),
        lng: p?.longitude.toString(),
        radioKm: 10,
        diaSemana: _diaDemanda,
        hora: _horaDemanda,
      );
      final rc = await _api.zonasConexion();
      final demanda = rd.list ?? [];
      final conexion = rc.list ?? [];

      int totalDe(dynamic e) => int.tryParse((e as Map)['total']?.toString() ?? '') ?? 0;
      double? latDe(dynamic e) => double.tryParse((e as Map)['lat']?.toString() ?? '');
      double? lngDe(dynamic e) => double.tryParse((e as Map)['lng']?.toString() ?? '');

      final maxD = demanda.fold<int>(1, (m, e) => totalDe(e) > m ? totalDe(e) : m);
      final circles = <Circle>{};
      // Mapa de calor tipo termico: capas concentricas muy tenues que se suman
      // hacia el centro. Entre mas servicios historicos tenga la zona, mas
      // notoria se vuelve (nunca un circulo solido).
      const capas = 5;
      for (var i = 0; i < demanda.length; i++) {
        final e = demanda[i];
        final lat = latDe(e);
        final lng = lngDe(e);
        if (lat == null || lng == null) continue;
        final ratio = (totalDe(e) / maxD).clamp(0.0, 1.0);
        final radioMax = 320 + ratio * 820;
        final alphaCapa = 0.03 + ratio * 0.04;
        for (var k = 0; k < capas; k++) {
          final frac = 1.0 - k * (0.85 / capas); // 1.00 .. 0.32
          final calor = (1 - frac).clamp(0.0, 1.0);
          final color = Color.lerp(VaiaColors.accent, VaiaColors.danger, calor)!;
          circles.add(Circle(
            circleId: CircleId('dem_${i}_$k'),
            center: LatLng(lat, lng),
            radius: radioMax * frac,
            fillColor: color.withValues(alpha: alphaCapa),
            strokeWidth: 0,
          ));
        }
      }

      final markers = <Marker>{};
      for (var i = 0; i < conexion.length; i++) {
        final e = conexion[i];
        final lat = latDe(e);
        final lng = lngDe(e);
        if (lat == null || lng == null) continue;
        markers.add(Marker(
          markerId: MarkerId('con_$i'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: 'Pasajeros conectados: ${totalDe(e)}'),
        ));
      }

      if (!mounted) return;
      setState(() {
        _mapCircles
          ..clear()
          ..addAll(circles);
        _mapMarkers
          ..clear()
          ..addAll(markers);
      });
      // Vuelve a colocar el marcador propio (fue removido al limpiar).
      _actualizarMarcadorConductor();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _cargarResumen() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final r = await _api.resumenDia(auth.userId);
      if (!mounted || r.data == null) return;
      setState(() => _resumen = r.data);
    } catch (_) {}
  }

  String _fmtMinutos(dynamic v) {
    final m = int.tryParse(v?.toString() ?? '') ?? 0;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ride = context.read<RideProvider>();
      _ride = ride;
      _authRef = auth;
      auth.addListener(_onAuthChanged);
      ride.setOnline(auth.isOnline);
      if (!auth.isLoggedIn) return;
      ride.startPolling(auth.userId);
      ride.iniciarPresencia(auth.userId);
      await context.read<ProfileProvider>().loadUnidades(auth.userId);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await mostrarTourConductor(context);
      if (!mounted) return;
      await _verificarContactoEmergencia(auth);
      if (!mounted) return;
      await _promptEmailVerification(auth);
      if (!mounted) return;
      await _seleccionarUnidadPredeterminada();
      // Si quedo un servicio sin concluir, se le pide cerrarlo.
      await ride.revisarServicioActivo(auth.userId);
      if (mounted && ride.activeRide != null) {
        await _revisarServicioPendiente(ride.activeRide!);
      }
      _cargarMapa();
      _iniciarSeguimiento();
      MarkerIcons.cargar().then((_) { if (mounted) setState(() => _actualizarMarcadorConductor()); });
      _cargarResumen();
      _resumenTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cargarResumen());
      // Vigila que el GPS siga activo mientras el conductor esta conectado.
      _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) => _vigilarGps());
      // Vigila la bateria: sin carga y por debajo del 20% se desconecta.
      _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) => _vigilarBateria());
      // El mapa de calor refleja la hora actual; se refresca al cambiar de hora.
      _horaActual = DateTime.now().hour;
      _horaDemanda = _horaActual;
      _horaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        final h = DateTime.now().hour;
        if (h != _horaActual) {
          _horaActual = h;
          if (!_horaManual && mounted) {
            setState(() => _horaDemanda = h);
            _cargarMapa();
          }
        }
      });
      _velocidadTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted) return;
        final ultima = _ultimaMuestraVelocidad;
        if (ultima != null &&
            DateTime.now().difference(ultima) > const Duration(seconds: 5) &&
            _velocidadKmh > 0) {
          setState(() => _velocidadKmh = 0);
          _evaluarExcesoVelocidad(DateTime.now());
        }
      });
    });
  }

  /// Si el conductor esta conectado, sin servicio activo, con bateria menor al
  /// 20% y sin estar cargando, se desconecta para no quedarse sin energia.
  Future<void> _vigilarBateria() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isOnline) return;
    final ride = context.read<RideProvider>();
    if (ride.activeRide != null) return; // En servicio no se desconecta.
    try {
      final nivel = await _battery.batteryLevel;
      final estado = await _battery.batteryState;
      final cargando = estado == BatteryState.charging || estado == BatteryState.full;
      if (nivel < 20 && !cargando) {
        await auth.toggleOnline();
        if (mounted) await _avisoBateria(nivel);
      }
    } catch (_) {}
  }

  Future<void> _avisoBateria(int nivel) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        icon: const Icon(Icons.battery_alert_rounded, color: VaiaColors.danger, size: 38),
        title: const Text('Bateria baja'),
        content: Text(
            'Tu bateria esta al $nivel% y no esta cargando, por lo que te desconectamos para que no te quedes sin energia. Conecta tu telefono al cargador y vuelve a conectarte.'),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  /// Si el conductor esta conectado y apaga el GPS, se desconecta y se le pide
  /// reactivarlo: sin GPS no puede reportar su ubicacion.
  Future<void> _vigilarGps() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isOnline) return;
    final activo = await Geolocator.isLocationServiceEnabled();
    if (activo || !mounted) return;
    await auth.toggleOnline();
    if (mounted) await _verificarGps(soloAviso: true);
  }

  /// Si al ingresar existe un servicio sin concluir, se le pide cerrarlo
  /// (cobrando solo lo calculado o la tarifa estimada) para poder laborar.
  Future<void> _revisarServicioPendiente(Servicio s) async {
    final ride = context.read<RideProvider>();
    final auth = context.read<AuthProvider>();

    // Si el viaje ya estaba iniciado, se continua en la pantalla del servicio.
    if ((s.servicioEstatus ?? '') == 'En Viaje') {
      Navigator.pushNamed(context, '/service_status');
      return;
    }

    final concluir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        icon: const Icon(Icons.warning_amber_rounded, color: VaiaColors.warning, size: 38),
        title: const Text('Servicio pendiente'),
        content: Text(
            'Quedo un servicio sin concluir (#${s.id}). Para poder volver a laborar debes concluirlo. Se cobrara unicamente lo calculado hasta el momento o la tarifa estimada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ver servicio')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Concluir ahora')),
        ],
      ),
    );

    if (concluir == true) {
      final ok = await ride.concluirServicioPendiente(s.id, auth.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Servicio concluido. Ya puedes laborar.' : (ride.error ?? 'No se pudo concluir')),
        backgroundColor: ok ? VaiaColors.success : VaiaColors.danger,
      ));
    } else {
      Navigator.pushNamed(context, '/service_status');
    }
  }

  /// Muestra la burbuja flotante al minimizar/cerrar la app y la oculta al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ride = _ride;
    if (ride == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // La app pasa a segundo plano: el servicio en primer plano toma el
      // reporte de ubicacion y la burbuja se muestra automaticamente.
      ride.marcarPrimerPlano(false);
      ride.mostrarBurbuja();
    } else if (state == AppLifecycleState.resumed) {
      ride.marcarPrimerPlano(true);
      ride.ocultarBurbuja();
    }
  }

  /// Si el conductor tiene varias unidades aprobadas y ninguna seleccionada,
  /// se le pide elegir con cual va a laborar.
  Future<void> _seleccionarUnidadPredeterminada() async {
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();
    final aprobadas = profile.unidades.where((u) => u.aprobada == true).toList();
    if (aprobadas.isEmpty || aprobadas.any((u) => u.enUso == true)) return;
    if (!mounted) return;

    final elegida = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _UnidadPickerSheet(unidades: aprobadas),
    );
    if (elegida == null || !mounted) return;
    await profile.selectUnidad(auth.userId, elegida);
  }

  /// Solicita verificar el correo si aun no esta confirmado (con opcion de
  /// corregirlo). Se pide cada vez que el conductor ingresa.
  Future<void> _promptEmailVerification(AuthProvider auth) async {
    final c = auth.conductor;
    if (c == null || c.correoConfirmado == true) return;
    if (!mounted) return;

    await EmailVerificationSheet.mostrar(context);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final ride = context.read<RideProvider>();
    ride.setOnline(auth.isOnline);
    if (auth.isLoggedIn && auth.userId > 0) {
      ride.startPolling(auth.userId);
      ride.iniciarPresencia(auth.userId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authRef?.removeListener(_onAuthChanged);
    _posSub?.cancel();
    _gpsTimer?.cancel();
    _batteryTimer?.cancel();
    WakelockPlus.disable();
    _horaTimer?.cancel();
    _velocidadTimer?.cancel();
    _resumenTimer?.cancel();
    _ride?.stopPolling();
    _ride?.detenerPresencia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ride = context.watch<RideProvider>();

    // Mantiene la pantalla encendida mientras el conductor esta conectado.
    if (auth.isOnline != _wakelockActivo) {
      _wakelockActivo = auth.isOnline;
      WakelockPlus.toggle(enable: auth.isOnline);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Servicio entrante -> tarjeta de alerta. Se muestra UNA sola vez y no
      // se empalma con otras.
      if (ride.servicioOfrecido != null && ride.hasNewRequest && !_alertaAbierta) {
        _alertaAbierta = true;
        await Navigator.pushNamed(context, '/service_alert');
        _alertaAbierta = false;
      }
    });

    return PopScope(
      canPop: !auth.isOnline,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmarCierre(auth);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context, auth),
              Expanded(
                child: ride.activeRide != null
                    ? _buildActiveRideView(ride)
                    : _buildIdleView(context, auth, ride),
              ),
              _buildBottomPanel(context, auth, ride),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: VaiaColors.primary,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.insights_rounded), label: 'Demanda'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Ganancias'),
          ],
          onTap: (i) {
            if (i == 0) return;
            // La demanda se puede consultar sin desconectarse.
            if (i == 2) {
              _abrirDemandaSheet();
              return;
            }
            // Conectado: solo se esperan servicios. Para otra seccion hay que
            // desconectarse primero.
            if (auth.isOnline) {
              _aviso('Desconectate para acceder a esta seccion');
              return;
            }
            switch (i) {
              case 1: Navigator.pushNamed(context, '/history');
              case 3: Navigator.pushNamed(context, '/profile');
              case 4: Navigator.pushNamed(context, '/earnings');
            }
          },
        ),
      ),
    );
  }

  String _fmtHora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: VaiaColors.warning,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Advierte al conductor conectado antes de cerrar la app.
  Future<void> _confirmarCierre(AuthProvider auth) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        icon: const Icon(Icons.warning_amber_rounded, color: VaiaColors.warning, size: 38),
        title: const Text('Estas conectado'),
        content: const Text(
            'Si cierras la app dejarias de recibir servicios y no podras trabajar. ¿Deseas salir de todas formas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir conectado')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VaiaColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (salir != true || !mounted) return;
    await auth.toggleOnline();
    if (mounted) Navigator.of(context).pop();
  }

  /// Explica que se necesita "Permitir todo el tiempo" para seguir enviando
  /// la ubicacion cuando la app esta minimizada (modo burbuja).
  Future<void> _solicitarPermisoSegundoPlano() async {
    final abrir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        icon: const Icon(Icons.location_on_rounded, color: VaiaColors.primary, size: 38),
        title: const Text('Ubicacion en segundo plano'),
        content: const Text(
            'Para seguir enviando tu ubicacion cuando la app esta minimizada o en la burbuja, en los permisos de ubicacion selecciona "Permitir todo el tiempo".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mas tarde')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir ajustes')),
        ],
      ),
    );
    if (abrir == true) await Geolocator.openAppSettings();
  }

  /// El GPS es obligatorio: si esta apagado no se permite conectarse.
  Future<bool> _verificarGps({bool soloAviso = false}) async {
    final activo = await Geolocator.isLocationServiceEnabled();
    if (activo) return true;
    if (!mounted) return false;
    if (soloAviso) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
          icon: const Icon(Icons.gps_off_rounded, color: VaiaColors.danger, size: 38),
          title: const Text('GPS desactivado'),
          content: const Text(
              'Tu ubicacion dejo de enviarse y por eso te desconectamos. El GPS es indispensable para trabajar; activalo para volver a conectarte.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openLocationSettings();
              },
              child: const Text('Activar GPS'),
            ),
          ],
        ),
      );
      return false;
    }
    final abrir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        icon: const Icon(Icons.gps_off_rounded, color: VaiaColors.danger, size: 38),
        title: const Text('GPS desactivado'),
        content: const Text(
            'El GPS es indispensable para enviar tu ubicacion a los pasajeros y administradores. Activalo para poder conectarte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Activar GPS')),
        ],
      ),
    );
    if (abrir == true) await Geolocator.openLocationSettings();
    return false;
  }

  Widget _buildTopBar(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const VaiaLogo(size: 40, showText: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${auth.conductor?.nombre ?? "Conductor"}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                Row(
                  children: [
                    VaiaStatusDot(online: auth.isOnline, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      auth.isOnline ? 'En linea' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 11,
                        color: auth.isOnline ? VaiaColors.onlineGreen : VaiaColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _iconAction(context, Icons.support_agent_rounded, () {
            // El soporte esta disponible siempre (con o sin servicio activo).
            final s = context.read<RideProvider>().activeRide;
            Navigator.pushNamed(context, '/support_chat', arguments: {'idServicio': s?.id});
          }),
          _iconAction(context, Icons.notifications_outlined, () => Navigator.pushNamed(context, '/notifications')),
          _iconAction(context, Icons.picture_in_picture_alt_rounded, () async {
            await context.read<RideProvider>().mostrarBurbuja();
            await BubbleOverlay.minimizar();
          }),
        ],
      ),
    );
  }

  Widget _iconAction(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: VaiaColors.textPrimary),
        ),
      ),
    );
  }

  Future<void> _abrirDemandaSheet() async {
    final p = _miPosicion;
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VaiaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: _DemandaSheet(lat: p?.latitude, lng: p?.longitude),
      ),
    );
    if (res == null || !mounted) return;
    final dia = res['dia'] as int?;
    final hora = res['hora'] as int?;
    if (dia == null || hora == null) return;
    final ahora = DateTime.now();
    setState(() {
      // Si el conductor elige el dia y la hora actuales, el mapa puede seguir
      // actualizandose solo cuando cambie la hora.
      _horaManual = !(dia == ahora.weekday && hora == ahora.hour);
      _diaDemanda = dia;
      _horaDemanda = hora;
    });
    _cargarMapa();
    const nombres = ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Mostrando demanda de ${nombres[dia - 1]} a las ${hora.toString().padLeft(2, '0')}:00',
      ),
      backgroundColor: VaiaColors.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }


  /// El conductor no puede conectarse sin un contacto de emergencia.
  Future<bool> _verificarContactoEmergencia(AuthProvider auth) async {
    try {
      final res = await _api.obtenerContactoEmergencia(auth.userId);
      if (!res.ok) return true;
      if (res.list != null && res.list!.isNotEmpty) return true;
    } catch (_) {
      return true;
    }
    if (auth.isOnline) {
      try { await auth.toggleOnline(); } catch (_) {}
    }
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.health_and_safety_outlined, color: VaiaColors.danger, size: 38),
        title: const Text('Contacto de emergencia obligatorio'),
        content: const Text(
          'Antes de conectarte debes registrar al menos un contacto de emergencia. Es necesario para poder ayudarte si activas un SOS.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Configurar ahora'),
          ),
        ],
      ),
    );
    return false;
  }
  Widget _buildIdleView(BuildContext context, AuthProvider auth, RideProvider ride) {
    return Stack(
      children: [
        // Mapa con las zonas de mayor demanda y de conexion de pasajeros
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(26.0923, -98.2789), zoom: 14.5),
          onMapCreated: (c) {
            _mapController = c;
            _centrarEnConductor();
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          markers: _mapMarkers,
          circles: _mapCircles,
        ),
        // Estado de conexion (socket) y ultima ubicacion enviada al servidor
        Positioned(top: 10, left: 10, child: _chipEstado(ride)),
        // Boton para ocultar/mostrar las tarjetas y ver el mapa mas amplio
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: VaiaColors.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(VaiaRadius.md),
            child: InkWell(
              onTap: () => setState(() => _ocultarPaneles = !_ocultarPaneles),
              borderRadius: BorderRadius.circular(VaiaRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_ocultarPaneles ? Icons.map_rounded : Icons.visibility_off_rounded, size: 17, color: VaiaColors.primary),
                  const SizedBox(width: 6),
                  Text(_ocultarPaneles ? 'Ver tarjetas' : 'Ver mapa',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: VaiaColors.primary)),
                ]),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          bottom: _ocultarPaneles ? 70 : 122,
          child: _indicadorVelocidad(),
        ),
        // Boton para centrar y seguir al conductor en el mapa
        Positioned(
          right: 14,
          bottom: _ocultarPaneles ? 70 : 122,
          child: FloatingActionButton.small(
            heroTag: 'centrar_mapa',
            backgroundColor: VaiaColors.surface,
            foregroundColor: _siguiendo ? VaiaColors.primary : VaiaColors.textSecondary,
            onPressed: () {
              setState(() => _siguiendo = true);
              _centrarEnConductor();
            },
            child: Icon(_siguiendo ? Icons.my_location_rounded : Icons.location_searching_rounded),
          ),
        ),
        if (!_ocultarPaneles) ...[
          const Positioned(top: 64, left: 0, right: 0, child: OnboardingChecklist()),
          Positioned(bottom: 14, left: 14, right: 14, child: _estadoCard(context, auth)),
        ] else
          Positioned(bottom: 14, left: 14, child: _leyendaMapa()),
      ],
    );
  }

  Widget _indicadorVelocidad() {
    final excede = _velocidadKmh > 85;
    final velocidad = _velocidadKmh.round();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: excede ? VaiaColors.danger : Colors.white.withValues(alpha: 0.22),
          width: excede ? 1.6 : 1,
        ),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$velocidad',
            style: TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: excede ? VaiaColors.danger : Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'km/h',
            style: TextStyle(
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: excede ? VaiaColors.danger : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipEstado(RideProvider ride) {
    final conectado = ride.conectadoWs;
    final color = conectado ? VaiaColors.onlineGreen : VaiaColors.warning;
    final ult = ride.ultimaUbicacion;
    final hora = ult != null
        ? '${ult.hour.toString().padLeft(2, '0')}:${ult.minute.toString().padLeft(2, '0')}:${ult.second.toString().padLeft(2, '0')}'
        : '--:--:--';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: VaiaColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(conectado ? 'En vivo' : 'Sin conexion',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 3),
          Text('Ultima ubicacion: $hora', style: const TextStyle(fontSize: 10.5, color: VaiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _estadoCard(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        boxShadow: VaiaShadows.elevated,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (auth.isOnline ? VaiaColors.primary : VaiaColors.textMuted).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(VaiaRadius.md),
            ),
            child: Icon(Icons.local_taxi_rounded, size: 28, color: auth.isOnline ? VaiaColors.primary : VaiaColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.isOnline ? 'Esperando solicitudes' : 'Estas desconectado',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  auth.isOnline ? 'Mantente cerca de las zonas con mas demanda' : 'Conectate para empezar a recibir viajes',
                  style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (auth.isOnline)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VaiaColors.primary)),
        ],
      ),
    );
  }

  Widget _leyendaMapa() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: VaiaColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Zonas de demanda', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: VaiaColors.danger.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(color: VaiaColors.danger),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Mas servicios', style: TextStyle(fontSize: 10.5, color: VaiaColors.textSecondary)),
          ]),
          const SizedBox(height: 4),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, size: 13, color: Color(0xFF3B82F6)),
            SizedBox(width: 6),
            Text('Mas pasajeros conectados', style: TextStyle(fontSize: 10.5, color: VaiaColors.textSecondary)),
          ]),
        ],
      ),
    );
  }


  Widget _buildActiveRideView(RideProvider ride) {
    final s = ride.activeRide;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: VaiaColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VaiaBadge(label: 'Viaje activo', color: Colors.white, filled: false),
              const SizedBox(height: 12),
              Text(
                s?.pasajeroNombre ?? 'Pasajero',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 10),
              _rideDetail(const MarkerIcon(origin: true, size: 18), 'Origen', s?.direccionOrigen ?? '-'),
              const SizedBox(height: 10),
              _rideDetail(const MarkerIcon(origin: false, size: 18), 'Destino', s?.direccionDestino ?? '-'),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (s?.distanciaMetros != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(VaiaRadius.pill),
                      ),
                      child: Text(
                        '${(s!.distanciaMetros! / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  const Spacer(),
                  if (s?.costoEstimado != null)
                    Text(
                      '\$${s!.costoEstimado!.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rideDetail(Widget icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: icon,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context, AuthProvider auth, RideProvider ride) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statTile(Icons.monetization_on_rounded, 'Ganancias',
                      '\$${(double.tryParse(_resumen?['gananciasdia']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}', VaiaColors.onlineGreen),
                  _statTile(Icons.route_rounded, 'Servicios', (_resumen?['serviciosdia'] ?? 0).toString(), VaiaColors.primary),
                  _statTile(Icons.timer_outlined, 'Conectado', _fmtMinutos(_resumen?['minutosconectado']), VaiaColors.accent),
                  _statTile(Icons.star_rounded, 'Rating', auth.conductor?.calificacionPromedio?.toStringAsFixed(1) ?? '0.0', VaiaColors.warning),
                ],
              ),
              if (auth.isOnline) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ride.ultimaUbicacion != null
                          ? Icons.location_on_rounded
                          : (ride.errorUbicacion != null ? Icons.location_off_rounded : Icons.location_searching_rounded),
                      size: 14,
                      color: ride.ultimaUbicacion != null
                          ? VaiaColors.onlineGreen
                          : (ride.errorUbicacion != null ? VaiaColors.danger : VaiaColors.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        ride.ultimaUbicacion != null
                            ? 'Ultima ubicacion enviada: ${_fmtHora(ride.ultimaUbicacion!)}'
                            : (ride.errorUbicacion ?? 'Enviando ubicacion...'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ride.ultimaUbicacion == null && ride.errorUbicacion != null
                              ? VaiaColors.danger
                              : VaiaColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    // El contacto de emergencia y el GPS son obligatorios.
                    if (!auth.isOnline) {
                      final okContacto = await _verificarContactoEmergencia(auth);
                      if (!okContacto || !mounted) return;
                      final okGps = await _verificarGps();
                      if (!okGps || !mounted) return;
                    }
                    final ok = await auth.toggleOnline();
                    if (!mounted) return;
                    if (!ok) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(auth.error ?? 'No se pudo cambiar el estatus'),
                        backgroundColor: VaiaColors.danger,
                      ));
                    } else {
                      _cargarResumen();
                      if (auth.isOnline && mounted) {
                        final ride = context.read<RideProvider>();
                        await ride.asegurarPermisoUbicacion();
                        if (mounted && ride.necesitaPermisoSegundoPlano) {
                          await _solicitarPermisoSegundoPlano();
                        }
                      }
                    }
                  },
                  icon: Icon(
                    auth.isOnline ? Icons.power_settings_new_rounded : Icons.wifi_tethering_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    auth.isOnline ? 'Desconectarse' : 'Conectarse',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: auth.isOnline ? VaiaColors.offlineRed : VaiaColors.onlineGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(VaiaRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 9.5, color: VaiaColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceRequestDialog extends StatelessWidget {
  final Servicio servicio;
  const ServiceRequestDialog({super.key, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = servicio;

    return Dialog(
      backgroundColor: VaiaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_active_rounded, color: VaiaColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Nueva solicitud', style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (s.pasajeroNombre != null)
              Text(s.pasajeroNombre!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _iconRow(context, const MarkerIcon(origin: true, size: 18), 'Origen', s.direccionOrigen, VaiaColors.onlineGreen),
            const SizedBox(height: 8),
            _iconRow(context, const MarkerIcon(origin: false, size: 18), 'Destino', s.direccionDestino, VaiaColors.danger),
            const SizedBox(height: 10),
            Row(
              children: [
                if (s.distanciaMetros != null) _infoChip(context, '${(s.distanciaMetros! / 1000).toStringAsFixed(1)} km'),
                const SizedBox(width: 8),
                if (s.costoEstimado != null) _infoChip(context, '\$${s.costoEstimado!.toStringAsFixed(2)}', primary: true),
                const Spacer(),
                if (s.tipoViaje != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VaiaColors.primaryGhost,
                      borderRadius: BorderRadius.circular(VaiaRadius.pill),
                    ),
                    child: Text(s.tipoViaje!, style: const TextStyle(fontSize: 11, color: VaiaColors.primary, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ride.rejectRide(s.id, auth.userId);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VaiaColors.danger,
                      side: const BorderSide(color: VaiaColors.danger, width: 1.2),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
                    ),
                    child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ride.acceptRide(s.id, auth.userId);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VaiaColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(BuildContext context, Widget icon, String label, String? value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: icon,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: VaiaColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value ?? '-', style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip(BuildContext context, String text, {bool primary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary ? VaiaColors.primary : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(VaiaRadius.pill),
        border: primary ? null : Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primary ? Colors.white : VaiaColors.textPrimary,
        ),
      ),
    );
  }
}


/// Hoja para que el conductor elija con cual unidad aprobada va a laborar.
class _UnidadPickerSheet extends StatelessWidget {
  final List<Unidad> unidades;
  const _UnidadPickerSheet({required this.unidades});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: VaiaColors.primaryGradient, borderRadius: BorderRadius.circular(VaiaRadius.md)),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Elige tu unidad', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text('Selecciona con cual vas a laborar', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VaiaColors.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 18),
              ...unidades.map((u) => _card(context, u)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Unidad u) {
    final detalle = [u.anio?.toString(), u.color].where((e) => e != null && e.isNotEmpty).join(' - ');
    return InkWell(
      onTap: () => Navigator.pop(context, u.id),
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VaiaColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          border: Border.all(color: VaiaColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.directions_car_filled_rounded, color: VaiaColors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            if (detalle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12)),
            ],
          ])),
          const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
        ]),
      ),
    );
  }
}

/// Demanda historica por dia y hora (matriz 7x24). Cada dia se muestra en una
/// pagina deslizable y dentro de ella las 24 horas aparecen como barras
/// proporcionales. Al tocar una barra se filtra el mapa de calor.
class _DemandaSheet extends StatefulWidget {
  final double? lat;
  final double? lng;
  const _DemandaSheet({this.lat, this.lng});
  @override
  State<_DemandaSheet> createState() => _DemandaSheetState();
}

class _DemandaSheetState extends State<_DemandaSheet> {
  static const _nombresDias = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];
  final _api = ApiService();
  late final PageController _pageCtrl;
  late int _dia;
  bool _cargando = true;
  bool _error = false;
  List<List<int>> _m = List.generate(7, (_) => List.filled(24, 0));
  int _max = 0;

  @override
  void initState() {
    super.initState();
    _dia = DateTime.now().weekday;
    _pageCtrl = PageController(initialPage: _dia - 1);
    _cargar();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (mounted) {
      setState(() {
        _cargando = true;
        _error = false;
      });
    }
    try {
      final r = await _api.demandaPorDiaHora(
        lat: widget.lat?.toString(),
        lng: widget.lng?.toString(),
        radioKm: 10,
        dias: 30,
      );
      if (!r.ok) {
        if (mounted) {
          setState(() {
            _cargando = false;
            _error = true;
          });
        }
        return;
      }
      final m = List.generate(7, (_) => List.filled(24, 0));
      int mx = 0;
      for (final e in (r.list ?? [])) {
        final mm = Map<String, dynamic>.from(e as Map);
        final d = int.tryParse(mm['dia']?.toString() ?? '') ?? 0;
        final h = int.tryParse(mm['hora']?.toString() ?? '') ?? 0;
        final t = int.tryParse(mm['total']?.toString() ?? '') ?? 0;
        if (d >= 1 && d <= 7 && h >= 0 && h <= 23) {
          m[d - 1][h] = t;
          if (t > mx) mx = t;
        }
      }
      if (mounted) {
        setState(() {
          _m = m;
          _max = mx;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = true;
        });
      }
    }
  }

  void _irADia(int delta) {
    final destino = (_dia + delta).clamp(1, 7);
    if (destino == _dia) return;
    _pageCtrl.animateToPage(
      destino - 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().weekday;
    final esHoy = _dia == hoy;
    final horaActual = DateTime.now().hour;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: VaiaColors.borderStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: VaiaColors.primaryGhost,
                    borderRadius: BorderRadius.circular(VaiaRadius.md),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: VaiaColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demanda por dia y hora',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ultimos 30 dias - 10 km a la redonda',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: VaiaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: VaiaColors.textMuted,
                  ),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: Row(
              children: [
                IconButton(
                  onPressed: _dia > 1 ? () => _irADia(-1) : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                  color: VaiaColors.textSecondary,
                  tooltip: 'Dia anterior',
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _nombresDias[_dia - 1],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (esHoy) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: VaiaColors.primaryGhost,
                                borderRadius: BorderRadius.circular(
                                  VaiaRadius.pill,
                                ),
                              ),
                              child: const Text(
                                'HOY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: VaiaColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        esHoy
                            ? 'Hora actual ${horaActual.toString().padLeft(2, '0')}:00 - Desliza para cambiar de dia'
                            : 'Desliza para cambiar de dia',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: VaiaColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _dia < 7 ? () => _irADia(1) : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
                  color: VaiaColors.textSecondary,
                  tooltip: 'Dia siguiente',
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 38,
                            color: VaiaColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No se pudo cargar la demanda',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _cargar,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _max == 0
                ? const Center(
                    child: Text(
                      'Aun no hay datos de demanda en tu zona',
                      style: TextStyle(color: VaiaColors.textSecondary),
                    ),
                  )
                : PageView.builder(
                    controller: _pageCtrl,
                    itemCount: 7,
                    onPageChanged: (i) => setState(() => _dia = i + 1),
                    itemBuilder: (_, i) => _DemandaDayPage(
                      valores: _m[i],
                      max: _max,
                      esHoy: i + 1 == hoy,
                      horaActual: horaActual,
                      onHora: (h) =>
                          Navigator.pop(context, {'dia': i + 1, 'hora': h}),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 9, 18, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: VaiaColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Menos',
                      style: TextStyle(
                        fontSize: 10,
                        color: VaiaColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (var i = 0; i < 5; i++)
                      Container(
                        width: 22,
                        height: 8,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: _demandaColor(
                            (_max * (i + 1) / 5).ceil(),
                            _max,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Text(
                      'Mas',
                      style: TextStyle(
                        fontSize: 10,
                        color: VaiaColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: VaiaColors.textMuted,
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Toca una barra para ver las zonas con mayor demanda en el mapa.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: VaiaColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _demandaColor(int valor, int max) {
  if (valor <= 0 || max <= 0) return VaiaColors.bgMuted;
  final r = (valor / max).clamp(0.0, 1.0);
  if (r < 0.5) {
    return Color.lerp(VaiaColors.success, VaiaColors.warning, r * 2)!;
  }
  return Color.lerp(VaiaColors.warning, VaiaColors.danger, (r - 0.5) * 2)!;
}

class _DemandaDayPage extends StatefulWidget {
  final List<int> valores;
  final int max;
  final bool esHoy;
  final int horaActual;
  final ValueChanged<int> onHora;
  const _DemandaDayPage({
    required this.valores,
    required this.max,
    required this.esHoy,
    required this.horaActual,
    required this.onHora,
  });
  @override
  State<_DemandaDayPage> createState() => _DemandaDayPageState();
}

class _DemandaDayPageState extends State<_DemandaDayPage> {
  static const double _itemExtent = 52;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    if (widget.esHoy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final objetivo = ((widget.horaActual - 2).clamp(0, 23) * _itemExtent).toDouble();
        _scroll.jumpTo(objetivo.clamp(0.0, _scroll.position.maxScrollExtent).toDouble());
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      itemExtent: _itemExtent,
      itemCount: 24,
      itemBuilder: (context, h) {
        final valor = widget.valores[h];
        final ratio = widget.max <= 0
            ? 0.0
            : (valor / widget.max).clamp(0.0, 1.0);
        final color = _demandaColor(valor, widget.max);
        final esAhora = widget.esHoy && h == widget.horaActual;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onHora(h),
              borderRadius: BorderRadius.circular(VaiaRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: esAhora
                      ? VaiaColors.primaryGhost
                      : VaiaColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VaiaRadius.md),
                  border: Border.all(
                    color: esAhora
                        ? VaiaColors.primary.withValues(alpha: 0.38)
                        : VaiaColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Row(
                        children: [
                          if (esAhora) ...[
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: VaiaColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: esAhora
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: esAhora
                                  ? VaiaColors.primary
                                  : VaiaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 20,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final ancho = valor <= 0
                                ? 0.0
                                : c.maxWidth * ratio.clamp(0.06, 1.0);
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: VaiaColors.bgMuted,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                if (ancho > 0)
                                  Container(
                                    width: ancho,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          color.withValues(alpha: 0.72),
                                          color,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '$valor',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: valor > 0
                              ? VaiaColors.textPrimary
                              : VaiaColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: VaiaColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
