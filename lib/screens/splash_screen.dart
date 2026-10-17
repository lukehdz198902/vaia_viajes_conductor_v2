import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../widgets/login_background.dart';
import 'pin_screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final auth = context.read<AuthProvider>();
    final storage = StorageService();
    // Primer arranque: primero los permisos y la aceptacion de terminos.
    final onboarding = await storage.getOnboardingCompletado();
    if (!mounted) return;
    if (!onboarding) {
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
      return;
    }
    // Seguridad por PIN: si esta habilitado, se exige al abrir la app.
    if (await storage.getPinHabilitado()) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PinLockScreen()),
        (route) => false,
      );
      return;
    }
    // Seguridad biometrica: si esta habilitada, se exige al abrir la app.
    if (await storage.getBiometriaHabilitada()) {
      if (!mounted) return;
      final ok = await BiometricService.autenticar(motivo: 'Desbloquea Vaia Conductor para continuar');
      if (!mounted) return;
      if (!ok) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
    }
    await auth.tryAutoLogin();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    // Se elimina por completo el splash de la pila para que nunca quede de
    // fondo ni vuelva a mostrarse al cerrar la pantalla principal.
    if (auth.isLoggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: LoginBackground(accent: VaiaColors.primary, accent2: VaiaColors.accent)),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Image.asset('assets/images/logo.png', width: 96, height: 96),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Vaia Conductor',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: VaiaColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tu camino, tu ingreso',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: VaiaColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 44),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: VaiaColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}