import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/vaia_widgets.dart';
import 'register_screen.dart';
import 'recover_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _accountCtrl.text.trim(),
      _passCtrl.text,
      dispositivoInfo: 'Flutter Conductor App',
      sistemaOperativo: 'Android',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error al iniciar sesion'),
          backgroundColor: VaiaColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(child: VaiaLogo(size: 64, showText: true)),
                const SizedBox(height: 32),
                Text(
                  'Bienvenido conductor',
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicia sesion para empezar a recibir viajes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VaiaTextField(
                        controller: _accountCtrl,
                        label: 'Usuario o correo',
                        hint: 'Tu cuenta de conductor',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Ingrese su usuario' : null,
                      ),
                      const SizedBox(height: 14),
                      VaiaTextField(
                        controller: _passCtrl,
                        label: 'Contrasena',
                        hint: 'Ingrese su contrasena',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Ingrese su contrasena' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RecoverPasswordScreen()),
                          ),
                          child: const Text('Olvide mi contrasena'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      VaiaPrimaryButton(
                        label: 'Iniciar sesion',
                        icon: Icons.arrow_forward_rounded,
                        loading: auth.loading,
                        onPressed: auth.loading ? null : _login,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('No tienes cuenta?', style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Registrate'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}