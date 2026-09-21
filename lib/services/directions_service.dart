import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RutaInfo {
  final List<LatLng> puntos;
  final int distanciaMetros;
  final int duracionSegundos;
  RutaInfo({required this.puntos, required this.distanciaMetros, required this.duracionSegundos});
}

/// Calcula la ruta estimada (polilinea, distancia y tiempo) con Google
/// Directions usando la llave movil del conductor.
class DirectionsService {
  static const String _apiKey = String.fromEnvironment(
    'PLACES_API_KEY',
    defaultValue: 'AIzaSyDp3aNnB9h8il09NbNbr2oigiHZEVTWBvQ',
  );

  static const String paqueteAndroid = 'prozoft.com.vaiaconductor';
  static const String sha1Android = '8D4BB32F55BD8255FD5436D335D636F8A1F0F742';

  static String ultimoError = '';

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        'X-Android-Package': paqueteAndroid,
        'X-Android-Cert': sha1Android,
      };

  static Future<RutaInfo?> ruta({
    required LatLng origen,
    required LatLng destino,
    List<LatLng> paradas = const [],
  }) async {
    ultimoError = '';
    try {
      final params = <String, String>{
        'origin': '${origen.latitude},${origen.longitude}',
        'destination': '${destino.latitude},${destino.longitude}',
        'key': _apiKey,
        'language': 'es',
        'mode': 'driving',
      };
      if (paradas.isNotEmpty) {
        params['waypoints'] = paradas.map((p) => '${p.latitude},${p.longitude}').join('|');
      }
      final url = Uri.parse('https://maps.googleapis.com/maps/api/directions/json')
          .replace(queryParameters: params);
      final res = await http.get(url, headers: _headers);
      if (res.statusCode != 200) {
        ultimoError = 'HTTP ${res.statusCode}';
        return null;
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['status']?.toString() != 'OK') {
        final msg = data['error_message']?.toString() ?? '';
        ultimoError = msg.isNotEmpty ? msg : (data['status']?.toString() ?? 'Error');
        return null;
      }
      final rutas = data['routes'] as List? ?? [];
      if (rutas.isEmpty) {
        ultimoError = 'Sin ruta';
        return null;
      }
      final ruta = rutas.first;
      final puntos = _decodificar(ruta['overview_polyline']?['points']?.toString() ?? '');
      if (puntos.isEmpty) {
        ultimoError = 'Sin polilinea';
        return null;
      }
      int dist = 0, dur = 0;
      for (final leg in (ruta['legs'] as List? ?? [])) {
        dist += ((leg['distance']?['value']) as num?)?.toInt() ?? 0;
        dur += ((leg['duration']?['value']) as num?)?.toInt() ?? 0;
      }
      return RutaInfo(puntos: puntos, distanciaMetros: dist, duracionSegundos: dur);
    } catch (e) {
      ultimoError = e.toString();
      return null;
    }
  }

  static List<LatLng> _decodificar(String encoded) {
    final puntos = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      puntos.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return puntos;
  }
}
