class Unidad {
  final int id;
  final int? idCompania;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? color;
  final String? placas;
  final String? numeroEconomico;
  final String? numeroSerie;
  final String? nombreAseguradora;
  final String? numeroPoliza;
  final String? vigenciaPoliza;
  final String? fotoUrl;
  final bool? enUso;
  final bool? aprobada;
  final int? documentos;
  final String? nombre;

  Unidad({
    required this.id,
    this.idCompania,
    this.marca,
    this.modelo,
    this.anio,
    this.color,
    this.placas,
    this.numeroEconomico,
    this.numeroSerie,
    this.nombreAseguradora,
    this.numeroPoliza,
    this.vigenciaPoliza,
    this.fotoUrl,
    this.enUso,
    this.aprobada,
    this.documentos,
    this.nombre,
  });

  factory Unidad.fromJson(Map<String, dynamic> json) {
    return Unidad(
      id: _safeInt(json['idunidad']) ?? _safeInt(json['id']) ?? 0,
      idCompania: _safeInt(json['idcompania']),
      marca: json['marca']?.toString(),
      modelo: json['modelo']?.toString(),
      anio: _safeInt(json['anio']),
      color: json['color']?.toString(),
      placas: json['placas']?.toString(),
      numeroEconomico: json['numeroeconomico']?.toString(),
      numeroSerie: json['numeroserie']?.toString(),
      nombreAseguradora: json['nombreaseguradora']?.toString(),
      numeroPoliza: json['numeropoliza']?.toString(),
      vigenciaPoliza: json['vigenciapoliza']?.toString(),
      fotoUrl: json['fotourl']?.toString(),
      enUso: _safeBool(json['enuso']),
      aprobada: _safeBool(json['aprobada']),
      documentos: _safeInt(json['documentos']),
      nombre: json['nombre']?.toString(),
    );
  }

  String get displayName => nombre ?? '$marca $modelo ($placas)';

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static bool? _safeBool(dynamic v) => v == null ? null : (v is bool ? v : v.toString() == '1');
}
