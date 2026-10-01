import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Iconos de mapa de Vaia: unidad (auto), origen y destino.
///
/// Se cargan una sola vez y se cachean como [BitmapDescriptor] para usarlos en
/// cualquier marcador de Google Maps.
class MarkerIcons {
  static BitmapDescriptor? _car;
  static BitmapDescriptor? _origin;
  static BitmapDescriptor? _destination;
  static bool _cargado = false;

  static BitmapDescriptor? get car => _car;
  static BitmapDescriptor? get origin => _origin;
  static BitmapDescriptor? get destination => _destination;

  /// Carga los tres iconos (idempotente). Llamar al abrir una pantalla con mapa.
  static Future<void> cargar() async {
    if (_cargado) return;
    try { _car = await _png('assets/images/carro32_lado.png'); } catch (_) {}
    try { _origin = await _svg('assets/images/ic_marker_origin.svg', 40); } catch (_) {}
    try { _destination = await _svg('assets/images/ic_marker_destination.svg', 40); } catch (_) {}
    _cargado = true;
  }

  static Future<BitmapDescriptor> _png(String path) async {
    final data = await rootBundle.load(path);
    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _svg(String path, int px) async {
    final info = await vg.loadPicture(SvgAssetLoader(path), null);
    final image = await info.picture.toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    info.picture.dispose();
    image.dispose();
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}

/// Icono vectorial de origen/destino para acompaÃ±ar el texto de direcciones.
class MarkerIcon extends StatelessWidget {
  final bool origin;
  final double size;
  const MarkerIcon({super.key, required this.origin, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      origin ? 'assets/images/ic_marker_origin.svg' : 'assets/images/ic_marker_destination.svg',
      width: size,
      height: size,
    );
  }
}
