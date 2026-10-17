import '../../services/google_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/vaia_widgets.dart';
import '../widgets/login_background.dart';
import '../services/app_info.dart';
import 'register_screen.dart';
import 'recover_password_screen.dart';

const String _linkDescargaConductor =
    'https://play.google.com/store/apps/details?id=prozoft.com.vaiaconductor&hl=es_MX';

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

  Future<void> _loginConGoogle() async {
    try {
      final idToken = await GoogleAuthService.obtenerIdToken();
      if (idToken == null) return;
      final auth = context.read<AuthProvider>();
      final ok = await auth.loginConGoogle(idToken);
      if (!mounted) return;
      if (ok) { Navigator.pushReplacementNamed(context, '/home'); }
      else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'No se pudo iniciar sesion con Google'), backgroundColor: VaiaColors.danger)); }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: VaiaColors.danger));
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _accountCtrl.text.trim(),
      _passCtrl.text,
      dispositivoInfo: AppInfo.dispositivo,
      sistemaOperativo: AppInfo.sistemaOperativo,
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
      body: Stack(
        children: [
          Positioned.fill(child: LoginBackground(accent: VaiaColors.primary, accent2: VaiaColors.accent)),
          SafeArea(
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
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VaiaTextField(
                        controller: _accountCtrl,
                        label: 'Correo o telefono',
                        hint: 'Correo verificado o telefono verificado',
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
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: auth.loading ? null : _loginConGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: const Text('Continuar con Google'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _beneficios(),
                const SizedBox(height: 10),
                _compartir(),
                const Spacer(),
                const SizedBox(height: 8),
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
                const SizedBox(height: 2),
                Center(
                  child: Text('Vaia Conductor v${AppInfo.versionCompleta}',
                      style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted)),
                ),
                const SizedBox(height: 8),
              ],
              ),
            ),
          ),
        ),
        ),
      ],
    ),
  );
  }

  Widget _beneficios() {
    Widget fila(IconData icono, String texto) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(8)),
              child: Icon(icono, size: 15, color: VaiaColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary, fontWeight: FontWeight.w500))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fila(Icons.payments_rounded, 'Gana mas con cada viaje y cobra puntual'),
          fila(Icons.schedule_rounded, 'Tu decides cuando y donde trabajar'),
          fila(Icons.map_rounded, 'Zonas de mayor demanda en tiempo real'),
        ],
      ),
    );
  }

  Widget _compartir() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [VaiaColors.primary.withValues(alpha: 0.10), VaiaColors.accent.withValues(alpha: 0.10)],
        ),
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: VaiaColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.group_add_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comparte la app', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                SizedBox(height: 1),
                Text('Invita a otros conductores a unirse a Vaia',
                    style: TextStyle(fontSize: 11, color: VaiaColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Compartir por WhatsApp',
            icon: const Icon(Icons.share_rounded, color: VaiaColors.primary),
            onPressed: _compartirWhatsApp,
          ),
          IconButton(
            tooltip: 'Copiar enlace',
            icon: const Icon(Icons.link_rounded, color: VaiaColors.primary),
            onPressed: _copiarEnlace,
          ),
        ],
      ),
    );
  }

  Future<void> _compartirWhatsApp() async {
    final msg = Uri.encodeComponent(
        'Unete a Vaia Conductor, la app para ganar mas con tus viajes. Descargala gratis: $_linkDescargaConductor');
    final uri = Uri.parse('https://wa.me/?text=$msg');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _copiarEnlace();
      }
    } catch (_) {
      await _copiarEnlace();
    }
  }

  Future<void> _copiarEnlace() async {
    await Clipboard.setData(const ClipboardData(text: _linkDescargaConductor));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace de descarga copiado'), backgroundColor: VaiaColors.success),
    );
  }
}