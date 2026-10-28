import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Recorrido real registrado por el GPS del conductor durante el servicio.
class RecorridoModel {
  final bool disponible;
  final String? mensaje;
  final List<LatLng> puntos;

  const RecorridoModel({
    required this.disponible,
    required this.puntos,
    this.mensaje,
  });

  bool get tieneRuta => puntos.length >= 2;

  factory RecorridoModel.fromRows(List<dynamic>? rows) {
    final list = rows ?? const [];
    if (list.isEmpty) {
      return const RecorridoModel(
        disponible: false,
        mensaje: 'No se pudo consultar el recorrido del servicio.',
        puntos: [],
      );
    }

    final first = Map<String, dynamic>.from(list.first as Map);
    final disponible = _toBool(first['disponible']);
    final mensaje = first['motivo']?.toString();
    final puntos = <LatLng>[];

    for (final item in list) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final lat = double.tryParse(row['lat']?.toString() ?? '');
      final lng = double.tryParse(row['lng']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      final punto = LatLng(lat, lng);
      if (puntos.isNotEmpty &&
          puntos.last.latitude == punto.latitude &&
          puntos.last.longitude == punto.longitude) {
        continue;
      }
      puntos.add(punto);
    }

    return RecorridoModel(
      disponible: disponible,
      mensaje: mensaje,
      puntos: puntos,
    );
  }

  static bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;
    final text = value?.toString().toLowerCase();
    return text == '1' || text == 'true';
  }
}
