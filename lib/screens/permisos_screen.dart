import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/policies.dart';
import '../config/theme.dart';
import '../services/permission_service.dart';
import 'webview_screen.dart';

/// Muestra el estado de cada permiso, permite solicitarlos de nuevo y abre
/// las politicas/terminos dentro de la app.
class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});
  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> {
  final List<PermisoDef> _permisos = PermissionService.conductor();
  final Map<String, bool> _estados = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    for (final p in _permisos) {
      final st = await PermissionService.estado(p);
      _estados[p.id] = p.soloAviso || st.isGranted;
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _solicitar(PermisoDef def) async {
    final ok = await PermissionService.solicitar(def);
    if (!ok) await PermissionService.abrirAjustes();
    await _cargar();
  }

  void _abrir(String titulo, String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewScreen(titulo: titulo, url: url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permisos y politicas'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualizar'),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _titulo('Permisos de la app'),
                const SizedBox(height: 8),
                ..._permisos.map(_filaPermiso),
                const SizedBox(height: 18),
                _titulo('Legal y privacidad'),
                const SizedBox(height: 8),
                _link(Icons.privacy_tip_rounded, 'Politicas de privacidad', Policies.privacidad),
                _link(Icons.description_rounded, 'Terminos y condiciones', Policies.terminos),
                _link(Icons.assignment_return_rounded, 'Politicas de devolucion', Policies.devoluciones),
                _link(Icons.security_rounded, 'Seguridad de datos', Policies.seguridad),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _titulo(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: VaiaColors.textSecondary, letterSpacing: 0.3));

  Widget _filaPermiso(PermisoDef def) {
    final ok = _estados[def.id] == true;
    final color = ok ? VaiaColors.success : VaiaColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: def.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(VaiaRadius.md)),
            child: Icon(def.icono, color: def.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(ok ? 'Concedido' : 'No concedido',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),
          if (!ok && !def.soloAviso)
            TextButton(
              onPressed: () => _solicitar(def),
              child: const Text('Permitir', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          else if (!ok)
            IconButton(
              onPressed: PermissionService.abrirAjustes,
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Abrir ajustes',
            ),
        ],
      ),
    );
  }

  Widget _link(IconData icono, String titulo, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrir(titulo, url),
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: VaiaColors.surface,
            borderRadius: BorderRadius.circular(VaiaRadius.md),
            border: Border.all(color: VaiaColors.border),
          ),
          child: Row(
            children: [
              Icon(icono, size: 20, color: VaiaColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
              const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
