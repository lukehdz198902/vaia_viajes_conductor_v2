import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/vaia_widgets.dart';
import 'verify_phone_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _appCtrl = TextEditingController();
  final _apmCtrl = TextEditingController();
  final _correoCtr = TextEditingController();
  final _telCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _enviandoCodigo = false;

  static final _emailRegex = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]{2,}$');

  @override
  void initState() {
    super.initState();
    // El usuario se prellena automaticamente con el telefono
    _telCtrl.addListener(() {
      final tel = _telCtrl.text.trim();
      if (_accountCtrl.text != tel) _accountCtrl.text = tel;
      setState(() {});
    });
    _passCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _appCtrl.dispose();
    _apmCtrl.dispose();
    _correoCtr.dispose();
    _telCtrl.dispose();
    _accountCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  bool get _tieneLargo => _passCtrl.text.length >= 8;
  bool get _tieneMayus => _passCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _tieneDigito => _passCtrl.text.contains(RegExp(r'[0-9]'));

  Future<void> _continuar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final telefono = _telCtrl.text.trim();
    const pais = '+52';

    setState(() => _enviandoCodigo = true);
    final enviado = await auth.enviarCodigoVerificacion(telefono, pais);
    if (!mounted) return;
    setState(() => _enviandoCodigo = false);

    if (!enviado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el codigo por WhatsApp. Verifica tu numero.'), backgroundColor: VaiaColors.danger),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerifyPhoneScreen(
        telefono: telefono,
        codigopaistel: pais,
        onValidar: (code) => auth.validarCodigoVerificacion(telefono, pais, code),
        onReenviar: () => auth.enviarCodigoVerificacion(telefono, pais),
        onVerified: () => _registrar(auth, telefono, pais),
      ),
    ));
  }

  Future<void> _registrar(AuthProvider auth, String telefono, String pais) async {
    final data = {
      'idCompania': 1,
      'nombre': _nombreCtrl.text.trim(),
      'appaterno': _appCtrl.text.trim(),
      'apmaterno': _apmCtrl.text.trim(),
      'genero': 'M',
      'codigopaistel': pais,
      'correo': _correoCtr.text.trim(),
      'telefono': telefono,
      'googlekey': '',
      'account': _accountCtrl.text.trim(),
      'pass': _passCtrl.text,
    };
    final ok = await auth.register(data);
    if (!mounted) return;
    if (ok) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: VaiaColors.success, size: 48),
          title: const Text('Registro exitoso'),
          content: const Text('Tu cuenta fue creada. Te enviamos un correo para verificar tu email y el siguiente paso es subir tu documentacion.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Error al registrar'), backgroundColor: VaiaColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: VaiaLogo(size: 64)),
                const SizedBox(height: 16),
                Text('Crear cuenta de conductor', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'Registrate para empezar a generar ingresos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Informacion personal', Icons.person_outline_rounded),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: VaiaTextField(
                        controller: _nombreCtrl,
                        label: 'Nombre',
                        prefixIcon: Icons.badge_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VaiaTextField(
                        controller: _appCtrl,
                        label: 'Ap. Paterno',
                        textInputAction: TextInputAction.next,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _apmCtrl,
                  label: 'Ap. Materno (opcional)',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _correoCtr,
                  label: 'Correo electronico',
                  hint: 'tu@correo.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (!_emailRegex.hasMatch(v.trim())) return 'Correo invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _telCtrl,
                  label: 'Telefono (sera tu usuario)',
                  hint: '5512345678',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (v.trim().length != 10) return 'Deben ser 10 digitos';
                    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Solo numeros';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _accountCtrl,
                  label: 'Usuario',
                  hint: 'Se llena con tu telefono',
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: false,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Seguridad', Icons.lock_outline_rounded),
                const SizedBox(height: 10),
                VaiaTextField(
                  controller: _passCtrl,
                  label: 'Contrasena',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 8) return 'Minimo 8 caracteres';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Al menos 1 mayuscula';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Al menos 1 digito';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _reglaPassword('Minimo 8 caracteres', _tieneLargo),
                _reglaPassword('Al menos 1 letra mayuscula', _tieneMayus),
                _reglaPassword('Al menos 1 digito', _tieneDigito),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _confirmPassCtrl,
                  label: 'Confirmar contrasena',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _continuar(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v != _passCtrl.text) return 'No coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                VaiaPrimaryButton(
                  label: 'Continuar',
                  icon: Icons.arrow_forward_rounded,
                  loading: auth.loading || _enviandoCodigo,
                  onPressed: (auth.loading || _enviandoCodigo) ? null : _continuar,
                ),
                const SizedBox(height: 8),
                Text(
                  'Te enviaremos un codigo por WhatsApp para verificar tu telefono.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VaiaColors.textSecondary),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reglaPassword(String texto, bool cumple) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        children: [
          Icon(cumple ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16, color: cumple ? VaiaColors.success : VaiaColors.textSecondary),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(fontSize: 12, color: cumple ? VaiaColors.success : VaiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: VaiaColors.primaryGhost,
            borderRadius: BorderRadius.circular(VaiaRadius.sm),
          ),
          child: Icon(icon, size: 16, color: VaiaColors.primary),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.4)),
      ],
    );
  }
}
