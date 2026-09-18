import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Documentos del conductor (INE, licencia, CURP, RFC, etc.).
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
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
      final rTipos = await _api.listarTiposDocumento(para: 'conductor');
      final rDocs = await _api.listarDocumentos(auth.userId);
      final tipos = rTipos.list ?? [];
      final docs = <int, Map<String, dynamic>>{};
      for (final d in (rDocs.list ?? [])) {
        final m = Map<String, dynamic>.from(d as Map);
        final id = int.tryParse(m['idtipoarchivo']?.toString() ?? '') ?? 0;
        docs[id] = m;
      }
      if (!mounted) return;
      setState(() { _tipos = tipos; _docs = docs; _cargando = false; });
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
      final bytes = await foto.readAsBytes();
      final b64 = base64Encode(bytes);
      final auth = context.read<AuthProvider>();
      final r = await _api.agregarDocumento(auth.userId, idTipo, nombreTipo, b64);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.ok ? 'Documento cargado, pendiente de revision' : (r.mensaje.isNotEmpty ? r.mensaje : 'No se pudo cargar')),
        backgroundColor: r.ok ? VaiaColors.success : VaiaColors.danger,
      ));
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: VaiaColors.danger));
      }
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi documentacion')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(12)),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, color: VaiaColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('Sube documentos claros y vigentes. Seran revisados por un administrador.',
                          style: TextStyle(fontSize: 13, color: VaiaColors.textSecondary))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  ..._tipos.map((t) {
                    final id = int.tryParse(t['id']?.toString() ?? '') ?? 0;
                    final nombre = t['tipoarchivo']?.toString() ?? '';
                    final doc = _docs[id];
                    return _documentoTile(id, nombre, doc);
                  }),
                ],
              ),
            ),
    );
  }

  Widget _documentoTile(int id, String nombre, Map<String, dynamic>? doc) {
    final validado = doc?['validado'] == true || doc?['validado'] == 1;
    final correccion = doc?['encorreccion'] == true || doc?['encorreccion'] == 1;
    final enRevision = doc?['enrevision'] == true || doc?['enrevision'] == 1;
    final tieneArchivo = doc?['tienearchivo'] == true || doc?['tienearchivo'] == 1;

    Color color = VaiaColors.textSecondary;
    IconData icono = Icons.upload_file_outlined;
    String estado = 'Pendiente de subir';
    if (validado) { color = VaiaColors.success; icono = Icons.verified_outlined; estado = 'Aprobado'; }
    else if (correccion) { color = VaiaColors.danger; icono = Icons.error_outline_rounded; estado = 'Requiere correccion'; }
    else if (enRevision && tieneArchivo) { color = VaiaColors.warning; icono = Icons.hourglass_top_rounded; estado = 'En revision'; }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(estado, style: TextStyle(fontSize: 12, color: color)),
              ])),
              if (_subiendo == id)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton.icon(
                  onPressed: () => _subir(id, nombre),
                  icon: Icon(tieneArchivo ? Icons.refresh_rounded : Icons.add_a_photo_outlined, size: 18),
                  label: Text(tieneArchivo ? 'Reemplazar' : 'Subir'),
                ),
            ]),
            if (correccion && (doc?['comentariocorreccion']?.toString().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text('Correccion: ${doc!['comentariocorreccion']}', style: const TextStyle(fontSize: 12, color: VaiaColors.danger)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
