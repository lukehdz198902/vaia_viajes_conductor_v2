class MensajeChat {
  final int id;
  final int? idServicio;
  final String? emisor;
  final String? mensaje;
  final String? fechaEnvio;
  final bool? leido;

  MensajeChat({
    required this.id,
    this.idServicio,
    this.emisor,
    this.mensaje,
    this.fechaEnvio,
    this.leido,
  });

  factory MensajeChat.fromJson(Map<String, dynamic> json) {
    return MensajeChat(
      id: _safeInt(json['id']) ?? 0,
      idServicio: _safeInt(json['idservicio']),
      emisor: json['emisor']?.toString(),
      mensaje: json['mensaje']?.toString(),
      fechaEnvio: json['fechaenvio']?.toString(),
      leido: _safeBool(json['leido']),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static bool? _safeBool(dynamic v) => v == null ? null : (v is bool ? v : v.toString() == '1');
}
