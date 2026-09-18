import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Documentos del vehiculo (tarjeta de circulacion, poliza, seguro, etc.).
class VehicleDocumentsScreen extends StatefulWidget {
  final int idUnidad;
  const VehicleDocumentsScreen({super.key, required this.idUnidad});
  @override
  State<VehicleDocumentsScreen> createState() => _VehicleDocumentsScreenState();
}

class _VehicleDocumentsScreenState extends State<VehicleDocumentsScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  List<dynamic> _tipos = [];
  Map<int, Map<String, dynamic>> _docs = {};
  bool _cargando = true;
  int? _subiendo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    try {
      final rTipos = await _api.listarTiposDocumento(para: 'unidad');
      final rDocs = await _api.listarDocumentosUnidad(auth.userId, widget.idUnidad);
      final docs = <int, Map<String, dynamic>>{};
      for (final d in (rDocs.list ?? [])) {
        final m = Map<String, dynamic>.from(d as Map);
        final id = int.tryParse(m['idtipoarchivounidad']?.toString() ?? '') ?? 0;
        docs[id] = m;
      }
      if (!mounted) return;
      setState(() { _tipos = rTipos.list ?? []; _docs = docs; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _subir(int idTipo, String nombreTipo) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de galeria'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (origen == null) return;

    final XFile? foto = await _picker.pickImage(source: origen, imageQuality: 60, maxWidth: 1400);
    if (foto == null) return;

    setState(() => _subiendo = idTipo);
    try {
      final b64 = base64Encode(await foto.readAsBytes());
      final auth = context.read<AuthProvider>();
      final r = await _api.agregarDocumentoUnidad(auth.userId, widget.idUnidad, idTipo, nombreTipo, b64);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.ok ? 'Documento cargado' : (r.mensaje.isNotEmpty ? r.mensaje : 'No se pudo cargar')),
        backgroundColor: r.ok ? VaiaColors.success : VaiaColors.danger,
      ));
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: VaiaColors.danger));
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos de la unidad')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _tipos.map((t) {
                  final id = int.tryParse(t['id']?.toString() ?? '') ?? 0;
                  final nombre = t['tipoarchivo']?.toString() ?? '';
                  return _tile(id, nombre, _docs[id]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _tile(int id, String nombre, Map<String, dynamic>? doc) {
    final validado = doc?['validado'] == true || doc?['validado'] == 1;
    final correccion = doc?['encorreccion'] == true || doc?['encorreccion'] == 1;
    final tieneArchivo = doc?['tienearchivo'] == true || doc?['tienearchivo'] == 1;

    Color color = VaiaColors.textSecondary;
    IconData icono = Icons.upload_file_outlined;
    String estado = 'Pendiente de subir';
    if (validado) { color = VaiaColors.success; icono = Icons.verified_outlined; estado = 'Aprobado'; }
    else if (correccion) { color = VaiaColors.danger; icono = Icons.error_outline_rounded; estado = 'Requiere correccion'; }
    else if (tieneArchivo) { color = VaiaColors.warning; icono = Icons.hourglass_top_rounded; estado = 'En revision'; }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(estado, style: TextStyle(fontSize: 12, color: color)),
        trailing: _subiendo == id
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: Icon(tieneArchivo ? Icons.refresh_rounded : Icons.add_a_photo_outlined),
                onPressed: () => _subir(id, nombre),
              ),
      ),
    );
  }
}
