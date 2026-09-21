import 'package:flutter/material.dart';
import '../config/policies.dart';
import '../config/theme.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/vaia_widgets.dart';
import 'webview_screen.dart';

/// Onboarding de primer arranque: explica y solicita cada permiso y exige
/// aceptar los terminos y condiciones antes de llegar al login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _storage = StorageService();
  final List<PermisoDef> _permisos = PermissionService.conductor();
  int _pagina = 0;
  bool _terminos = false;
  bool _procesando = false;

  int get _total => _permisos.length + 1;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _permitir(PermisoDef def) async {
    setState(() => _procesando = true);
    if (!def.soloAviso) {
      await PermissionService.solicitar(def);
    }
    if (!mounted) return;
    setState(() => _procesando = false);
    _siguiente();
  }

  void _siguiente() {
    if (_pagina < _total - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Future<void> _finalizar() async {
    if (!_terminos) return;
    setState(() => _procesando = true);
    await _storage.setTerminosAceptados(true);
    await _storage.setOnboardingCompletado(true);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _abrirPolitica(String titulo, String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewScreen(titulo: titulo, url: url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _pagina = i),
                children: [
                  ..._permisos.map(_paginaPermiso),
                  _paginaTerminos(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        children: [
          Row(
            children: [
              const VaiaLogo(size: 34, showText: true),
              const Spacer(),
              Text('${_pagina + 1}/$_total',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: VaiaColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_pagina + 1) / _total,
              minHeight: 6,
              backgroundColor: VaiaColors.bgMuted,
              valueColor: const AlwaysStoppedAnimation(VaiaColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaPermiso(PermisoDef def) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: def.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: def.color.withValues(alpha: 0.3), width: 2),
              ),
              child: Icon(def.icono, size: 50, color: def.color),
            ),
          ),
          const SizedBox(height: 26),
          Text(def.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 10),
          Text(def.descripcion,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: VaiaColors.textSecondary, height: 1.4)),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VaiaColors.surface,
              borderRadius: BorderRadius.circular(VaiaRadius.lg),
              border: Border.all(color: VaiaColors.border),
            ),
            child: Column(
              children: def.puntos
                  .map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 18, color: def.color),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p, style: const TextStyle(fontSize: 13, color: VaiaColors.textSecondary))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Spacer(),
          VaiaPrimaryButton(
            label: def.soloAviso ? 'Entendido' : 'Permitir',
            icon: def.soloAviso ? Icons.check_rounded : Icons.verified_user_rounded,
            loading: _procesando,
            onPressed: _procesando ? null : () => _permitir(def),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _procesando ? null : _siguiente,
            child: Text(def.obligatorio ? 'Continuar' : 'Ahora no'),
          ),
        ],
      ),
    );
  }

  Widget _paginaTerminos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(
            child: Icon(Icons.gavel_rounded, size: 46, color: VaiaColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('Terminos y condiciones',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          const Text('Para usar Vaia Conductor debes aceptar nuestras politicas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _linkPolitica(Icons.privacy_tip_rounded, 'Politicas de privacidad', Policies.privacidad),
                  _linkPolitica(Icons.description_rounded, 'Terminos y condiciones', Policies.terminos),
                  _linkPolitica(Icons.assignment_return_rounded, 'Politicas de devolucion', Policies.devoluciones),
                  _linkPolitica(Icons.security_rounded, 'Seguridad de datos', Policies.seguridad),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _terminos = !_terminos),
            borderRadius: BorderRadius.circular(VaiaRadius.md),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _terminos ? VaiaColors.primaryGhost : VaiaColors.surface,
                borderRadius: BorderRadius.circular(VaiaRadius.md),
                border: Border.all(color: _terminos ? VaiaColors.primary : VaiaColors.border),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _terminos,
                    onChanged: (v) => setState(() => _terminos = v ?? false),
                    activeColor: VaiaColors.primary,
                  ),
                  const Expanded(
                    child: Text(
                      'Acepto los terminos y condiciones, el aviso de privacidad, las politicas de devolucion y la seguridad de datos.',
                      style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          VaiaPrimaryButton(
            label: 'Aceptar y continuar',
            icon: Icons.arrow_forward_rounded,
            loading: _procesando,
            onPressed: (_terminos && !_procesando) ? _finalizar : null,
          ),
        ],
      ),
    );
  }

  Widget _linkPolitica(IconData icono, String titulo, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirPolitica(titulo, url),
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
              const Icon(Icons.open_in_new_rounded, size: 16, color: VaiaColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
