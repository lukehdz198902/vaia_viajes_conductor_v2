class ParadaModel {
  final int id;
  final int idServicio;
  final int orden;
  final String direccion;
  final String lat;
  final String lng;
  final String? referencia;
  final String? notas;
  final bool completada;
  final String? fechaCompletada;

  ParadaModel({
    required this.id,
    required this.idServicio,
    required this.orden,
    required this.direccion,
    required this.lat,
    required this.lng,
    this.referencia,
    this.notas,
    this.completada = false,
    this.fechaCompletada,
  });

  factory ParadaModel.fromJson(Map<String, dynamic> json) {
    return ParadaModel(
      id: _toInt(json['id']),
      idServicio: _toInt(json['idservicio']),
      orden: _toInt(json['orden']),
      direccion: json['direccion']?.toString() ?? '',
      lat: json['lat']?.toString() ?? '',
      lng: json['lng']?.toString() ?? '',
      referencia: json['referencia']?.toString(),
      notas: json['notas']?.toString(),
      completada: json['completada'] == true || json['completada'] == 1,
      fechaCompletada: json['fecha_completada']?.toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}