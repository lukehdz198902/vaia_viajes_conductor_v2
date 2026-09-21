import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/vaia_widgets.dart';

/// Recuperacion de contrasena del conductor:
/// 1) captura el telefono y envia un codigo por WhatsApp,
/// 2) valida el codigo y establece la nueva contrasena.
class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});
  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _api = ApiService();
  final _telCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _codigoEnviado = false;
  bool _loading = false;
  bool _verPass = false;
  String? _error;

  @override
  void dispose() {
    _telCtrl.dispose();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? VaiaColors.danger : VaiaColors.success),
    );
  }

  Future<void> _enviarCodigo() async {
    final tel = _telCtrl.text.trim();
    if (tel.length != 10 || !RegExp(r'^\d{10}$').hasMatch(tel)) {
      setState(() => _error = 'Ingresa tu telefono a 10 digitos');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await _api.enviarCodigoVerificacion(tel, '+52');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _codigoEnviado = r.ok;
      _error = r.ok ? null : (r.mensaje.isNotEmpty ? r.mensaje : 'No se pudo enviar el codigo');
    });
    if (r.ok) _snack('Codigo enviado por WhatsApp');
  }

  Future<void> _actualizar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _error = 'Las contrasenas no coinciden');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await _api.recuperarPassword(_telCtrl.text.trim(), _codigoCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.ok) {
      _snack('Contrasena actualizada. Ya puedes iniciar sesion.');
      Navigator.of(context).pop();
    } else {
      setState(() => _error = r.mensaje.isNotEmpty ? r.mensaje : 'No se pudo actualizar la contrasena');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.lock_reset_rounded, size: 52, color: VaiaColors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Recuperar contrasena', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  _codigoEnviado
                      ? 'Escribe el codigo que enviamos a tu WhatsApp y tu nueva contrasena.'
                      : 'Te enviaremos un codigo por WhatsApp para confirmar que eres tu.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                ),
                const SizedBox(height: 24),
                VaiaTextField(
                  controller: _telCtrl,
                  label: 'Telefono',
                  hint: '10 digitos',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_codigoEnviado,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return '10 digitos';
                    return null;
                  },
                ),
                if (_codigoEnviado) ...[
                  const SizedBox(height: 14),
                  VaiaTextField(
                    controller: _codigoCtrl,
                    label: 'Codigo de verificacion',
                    hint: '6 digitos',
                    prefixIcon: Icons.password_rounded,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (v) => (v == null || v.trim().length < 6) ? 'Ingresa el codigo' : null,
                  ),
                  const SizedBox(height: 14),
                  VaiaTextField(
                    controller: _passCtrl,
                    label: 'Nueva contrasena',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !_verPass,
                    suffixIcon: IconButton(
                      icon: Icon(_verPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _verPass = !_verPass),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Minimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  VaiaTextField(
                    controller: _pass2Ctrl,
                    label: 'Confirmar contrasena',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !_verPass,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VaiaColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: VaiaColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: const TextStyle(color: VaiaColors.danger, fontSize: 12.5))),
                    ]),
                  ),
                ],
                const SizedBox(height: 22),
                VaiaPrimaryButton(
                  label: _codigoEnviado ? 'Actualizar contrasena' : 'Enviar codigo',
                  icon: _codigoEnviado ? Icons.check_rounded : Icons.send_rounded,
                  loading: _loading,
                  onPressed: _loading ? null : (_codigoEnviado ? _actualizar : _enviarCodigo),
                ),
                if (_codigoEnviado) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _loading ? null : _enviarCodigo,
                    child: const Text('Reenviar codigo'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
