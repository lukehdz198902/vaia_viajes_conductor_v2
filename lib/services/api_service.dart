import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiResponse {
  final bool ok;
  final Map<String, dynamic>? data;
  final List<dynamic>? list;
  final String? error;

  ApiResponse({required this.ok, this.data, this.list, this.error});

  int get id => data?['id'] ?? 0;
  String get mensaje => data?['mensaje']?.toString() ?? '';
  int get resultado => data?['resultado'] ?? 0;
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String base = ApiConfig.baseUrl;

  Future<ApiResponse> _processResponse(http.Response resp, {bool isList = false}) async {
    try {
      final body = utf8.decode(resp.bodyBytes);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = json.decode(body);
        if (isList) {
          final list = decoded is List ? decoded : (decoded is Map ? (decoded['data'] ?? []) : []);
          return ApiResponse(ok: true, list: List<Map<String, dynamic>>.from(list));
        }
        final map = decoded is Map<String, dynamic> ? decoded : (decoded is List && decoded.isNotEmpty ? decoded[0] : {});
        final ok = map['resultado'] != -1 && map['id'] != -1;
        return ApiResponse(ok: ok, data: map);
      }
      return ApiResponse(ok: false, error: 'Error ${resp.statusCode}');
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
      return _processResponse(resp);
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
      return _processResponse(resp, isList: true);
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
      return _processResponse(resp);
    } catch (e) {
      return ApiResponse(ok: false, error: e.toString());
    }
  }

  Future<ApiResponse> registrarConductor(Map<String, dynamic> data) =>
      post('${ApiConfig.conductorEndpoint}/Registrar', data);

  Future<ApiResponse> iniciarSesion(String account, String pass, {String? googleKey, String? dispositivoInfo}) =>
      post('${ApiConfig.conductorEndpoint}/IniciarSesion', {
        'account': account, 'pass': pass,
        'googlekey': googleKey ?? '', 'dispositivoinfo': dispositivoInfo ?? '',
      });

  Future<ApiResponse> cerrarSesion(int idConductor, String uuidsesion) =>
      post('${ApiConfig.conductorEndpoint}/CerrarSesion', {
        'idConductor': idConductor, 'uuidsesion': uuidsesion,
      });

  Future<ApiResponse> obtenerPerfil(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerPerfil?idConductor=$idConductor');

  Future<ApiResponse> actualizarPerfil(Map<String, dynamic> data) =>
      postForm('${ApiConfig.conductorEndpoint}/ActualizarPerfil', {
        for (var e in data.entries) e.key: e.value?.toString() ?? '',
      });

  Future<ApiResponse> cambiarPassword(int idConductor, String passActual, String passNueva) =>
      post('${ApiConfig.conductorEndpoint}/CambiarPassword', {
        'idConductor': idConductor, 'passActual': passActual, 'passNueva': passNueva,
      });

  Future<ApiResponse> actualizarUbicacion(int idConductor, String lat, String lng) =>
      post('${ApiConfig.conductorEndpoint}/ActualizarUbicacion', {
        'idConductor': idConductor, 'lat': lat, 'lng': lng,
      });

  Future<ApiResponse> cambiarEstatus(int idConductor, String estatus) =>
      post('${ApiConfig.conductorEndpoint}/CambiarEstatus', {
        'idConductor': idConductor, 'estatus': estatus,
      });

  Future<ApiResponse> obtenerServicioActivo(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerServicioActivo?idConductor=$idConductor');

  Future<ApiResponse> aceptarServicio(int idServicio, int idConductor) =>
      post('${ApiConfig.conductorEndpoint}/AceptarServicio', {
        'idServicio': idServicio, 'idConductor': idConductor,
      });

  Future<ApiResponse> iniciarViaje(int idServicio, int idConductor) =>
      post('${ApiConfig.conductorEndpoint}/IniciarViaje', {
        'idServicio': idServicio, 'idConductor': idConductor,
      });

  Future<ApiResponse> finalizarViaje(int idServicio, int idConductor, {double? costoFinal}) =>
      post('${ApiConfig.conductorEndpoint}/FinalizarViaje', {
        'idServicio': idServicio, 'idConductor': idConductor,
        if (costoFinal != null) 'costoFinal': costoFinal.toString(),
      });

  Future<ApiResponse> listarUnidades(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ListarUnidades?idConductor=$idConductor');

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

  Future<ApiResponse> transferirSemanaCorte(int idConductor, int idCorte) =>
      post('${ApiConfig.conductorEndpoint}/TransferirSemanaCorte', {
        'idConductor': idConductor, 'idCorte': idCorte,
      });

  Future<ApiResponse> enviarMensaje(int idServicio, int idConductor, String mensaje) =>
      post('${ApiConfig.conductorEndpoint}/EnviarMensajeChat', {
        'idServicio': idServicio, 'idConductor': idConductor, 'mensaje': mensaje,
      });

  Future<ApiResponse> obtenerMensajes(int idServicio, int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerMensajesChat?idServicio=$idServicio&idConductor=$idConductor');

  Future<ApiResponse> activarAlarmaSOS(int idConductor, double lat, double lng) =>
      post('${ApiConfig.conductorEndpoint}/ActivarAlarmaSOS', {
        'idConductor': idConductor, 'lat': lat.toString(), 'lng': lng.toString(),
      });

  Future<ApiResponse> reportarIncidente(Map<String, dynamic> data) =>
      postForm('${ApiConfig.conductorEndpoint}/ReportarIncidente', {
        for (var e in data.entries) e.key: e.value?.toString() ?? '',
      });

  Future<ApiResponse> obtenerNotificaciones(int idConductor) =>
      get('${ApiConfig.conductorEndpoint}/ObtenerNotificaciones?idConductor=$idConductor');

  Future<ApiResponse> obtenerAvisos() =>
      get('${ApiConfig.conductorEndpoint}/ObtenerAvisos');
}
