class Servicio {
  final int id;
  final int? idPasajero;
  final String? pasajeroNombre;
  final String? pasajeroFoto;
  final String? pasajeroTelefono;
  final int? idConductor;
  final int? idUnidad;
  final int? idServicioEstatus;
  final String? servicioEstatus;
  final String? direccionOrigen;
  final String? latOrigen;
  final String? lngOrigen;
  final String? direccionDestino;
  final String? latDestino;
  final String? lngDestino;
  final double? distanciaMetros;
  final double? costoEstimado;
  final double? costoFinal;
  final String? tipoViaje;
  final String? fechaCreacion;
  final int? calificacion;
  final String? comentarios;
  final int? idCompania;
  final int? segundosParaTomar;

  Servicio({
    required this.id,
    this.idPasajero,
    this.pasajeroNombre,
    this.pasajeroFoto,
    this.pasajeroTelefono,
    this.idConductor,
    this.idUnidad,
    this.idServicioEstatus,
    this.servicioEstatus,
    this.direccionOrigen,
    this.latOrigen,
    this.lngOrigen,
    this.direccionDestino,
    this.latDestino,
    this.lngDestino,
    this.distanciaMetros,
    this.costoEstimado,
    this.costoFinal,
    this.tipoViaje,
    this.fechaCreacion,
    this.calificacion,
    this.comentarios,
    this.idCompania,
    this.segundosParaTomar,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idpasajero': idPasajero,
      'pas_nombre': pasajeroNombre,
      'pas_foto': pasajeroFoto,
      'pas_tel': pasajeroTelefono,
      'idconductor': idConductor,
      'idunidad': idUnidad,
      'idservicioestatus': idServicioEstatus,
      'servicioEstatus': servicioEstatus,
      'direccionorigen': direccionOrigen,
      'latorigen': latOrigen,
      'lngorigen': lngOrigen,
      'direcciondestination': direccionDestino,
      'latdestination': latDestino,
      'lngdestination': lngDestino,
      'distanciametros': distanciaMetros,
      'costoestimado': costoEstimado,
      'costofinal': costoFinal,
      'tipoviaje': tipoViaje,
      'fechacreacion': fechaCreacion,
      'calificacion': calificacion,
      'comentarios': comentarios,
      'idcompania': idCompania,
      'segundosparatomar': segundosParaTomar,
    };
  }

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: _safeInt(json['id']) ?? 0,
      idPasajero: _safeInt(json['idpasajero']),
      pasajeroNombre: json['pas_nombre']?.toString() ?? json['pasajeroNombre']?.toString(),
      pasajeroFoto: json['pas_foto']?.toString() ?? json['pasajeroFoto']?.toString(),
      pasajeroTelefono: json['pas_tel']?.toString() ?? json['pasajeroTelefono']?.toString(),
      idConductor: _safeInt(json['idconductor']),
      idUnidad: _safeInt(json['idunidad']),
      idServicioEstatus: _safeInt(json['idservicioestatus']),
      servicioEstatus: json['servicioEstatus']?.toString(),
      direccionOrigen: json['direccionorigen']?.toString(),
      latOrigen: json['latorigen']?.toString(),
      lngOrigen: json['lngorigen']?.toString(),
      direccionDestino: json['direcciondestination']?.toString(),
      latDestino: json['latdestination']?.toString(),
      lngDestino: json['lngdestination']?.toString(),
      distanciaMetros: _safeDouble(json['distanciametros']),
      costoEstimado: _safeDouble(json['costoestimado']),
      costoFinal: _safeDouble(json['costofinal']),
      tipoViaje: json['tipoviaje']?.toString(),
      fechaCreacion: json['fechacreacion']?.toString() ?? json['fechaCreacion']?.toString(),
      calificacion: _safeInt(json['calificacion']),
      comentarios: json['comentarios']?.toString(),
      idCompania: _safeInt(json['idcompania']),
      segundosParaTomar: _safeInt(json['segundosparatomar']) ?? _safeInt(json['segundosParaTomar']),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static double? _safeDouble(dynamic v) => v == null ? null : double.tryParse(v.toString());
}
