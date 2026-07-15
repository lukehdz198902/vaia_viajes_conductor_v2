class Notificacion {
  final int id;
  final String? titulo;
  final String? mensaje;
  final String? fecha;
  final bool? leido;
  final String? tipo;

  Notificacion({
    required this.id,
    this.titulo,
    this.mensaje,
    this.fecha,
    this.leido,
    this.tipo,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: _safeInt(json['id']) ?? 0,
      titulo: json['titulo']?.toString(),
      mensaje: json['mensaje']?.toString(),
      fecha: json['fecha']?.toString(),
      leido: _safeBool(json['leido']),
      tipo: json['tipo']?.toString(),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static bool? _safeBool(dynamic v) => v == null ? null : (v is bool ? v : v.toString() == '1');
}

class Aviso {
  final int id;
  final String? titulo;
  final String? contenido;
  final String? fechaPublicacion;
  final bool? activo;

  Aviso({
    required this.id,
    this.titulo,
    this.contenido,
    this.fechaPublicacion,
    this.activo,
  });

  factory Aviso.fromJson(Map<String, dynamic> json) {
    return Aviso(
      id: _safeInt(json['id']) ?? 0,
      titulo: json['titulo']?.toString(),
      contenido: json['contenido']?.toString(),
      fechaPublicacion: json['fechapublicacion']?.toString(),
      activo: _safeBool(json['activo']),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static bool? _safeBool(dynamic v) => v == null ? null : (v is bool ? v : v.toString() == '1');
}
