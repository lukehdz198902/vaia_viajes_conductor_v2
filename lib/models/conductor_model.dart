class Conductor {
  final int id;
  final int idCompania;
  final int? idZonaCobertura;
  final String nombre;
  final String appaterno;
  final String apmaterno;
  final String? sexo;
  final String correo;
  final String telefono;
  final bool? telefonoConfirmado;
  final String? fotoPerfil;
  final String account;
  final int? idConductorEstatus;
  final String? conductorEstatus;
  final bool? documentacionAprobada;
  final int? idEstatusDocumentacion;
  final String? nombreEstatusDocs;
  final bool? bloqueado;
  final String? curp;
  final String? rfc;
  final String? licenciaConducir;
  final String? fechaVencimientoLicencia;
  final bool? esLogueadoConGoogle;
  final String? googleUserId;
  final String? fotoUrlGoogle;
  final int? idiomaPreferido;
  final String? idioma;
  final double? calificacionPromedio;
  final int? totalViajes;
  final String? banco;
  final String? nombreTitular;
  final String? clabeInterbancaria;
  final String? nombreZona;
  final String? uuidsesion;

  Conductor({
    required this.id,
    required this.idCompania,
    this.idZonaCobertura,
    required this.nombre,
    required this.appaterno,
    this.apmaterno = '',
    this.sexo,
    required this.correo,
    required this.telefono,
    this.telefonoConfirmado,
    this.fotoPerfil,
    required this.account,
    this.idConductorEstatus,
    this.conductorEstatus,
    this.documentacionAprobada,
    this.idEstatusDocumentacion,
    this.nombreEstatusDocs,
    this.bloqueado,
    this.curp,
    this.rfc,
    this.licenciaConducir,
    this.fechaVencimientoLicencia,
    this.esLogueadoConGoogle,
    this.googleUserId,
    this.fotoUrlGoogle,
    this.idiomaPreferido,
    this.idioma,
    this.calificacionPromedio,
    this.totalViajes,
    this.banco,
    this.nombreTitular,
    this.clabeInterbancaria,
    this.nombreZona,
    this.uuidsesion,
  });

  String get nombreCompleto => '$nombre $appaterno $apmaterno'.trim();

  factory Conductor.fromJson(Map<String, dynamic> json) {
    return Conductor(
      id: _safeInt(json['id']) ?? 0,
      idCompania: _safeInt(json['idcompania']) ?? 0,
      idZonaCobertura: _safeInt(json['idzonacobertura']),
      nombre: json['nombre']?.toString() ?? '',
      appaterno: json['appaterno']?.toString() ?? '',
      apmaterno: json['apmaterno']?.toString() ?? '',
      sexo: json['sexo']?.toString(),
      correo: json['correo']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      telefonoConfirmado: _safeBool(json['telefonoconfirmado']),
      fotoPerfil: json['fotoperfil']?.toString(),
      account: json['account']?.toString() ?? '',
      idConductorEstatus: _safeInt(json['idconductorestatus']),
      conductorEstatus: json['conductorestatus']?.toString(),
      documentacionAprobada: _safeBool(json['documentacionaprobada']),
      idEstatusDocumentacion: _safeInt(json['idestatusdocumentacion']),
      nombreEstatusDocs: json['nombreestatusdocs']?.toString(),
      bloqueado: _safeBool(json['bloqueado']),
      curp: json['curp']?.toString(),
      rfc: json['rfc']?.toString(),
      licenciaConducir: json['licenciaconducir']?.toString(),
      fechaVencimientoLicencia: json['fechavencimientolicencia']?.toString(),
      esLogueadoConGoogle: _safeBool(json['eslogueadocongoogle']),
      googleUserId: json['googleuserid']?.toString(),
      fotoUrlGoogle: json['fotourlgoogle']?.toString(),
      idiomaPreferido: _safeInt(json['idiomapreferido']),
      idioma: json['idioma']?.toString(),
      calificacionPromedio: _safeDouble(json['calificacionpromedio']),
      totalViajes: _safeInt(json['totalviajes']),
      banco: json['banco']?.toString(),
      nombreTitular: json['nombretitular']?.toString(),
      clabeInterbancaria: json['clabeinterbancaria']?.toString(),
      nombreZona: json['nombrezona']?.toString(),
      uuidsesion: json['uuidsesion']?.toString(),
    );
  }

  static int? _safeInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static double? _safeDouble(dynamic v) => v == null ? null : double.tryParse(v.toString());
  static bool? _safeBool(dynamic v) => v == null ? null : (v is bool ? v : v.toString() == '1');
}
