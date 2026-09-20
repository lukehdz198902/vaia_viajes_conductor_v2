import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'vaia_widgets.dart';

/// Aviso moderno para verificar el correo electronico del conductor.
/// Se muestra como hoja inferior con encabezado degradado, pasos y acciones.
class EmailVerificationSheet extends StatefulWidget {
  const EmailVerificationSheet({super.key});

  /// Muestra la hoja y devuelve true si el correo quedo verificado.
  static Future<bool> mostrar(BuildContext context) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const EmailVerificationSheet(),
    );
    return r ?? false;
  }

  @override
  State<EmailVerificationSheet> createState() => _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends State<EmailVerificationSheet> {
  final _codigoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  bool _enviando = false;
  bool _verificando = false;
  bool _codigoEnviado = false;
  bool _editandoCorreo = false;

  @override
  void initState() {
    super.initState();
    _correoCtrl.text = context.read<AuthProvider>().conductor?.correo ?? '';
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? VaiaColors.danger : VaiaColors.success),
    );
  }

  Future<void> _enviarCodigo() async {
    final auth = context.read<AuthProvider>();
    setState(() => _enviando = true);
    final ok = await auth.enviarCodigoCorreo();
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _codigoEnviado = ok;
    });
    _snack(ok ? 'Codigo enviado a tu correo' : 'No se pudo enviar el codigo', error: !ok);
  }

  Future<void> _verificar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length < 6) {
      _snack('Ingresa el codigo de 6 digitos', error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _verificando = true);
    final ok = await auth.validarCodigoCorreo(codigo);
    if (!mounted) return;
    setState(() => _verificando = false);
    if (ok) {
      _snack('Correo verificado');
      Navigator.pop(context, true);
    } else {
      _snack(auth.error ?? 'Codigo invalido', error: true);
    }
  }

  Future<void> _guardarCorreo() async {
    final nuevo = _correoCtrl.text.trim();
    if (!RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]{2,}$').hasMatch(nuevo)) {
      _snack('Correo invalido', error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _enviando = true);
    final ok = await auth.actualizarCorreo(nuevo);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _editandoCorreo = false;
    });
    if (ok) {
      await _enviarCodigo();
    } else {
      _snack(auth.error ?? 'No se pudo actualizar el correo', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final correo = context.watch<AuthProvider>().conductor?.correo ?? '';
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: VaiaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _correoChip(correo),
                      const SizedBox(height: 20),
                      if (!_codigoEnviado) ...[
                        _paso(
                          numero: '1',
                          titulo: 'Envia el codigo',
                          detalle: 'Te enviaremos un codigo de 6 digitos al correo indicado.',
                        ),
                        const SizedBox(height: 18),
                        VaiaPrimaryButton(
                          label: 'Enviar codigo',
                          icon: Icons.send_rounded,
                          loading: _enviando,
                          onPressed: _enviando ? null : _enviarCodigo,
                        ),
                      ] else ...[
                        _paso(
                          numero: '2',
                          titulo: 'Ingresa el codigo',
                          detalle: 'Escribe el codigo de 6 digitos que llego a tu correo.',
                        ),
                        const SizedBox(height: 16),
                        VaiaTextField(
                          controller: _codigoCtrl,
                          label: 'Codigo de verificacion',
                          hint: '000000',
                          prefixIcon: Icons.password_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofocus: true,
                          onFieldSubmitted: (_) => _verificar(),
                        ),
                        const SizedBox(height: 16),
                        VaiaPrimaryButton(
                          label: 'Verificar correo',
                          icon: Icons.verified_rounded,
                          loading: _verificando,
                          onPressed: _verificando ? null : _verificar,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _enviando ? null : _enviarCodigo,
                          child: const Text('Reenviar codigo'),
                        ),
                      ],
                      const Divider(height: 28),
                      if (_editandoCorreo) ...[
                        VaiaTextField(
                          controller: _correoCtrl,
                          label: 'Nuevo correo electronico',
                          hint: 'tu@correo.com',
                          prefixIcon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _editandoCorreo = false),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _enviando ? null : _guardarCorreo,
                              child: const Text('Guardar y enviar'),
                            ),
                          ),
                        ]),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _editandoCorreo = true),
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                label: const Text('Cambiar correo'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Mas tarde'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: const BoxDecoration(
        gradient: VaiaColors.heroGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(VaiaRadius.lg),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.mark_email_unread_rounded, color: VaiaColors.primaryDark, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verifica tu correo',
                      style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Protege tu cuenta y no pierdas acceso',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _correoChip(String correo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VaiaColors.primaryGhost,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alternate_email_rounded, size: 18, color: VaiaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              correo.isEmpty ? 'Sin correo registrado' : correo,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.verified_outlined, size: 18, color: VaiaColors.textMuted),
        ],
      ),
    );
  }

  Widget _paso({required String numero, required String titulo, required String detalle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: VaiaColors.primary, shape: BoxShape.circle),
          child: Text(numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}
