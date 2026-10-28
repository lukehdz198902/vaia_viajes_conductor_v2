import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../widgets/slide_to_confirm.dart';

/// Baja definitiva de la cuenta del conductor.
///
/// Se muestra en una pantalla completa (no en un dialogo) para que la
/// advertencia, la contrasena y el boton deslizable tengan espacio suficiente
/// y el conductor entienda que la accion no se puede revertir.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _api = ApiService();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _eliminada = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: VaiaColors.danger,
    ));
  }

  Future<void> _darDeBaja() async {
    if (_loading) return;
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) {
      _aviso('Ingresa tu contrasena para confirmar');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final res = await _api.darDeBaja(auth.userId, pass);
    if (!mounted) return;

    if (!res.ok) {
      setState(() => _loading = false);
      final mensaje = res.mensaje.trim();
      _aviso(mensaje.isNotEmpty ? mensaje : 'No se pudo dar de baja la cuenta');
      return;
    }

    // Detiene el reporte de ubicacion y el sondeo antes de cerrar la sesion.
    try {
      final ride = context.read<RideProvider>();
      ride.stopPolling();
      ride.detenerPresencia();
    } catch (_) {}

    await auth.logout();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _eliminada = true;
    });
  }

  void _irAlLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_eliminada,
      child: Scaffold(
        backgroundColor: VaiaColors.bgLight,
        appBar: AppBar(
          title: Text(_eliminada ? 'Cuenta dada de baja' : 'Eliminar mi cuenta'),
          automaticallyImplyLeading: !_eliminada,
        ),
        body: _eliminada ? _vistaFinal() : _vistaConfirmacion(),
      ),
    );
  }

  Widget _vistaConfirmacion() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(VaiaRadius.lg),
            boxShadow: [
              BoxShadow(
                color: VaiaColors.danger.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.person_off_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Esta accion no se puede revertir',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('Al confirmar, tu cuenta quedara desactivada de forma permanente.',
                        style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.report_gmailerrorred_rounded, size: 19, color: VaiaColors.danger),
                  SizedBox(width: 8),
                  Text('Esto es lo que sucedera',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              _punto('Perderas el acceso a la app con este numero y correo.'),
              _punto('Tu perfil, documentos, unidad y ganancias quedaran desactivados.'),
              _punto('Se cerraran todas las sesiones y dispositivos conectados.'),
              _punto('Quedaras desconectado y no podras recibir servicios.'),
              _punto('No podras recuperar la cuenta desde la aplicacion.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirma con tu contrasena',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Solo con tu contrasena podemos validar que eres el titular de la cuenta.',
                  style: TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary, height: 1.4)),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Contrasena actual',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    tooltip: _obscure ? 'Mostrar contrasena' : 'Ocultar contrasena',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SlideToConfirm(
                label: 'Desliza para eliminar mi cuenta',
                color: VaiaColors.danger,
                enabled: _passCtrl.text.trim().isNotEmpty,
                loading: _loading,
                onConfirm: _darDeBaja,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar y volver', style: TextStyle(color: VaiaColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _vistaFinal() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VaiaColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: VaiaColors.success, size: 54),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Tu cuenta fue dada de baja',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: VaiaColors.textPrimary)),
        const SizedBox(height: 10),
        const Text(
          'Tu cuenta quedo desactivada y ya no podras iniciar sesion. '
          'Tambien cerramos tus dispositivos conectados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: VaiaColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VaiaColors.primaryGhost,
            borderRadius: BorderRadius.circular(VaiaRadius.md),
            border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.22)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: VaiaColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enviamos un correo de confirmacion. Si no reconoces este movimiento, contacta al area de soporte de Vaia.',
                  style: TextStyle(fontSize: 12, color: VaiaColors.textSecondary, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _irAlLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Ir al inicio de sesion'),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VaiaColors.surface,
          borderRadius: BorderRadius.circular(VaiaRadius.lg),
          border: Border.all(color: VaiaColors.border),
          boxShadow: VaiaShadows.card,
        ),
        child: child,
      );

  Widget _punto(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.remove_circle_outline_rounded, size: 16, color: VaiaColors.danger),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto,
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: VaiaColors.textSecondary)),
            ),
          ],
        ),
      );
}
