class Servicio {
  final int id;
  final int? idPasajero;
  final String? pasajeroNombre;
  final String? pasajeroApaterno;
  final String? pasajeroFoto;
  final String? pasajeroTelefono;
  final double? pasajeroCalificacion;
  final int? pasajeroTotalViajes;

  final int? idConductor;
  final int? idUnidad;
  final int? idServicioEstatus;
  final String? servicioEstatus;
  final String? servicioEstatusDescripcion;

  final String? direccionOrigen;
  final String? latOrigen;
  final String? lngOrigen;
  final String? direccionDestino;
  final String? latDestino;
  final String? lngDestino;

  final double? distanciaMetros;
  final double? rdM;
  final double? rdS;
  final int? duracionSegundos;

  final double? costoEstimado;
  final double? costoEnCurso;
  final double? costoFinal;

  final String? tipoViaje;
  final String? tipoPago;
  final String? codigoInicio;

  final String? fechaCreacion;
  final String? fechaServicioIniciado;
  final String? fechaLlegoOrigen;
  final String? fechaLlegoDestino;

  final int? calificacion;
  final int? calificacionPasajero;
  final String? comentarios;
  final int? idCompania;
  final int? segundosParaTomar;

  // Unidad
  final String? unidad;
  final String? placas;
  final String? modelo;
  final String? colorNombre;
  final String? colorHex;
  final int? numeroAsientos;
  final String? marca;
  final String? submarca;

  // Banderas
  final bool servicioIniciado;
  final bool llegoOrigen;
  final bool llegoDestino;

  final Map<String, dynamic> raw;

  Servicio({
    required this.id,
    this.idPasajero,
    this.pasajeroNombre,
    this.pasajeroApaterno,
    this.pasajeroFoto,
    this.pasajeroTelefono,
    this.pasajeroCalificacion,
    this.pasajeroTotalViajes,
    this.idConductor,
    this.idUnidad,
    this.idServicioEstatus,
    this.servicioEstatus,
    this.servicioEstatusDescripcion,
    this.direccionOrigen,
    this.latOrigen,
    this.lngOrigen,
    this.direccionDestino,
    this.latDestino,
    this.lngDestino,
    this.distanciaMetros,
    this.rdM,
    this.rdS,
    this.duracionSegundos,
    this.costoEstimado,
    this.costoEnCurso,
    this.costoFinal,
    this.tipoViaje,
    this.tipoPago,
    this.codigoInicio,
    this.fechaCreacion,
    this.fechaServicioIniciado,
    this.fechaLlegoOrigen,
    this.fechaLlegoDestino,
    this.calificacion,
    this.calificacionPasajero,
    this.comentarios,
    this.idCompania,
    this.segundosParaTomar,
    this.unidad,
    this.placas,
    this.modelo,
    this.colorNombre,
    this.colorHex,
    this.numeroAsientos,
    this.marca,
    this.submarca,
    this.servicioIniciado = false,
    this.llegoOrigen = false,
    this.llegoDestino = false,
    this.raw = const {},
  });

  String get pasajeroNombreCompleto {
    final n = [pasajeroNombre, pasajeroApaterno].where((e) => e != null && e.trim().isNotEmpty).join(' ').trim();
    return n.isEmpty ? 'Pasajero' : n;
  }

  String get vehiculoDescripcion =>
      [marca, submarca, modelo].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ').trim();

  String get estatusNorm => (servicioEstatus ?? '').trim().toLowerCase();

  bool get cancelado => estatusNorm.contains('cancel') || estatusNorm == 'no pagado';
  bool get esSolicitado => estatusNorm == 'solicitado';
  bool get esEnCamino => estatusNorm == 'en camino';
  bool get esLlegoOrigen => estatusNorm == 'llego al origen';
  bool get esEnViaje => estatusNorm == 'en viaje' || estatusNorm == 'casi llegando' || estatusNorm == 'llego al destino';
  bool get esFinalizado => estatusNorm == 'finalizado' || estatusNorm == 'pagado';
  bool get esActivo => !cancelado && !esFinalizado;

  /// Paso del proceso (0..4) para la linea de tiempo animada.
  int get pasoActual {
    if (cancelado) return -1;
    if (esSolicitado) return 0;
    if (esEnCamino) return 1;
    if (esLlegoOrigen) return 2;
    if (esEnViaje) return 3;
    if (esFinalizado) return 4;
    return 0;
  }

  double get montoActual => (costoFinal ?? 0) > 0
      ? costoFinal!
      : (costoEnCurso ?? 0) > 0
          ? costoEnCurso!
          : (costoEstimado ?? 0);

  Servicio copyWith(Map<String, dynamic> cambios) => Servicio.fromJson({...raw, ...cambios});

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(raw);

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: _safeInt(json['id']) ?? 0,
      idPasajero: _safeInt(json['idpasajero']),
      pasajeroNombre: (json['pasajero_nombre'] ?? json['pas_nombre'] ?? json['p_nombre'] ?? json['pasajeroNombre'])?.toString(),
      pasajeroApaterno: (json['pasajero_appaterno'] ?? json['pas_appaterno'] ?? json['p_appaterno'])?.toString(),
      pasajeroFoto: (json['pasajero_foto'] ?? json['pas_foto'] ?? json['p_foto'] ?? json['pasajeroFoto'])?.toString(),
      pasajeroTelefono: (json['pasajero_telefono'] ?? json['pas_tel'] ?? json['p_tel'] ?? json['pasajeroTelefono'])?.toString(),
      pasajeroCalificacion: _safeDouble(json['pasajero_calificacion'] ?? json['pasajerocalificacion'] ?? json['pasajeroCalificacion']),
      pasajeroTotalViajes: _safeInt(json['pasajero_totalviajes'] ?? json['pasajerototalviajes'] ?? json['pasajeroTotalViajes']),
      idConductor: _safeInt(json['idconductor']),
      idUnidad: _safeInt(json['idunidad']),
      idServicioEstatus: _safeInt(json['idservicioestatus']),
      servicioEstatus: (json['estatus'] ?? json['servicioEstatus'])?.toString(),
      servicioEstatusDescripcion: (json['estatusdescription'] ?? json['servicioEstatusDescripcion'])?.toString(),
      direccionOrigen: json['direccionorigen']?.toString(),
      latOrigen: json['latorigen']?.toString(),
      lngOrigen: json['lngorigen']?.toString(),
      direccionDestino: json['direcciondestination']?.toString(),
      latDestino: json['latdestination']?.toString(),
      lngDestino: json['lngdestination']?.toString(),
      distanciaMetros: _safeDouble(json['distanciametros']),
      rdM: _safeDouble(json['rd_m']),
      rdS: _safeDouble(json['rd_s']),
      duracionSegundos: _safeInt(json['durationsegundos'] ?? json['duracionsegundos']),
      costoEstimado: _safeDouble(json['costoestimado']),
      costoEnCurso: _safeDouble(json['costoencurso']),
      costoFinal: _safeDouble(json['costofinal']),
      tipoViaje: json['tipoviaje']?.toString(),
      tipoPago: json['tipopago']?.toString(),
      codigoInicio: json['codigoinicio']?.toString(),
      fechaCreacion: json['fechacreacion']?.toString() ?? json['fechaCreacion']?.toString(),
      fechaServicioIniciado: json['fechaservicioiniciado']?.toString(),
      fechaLlegoOrigen: json['fechallegoalorigen']?.toString(),
      fechaLlegoDestino: json['fechallegoasudestino']?.toString(),
      calificacion: _safeInt(json['calificacion']),
      calificacionPasajero: _safeInt(json['calificacionpasajero']),
      comentarios: json['comentarios']?.toString(),
      idCompania: _safeInt(json['idcompania']),
      segundosParaTomar: _safeInt(json['segundosparatomar']) ?? _safeInt(json['segundosParaTomar']),
      unidad: json['unidad']?.toString(),
      placas: json['placas']?.toString(),
      modelo: json['modelo']?.toString(),
      colorNombre: json['colornombre']?.toString(),
      colorHex: json['colorhex']?.toString(),
      numeroAsientos: _safeInt(json['numeroasientos']),
      marca: json['nombremarca']?.toString(),
      submarca: json['nombresubmarca']?.toString(),
      servicioIniciado: json['servicioiniciado'] == true || json['servicioiniciado']?.toString() == 'true',
      llegoOrigen: json['llegoalorigen'] == true || json['llegoalorigen']?.toString() == 'true',
      llegoDestino: json['llegoasudestino'] == true || json['llegoasudestino']?.toString() == 'true',
      raw: Map<String, dynamic>.from(json),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static double? _safeDouble(dynamic v) => v == null ? null : double.tryParse(v.toString());
}
