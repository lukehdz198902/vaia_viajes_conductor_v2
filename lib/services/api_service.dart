import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiResponse {
  final bool ok;
  final Map<String, dynamic>? data;
  final List<dynamic>? list;
  final String? error;
  final String? message;
  final String? errorCode;
  final int? statusCode;

  ApiResponse({
    required this.ok,
    this.data,
    this.list,
    this.error,
    this.message,
    this.errorCode,
    this.statusCode,
  });

  factory ApiResponse.fromMap(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final isList = dataRaw is List;
    return ApiResponse(
      ok: json['success'] == true,
      data: dataRaw is Map<String, dynamic> ? dataRaw : (dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null),
      list: isList ? List<Map<String, dynamic>>.from(dataRaw) : null,
      message: json['message']?.toString(),
      error: json['message']?.toString(),
      errorCode: json['code']?.toString(),
      statusCode: json['code'] is int ? json['code'] : null,
    );
  }

  int get id => data?['id'] ?? 0;
  String get mensaje => message ?? '';
  int get resultado => data?['resultado'] ?? 0;
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String base = ApiConfig.apiRoot;

  Future<ApiResponse> _processResponse(http.Response resp, {bool isList = false, String? endpoint}) async {
    try {
      final body = utf8.decode(resp.bodyBytes);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = json.decode(body);
        if (decoded is Map<String, dynamic>) {
          return ApiResponse.fromMap(decoded);
        }
        if (isList) {
          final list = decoded is List ? decoded : (decoded is Map ? (decoded['data'] ?? []) : []);
          return ApiResponse(ok: true, list: List<Map<String, dynamic>>.from(list));
        }
        final map = decoded is Map<String, dynamic> ? decoded : (decoded is List && decoded.isNotEmpty ? decoded[0] : <String, dynamic>{});
        final ok = map['resultado'] != -1 && map['id'] != -1;
        return ApiResponse(ok: ok, data: map, message: map['mensaje']?.toString());
      }
      String msg = 'Error ${resp.statusCode}';
      String? code;
      try {
        final decoded = json.decode(body);
        if (decoded is Map) {
          msg = decoded['message']?.toString() ?? decoded['mensaje']?.toString() ?? msg;
          code = decoded['code']?.toString();
        }
      } catch (_) {}
      return ApiResponse(ok: false, error: msg, errorCode: code, statusCode: resp.statusCode);
    } catch (e) {
      return ApiResponse(ok: false, error: e.toString());
    }
  }

  Future<ApiResponse> ping() async {
    try {
      final resp = await http.get(Uri.parse('$base/admin/ping'))
          .timeout(ApiConfig.shortTimeout);
      if (resp.statusCode == 200) return ApiResponse(ok: true);
      return ApiResponse(ok: false);
    } catch (_) {
      return ApiResponse(ok: false);
    }
  }

  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('$base$endpoint');
      final resp = await http.post(url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode(body),
      ).timeout(ApiConfig.timeout);
      return _processResponse(resp, endpoint: endpoint);
    } catch (e) {
      return ApiResponse(ok: false, error: e.toString());
    }
  }

  Future<ApiResponse> get(String endpoint) async {
    try {
      final url = Uri.parse('$base$endpoint');
      final resp = await http.get(url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      ).timeout(ApiConfig.timeout);
      return _processResponse(resp, isList: true, endpoint: endpoint);
    } catch (e) {
      return ApiResponse(ok: false, error: e.toString());
    }
  }

  Future<ApiResponse> postForm(String endpoint, Map<String, String> fields) async {
    try {
      final url = Uri.parse('$base$endpoint');
      final req = http.MultipartRequest('POST', url);
      req.fields.addAll(fields);
      final streamed = await req.send().timeout(ApiConfig.timeout);
      final resp = await http.Response.fromStream(streamed);
      return _processResponse(resp, endpoint: endpoint);
    } catch (e) {
      return ApiResponse(ok: false, error: e.toString());
    }
  }

  Future<ApiResponse> registrarConductor(Map<String, dynamic> data) =>
      post('${ApiConfig.conductorEndpoint}/Registrar', data);

  Future<ApiResponse> iniciarSesion(String account, String pass,
      {String? googleKey, String? dispositivoInfo, String? sistemaOperativo}) =>
      post('${ApiConfig.conductorEndpoint}/IniciarSesion', {
        'account': account, 'pass': pass,
        'googlekey': googleKey ?? '',
        'dispositivoinfo': dispositivoInfo ?? '',
        'sistemaoperativo': sistemaOperativo ?? '',
      });

  Future<ApiResponse> cerrarSesion(int idConductor, String uuidsesion) =>
      post('${ApiConfig.conductorEndpoint}/CerrarSesion', {
        'idConductor': idConductor, 'uuidsesion': uuidsesion,
      });

  Future<ApiResponse> obtenerPerfil(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerPerfil?idConductor=$idConductor');

  Future<ApiResponse> actualizarPerfil(Map<String, dynamic> data) =>
      post('${ApiConfig.conductorEndpoint}/ActualizarPerfil', data);

  Future<ApiResponse> cambiarPassword(int idConductor, String passActual, String passNueva) =>
      post('${ApiConfig.conductorEndpoint}/CambiarPassword', {
        'idConductor': idConductor, 'passActual': passActual, 'pass': passNueva,
      });

  Future<ApiResponse> actualizarUbicacion(int idConductor, String lat, String lng) =>
      post('${ApiConfig.conductorEndpoint}/ActualizarUbicacion', {
        'idConductor': idConductor, 'lat': lat, 'lng': lng,
      });

  Future<ApiResponse> cambiarEstatus(int idConductor, String estatus,
      {String? lat, String? lng}) =>
      post('${ApiConfig.conductorEndpoint}/CambiarEstatus', {
        'idConductor': idConductor, 'estatus': estatus,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

  Future<ApiResponse> obtenerServicioActivo(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerServicioActivo?idConductor=$idConductor');

  Future<ApiResponse> aceptarServicio(int idServicio, int idConductor) =>
      post('${ApiConfig.conductorEndpoint}/AceptarServicio', {
        'idServicio': idServicio, 'idConductor': idConductor,
      });

  Future<ApiResponse> iniciarViaje(int idServicio, int idConductor, String codigoInicio) =>
      post('${ApiConfig.conductorEndpoint}/IniciarViaje', {
        'idServicio': idServicio, 'idConductor': idConductor, 'codigoInicio': codigoInicio,
      });

  Future<ApiResponse> finalizarViaje(int idServicio, int idConductor,
      {double? costoFinal, String? lat, String? lng, int? rdM, int? rdS}) =>
      post('${ApiConfig.conductorEndpoint}/FinalizarViaje', {
        'idServicio': idServicio, 'idConductor': idConductor,
        if (costoFinal != null) 'costoFinal': costoFinal.toString(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (rdM != null) 'rd_m': rdM,
        if (rdS != null) 'rd_s': rdS,
      });

  /// Taximetro: reporta distancia/tiempo acumulados y obtiene el costo en vivo.
  Future<ApiResponse> actualizarTaximetro(int idServicio, int idConductor, int distanciaMetros, int duracionSegundos) =>
      post('${ApiConfig.conductorEndpoint}/ActualizarTaximetro', {
        'idServicio': idServicio, 'idConductor': idConductor,
        'distanciaMetros': distanciaMetros, 'duracionSegundos': duracionSegundos,
      });

  /// Registra el pago del servicio (efectivo por defecto) y dispara el comprobante por correo.
  Future<ApiResponse> registrarPago(int idServicio, int idConductor, double monto,
      {String metodo = 'CASH', String? referencia}) =>
      post('${ApiConfig.conductorEndpoint}/RegistrarPago', {
        'idServicio': idServicio, 'idConductor': idConductor,
        'monto': monto.toString(), 'metodo': metodo,
        if (referencia != null) 'referencia': referencia,
      });

  // ─── VERIFICACION DE TELEFONO / CORREO ───────────────────────

  Future<ApiResponse> enviarCodigoVerificacion(String telefono, String codigopaistel) =>
      post('${ApiConfig.conductorEndpoint}/EnviarCodigoVerificacion', {
        'telefono': telefono, 'codigopaistel': codigopaistel,
      });

  Future<ApiResponse> validarCodigoVerificacion(String telefono, String codigopaistel, String codigo) =>
      post('${ApiConfig.conductorEndpoint}/ValidarCodigoVerificacion', {
        'telefono': telefono, 'codigopaistel': codigopaistel, 'codigo': codigo,
      });

  Future<ApiResponse> enviarCodigoCorreo(int idConductor, String correo) =>
      post('${ApiConfig.conductorEndpoint}/EnviarCodigoCorreo', {
        'idConductor': idConductor, 'correo': correo,
      });

  Future<ApiResponse> validarCodigoCorreo(String correo, String codigo) =>
      post('${ApiConfig.conductorEndpoint}/ValidarCodigoCorreo', {
        'correo': correo, 'codigo': codigo,
      });

  Future<ApiResponse> actualizarCorreo(int idConductor, String correo) =>
      post('${ApiConfig.conductorEndpoint}/ActualizarCorreo', {
        'idConductor': idConductor, 'correo': correo,
      });

  /// Registra/actualiza el token de notificaciones push (FCM) del conductor.
  Future<ApiResponse> actualizarToken(int idConductor, String token) =>
      post('${ApiConfig.conductorEndpoint}/ActualizarToken', {
        'idConductor': idConductor, 'googlekey': token,
      });

  /// Resumen del dia: ganancias, servicios realizados y minutos conectado.
  Future<ApiResponse> resumenDia(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ResumenDia?idConductor=$idConductor');

  // ─── DOCUMENTOS ──────────────────────────────────────────────

  Future<ApiResponse> listarTiposDocumento({String para = 'conductor'}) =>
      get('${ApiConfig.conductorEndpoint}/ListarTiposDocumento?para=$para');

  Future<ApiResponse> agregarDocumento(int idConductor, int idtipoarchivo, String nombre, String base64) =>
      post('${ApiConfig.conductorEndpoint}/AgregarDocumento', {
        'idConductor': idConductor, 'idtipoarchivo': idtipoarchivo,
        'nombredocumento': nombre, 'contenidoBase64': base64,
      });

  Future<ApiResponse> eliminarDocumento(int idDocumento, int idConductor) =>
      post('${ApiConfig.conductorEndpoint}/EliminarDocumento', {
        'idDocumento': idDocumento, 'idConductor': idConductor,
      });

  Future<ApiResponse> listarDocumentos(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ListarDocumentos?idConductor=$idConductor');

  Future<ApiResponse> agregarDocumentoUnidad(int idConductor, int idunidad, int idtipoarchivounidad, String nombre, String base64) =>
      post('${ApiConfig.conductorEndpoint}/AgregarDocumentoUnidad', {
        'idConductor': idConductor, 'idunidad': idunidad, 'idtipoarchivounidad': idtipoarchivounidad,
        'nombredocumento': nombre, 'contenidoBase64': base64,
      });

  Future<ApiResponse> listarDocumentosUnidad(int idConductor, int idunidad) =>
      get('${ApiConfig.conductorEndpoint}/ListarDocumentosUnidad?idConductor=$idConductor&idunidad=$idunidad');

  Future<ApiResponse> listarUnidades(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ListarUnidades?idConductor=$idConductor');

  /// Configuracion vigente que consume la app (intervalo de ubicacion, etc.).
  Future<ApiResponse> obtenerConfiguracionApp() =>
      get('${ApiConfig.conductorEndpoint}/ObtenerConfiguracionApp');

  /// Zonas con mayor demanda historica (origenes de servicios) para el mapa.
  Future<ApiResponse> zonasDemanda({int dias = 30}) =>
      get('${ApiConfig.conductorEndpoint}/ZonasDemanda?dias=$dias');

  /// Zonas donde mas se conectan los pasajeros.
  Future<ApiResponse> zonasConexion() =>
      get('${ApiConfig.conductorEndpoint}/ZonasConexion');

  Future<ApiResponse> seleccionarUnidad(int idConductor, int idUnidad) =>
      post('${ApiConfig.conductorEndpoint}/SeleccionarUnidad', {
        'idConductor': idConductor, 'idUnidad': idUnidad,
      });

  Future<ApiResponse> historialViajes(int idConductor, {int pagina = 1, int tamano = 20}) =>
      get('${ApiConfig.conductorEndpoint}/HistorialViajes?idConductor=$idConductor&pagina=$pagina&tamano=$tamano');

  Future<ApiResponse> detalleViaje(int idServicio, int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/DetalleViaje?idServicio=$idServicio&idConductor=$idConductor');

  Future<ApiResponse> obtenerSemanaCorte(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerSemanaCorte?idConductor=$idConductor');

  Future<ApiResponse> transferirSemanaCorte(int idConductor, int idSemanaCorte) =>
      post('${ApiConfig.conductorEndpoint}/TransferirSemanaCorte', {
        'idConductor': idConductor, 'idSemanaCorte': idSemanaCorte,
      });

  Future<ApiResponse> enviarMensaje(int idServicio, int idConductor, String mensaje) =>
      post('${ApiConfig.conductorEndpoint}/EnviarMensajeChat', {
        'idServicio': idServicio, 'idConductor': idConductor, 'mensaje': mensaje,
      });

  Future<ApiResponse> obtenerMensajes(int idServicio, int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerMensajesChat?idServicio=$idServicio&idConductor=$idConductor');

  Future<ApiResponse> activarAlarmaSOS(int idServicio, int idConductor) =>
      post('${ApiConfig.conductorEndpoint}/ActivarAlarmaSOS', {
        'idServicio': idServicio, 'idConductor': idConductor,
      });

  Future<ApiResponse> reportarIncidente(Map<String, dynamic> data) =>
      post('${ApiConfig.conductorEndpoint}/ReportarIncidente', data);

  Future<ApiResponse> obtenerNotificaciones(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerNotificaciones?idConductor=$idConductor');

  Future<ApiResponse> obtenerAvisos(int idCompania) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerAvisos?idCompania=$idCompania');

  // ─── ENDPOINTS NUEVOS ─────────────────────────────────────────

  Future<ApiResponse> llegarAlOrigen(int idServicio, int idConductor) =>
      post('${ApiConfig.conductorEndpoint}/LlegarAlOrigen', {
        'idServicio': idServicio, 'idConductor': idConductor,
      });

  Future<ApiResponse> rechazarServicio(int idServicio, int idConductor, {String? motivo}) =>
      post('${ApiConfig.conductorEndpoint}/RechazarServicio', {
        'idservicio': idServicio, 'idconductor': idConductor, if (motivo != null) 'motivo': motivo,
      });

  Future<ApiResponse> agregarUnidad(Map<String, dynamic> data) =>
      post('${ApiConfig.conductorEndpoint}/AgregarUnidad', data);

  Future<ApiResponse> calificarPasajero(int idServicio, int idConductor, int calificacion, {String? comentarios}) =>
      post('${ApiConfig.conductorEndpoint}/CalificarPasajero', {
        'idServicio': idServicio, 'idConductor': idConductor,
        'calificacion': calificacion, 'comentarios': comentarios,
      });

  // ─── PARADAS INTERMEDIAS ─────────────────────────────────────

  Future<ApiResponse> listarParadas(int idServicio) =>
      get('/Servicio/ListarParadas?idservicio=$idServicio');

  Future<ApiResponse> completarParada(int idParada, int idConductor) =>
      post('/Servicio/CompletarParada', {'idParada': idParada, 'idConductor': idConductor});

  // ─── SOPORTE ─────────────────────────────────────────────────

  Future<ApiResponse> crearSolicitudSoporte(int idServicio, int idConductor, String asunto, String descripcion, {String prioridad = 'Normal'}) =>
      post('/Soporte/CrearSolicitud', {
        'idservicio': idServicio,
        'idconductor': idConductor,
        'tipoSolicitante': 'conductor',
        'asunto': asunto,
        'descripcion': descripcion,
        'prioridad': prioridad,
      });

  Future<ApiResponse> listarMensajesSoporte(int idSolicitud) =>
      get('/Soporte/ListarMensajes?idsolicitud=$idSolicitud');

  Future<ApiResponse> enviarMensajeSoporte(int idSolicitud, String emisor, int idEmisor, String nombreEmisor, String mensaje) =>
      post('/Soporte/EnviarMensaje', {
        'idsolicitud': idSolicitud,
        'emisor': emisor,
        'idemisor': idEmisor,
        'nombreEmisor': nombreEmisor,
        'mensaje': mensaje,
      });

  Future<ApiResponse> obtenerSolicitudSoporte(int id) =>
      get('/Soporte/ObtenerSolicitud?id=$id');
}