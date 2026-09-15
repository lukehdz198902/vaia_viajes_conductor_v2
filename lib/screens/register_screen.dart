import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/vaia_widgets.dart';

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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final data = {
      'idCompania': 1,
      'nombre': _nombreCtrl.text.trim(),
      'appaterno': _appCtrl.text.trim(),
      'apmaterno': _apmCtrl.text.trim(),
      'genero': 'M',
      'codigopaistel': '+52',
      'correo': _correoCtr.text.trim(),
      'telefono': _telCtrl.text.trim(),
      'googlekey': '',
      'account': _accountCtrl.text.trim(),
      'pass': _passCtrl.text,
    };
    final ok = await auth.register(data);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso. Inicia sesion.'),
          backgroundColor: VaiaColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error al registrar'),
          backgroundColor: VaiaColors.danger,
        ),
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
                Text('Crear cuenta de conductor', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  'Registrate para empezar a generar ingresos',
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
                    if (!v.contains('@') || !v.contains('.')) return 'Correo invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _telCtrl,
                  label: 'Telefono',
                  hint: '5512345678',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (v.trim().length != 10) return '10 digitos';
                    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Solo numeros';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Datos de la cuenta', Icons.lock_outline_rounded),
                const SizedBox(height: 10),
                VaiaTextField(
                  controller: _accountCtrl,
                  label: 'Usuario',
                  hint: 'Tu nombre de usuario',
                  prefixIcon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _passCtrl,
                  label: 'Contrasena',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 6) return 'Minimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _confirmPassCtrl,
                  label: 'Confirmar contrasena',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v != _passCtrl.text) return 'No coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                VaiaPrimaryButton(
                  label: 'Registrarse',
                  icon: Icons.arrow_forward_rounded,
                  loading: auth.loading,
                  onPressed: auth.loading ? null : _register,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.4),
        ),
      ],
    );
  }
}