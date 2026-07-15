class CorteSemanal {
  final int id;
  final String? semana;
  final String? fechaInicio;
  final String? fechaFin;
  final int? totalViajes;
  final double? totalGanancia;
  final double? comision;
  final double? propinas;
  final double? montoTransferir;
  final bool? transferido;
  final String? fechaTransferencia;

  CorteSemanal({
    required this.id,
    this.semana,
    this.fechaInicio,
    this.fechaFin,
    this.totalViajes,
    this.totalGanancia,
    this.comision,
    this.propinas,
    this.montoTransferir,
    this.transferido,
    this.fechaTransferencia,
  });

  factory CorteSemanal.fromJson(Map<String, dynamic> json) {
    return CorteSemanal(
      id: _safeInt(json['id']) ?? 0,
      semana: json['semana']?.toString(),
      fechaInicio: json['fechainicio']?.toString(),
      fechaFin: json['fechafin']?.toString(),
      totalViajes: _safeInt(json['totalviajes']),
      totalGanancia: _safeDouble(json['totalganancia']),
      comision: _safeDouble(json['comision']),
      propinas: _safeDouble(json['propinas']),
      montoTransferir: _safeDouble(json['montotransferir']),
      transferido: _safeBool(json['transferido']),
      fechaTransferencia: json['fechatransferencia']?.toString(),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static double? _safeDouble(dynamic v) => v == null ? null : double.tryParse(v.toString());
  static bool? _safeBool(dynamic v) => v == null ? null : (v is bool ? v : v.toString() == '1');
}

class HistorialViaje {
  final int id;
  final String? fecha;
  final String? pasajero;
  final String? origen;
  final String? destino;
  final double? costo;
  final String? estatus;

  HistorialViaje({
    required this.id,
    this.fecha,
    this.pasajero,
    this.origen,
    this.destino,
    this.costo,
    this.estatus,
  });

  factory HistorialViaje.fromJson(Map<String, dynamic> json) {
    return HistorialViaje(
      id: _safeInt(json['id']) ?? 0,
      fecha: json['fechacreacion']?.toString(),
      pasajero: json['pasajero']?.toString(),
      origen: json['direccionorigen']?.toString(),
      destino: json['direcciondestination']?.toString(),
      costo: _safeDouble(json['costoestimado']),
      estatus: json['estatus']?.toString(),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static double? _safeDouble(dynamic v) => v == null ? null : double.tryParse(v.toString());
}
