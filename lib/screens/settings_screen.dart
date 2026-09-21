import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _biometria = false;

  @override
  void initState() {
    super.initState();
    StorageService().getBiometriaHabilitada().then((v) {
      if (mounted) setState(() => _biometria = v);
    });
  }

  /// Activa o desactiva la seguridad biometrica.
  Future<void> _cambiarBiometria(bool v) async {
    final storage = StorageService();
    if (v) {
      final disponible = await BiometricService.disponible();
      if (!disponible) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tu dispositivo no tiene biometria configurada'), backgroundColor: AppTheme.danger),
          );
        }
        return;
      }
      final ok = await BiometricService.autenticar(motivo: 'Activa la seguridad biometrica de Vaia Conductor');
      if (!ok) return;
      await storage.setBiometriaHabilitada(true);
    } else {
      await storage.setBiometriaHabilitada(false);
    }
    if (mounted) setState(() => _biometria = v);
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: AppTheme.danger));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final api = ApiService();
    final resp = await api.cambiarPassword(auth.userId, _currentPassCtrl.text, _newPassCtrl.text);
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.ok ? 'Contraseña actualizada' : resp.mensaje), backgroundColor: resp.ok ? AppTheme.accent : AppTheme.danger),
      );
      if (resp.ok) {
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Cambiar Contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _currentPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña Actual', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 12),
          TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva Contraseña', prefixIcon: Icon(Icons.lock))),
          const SizedBox(height: 12),
          TextField(controller: _confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar Contraseña', prefixIcon: Icon(Icons.lock))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _changePassword,
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Actualizar Contraseña'),
            ),
          ),
          const Divider(height: 40),
          const Text('Seguridad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VaiaRadius.md),
              side: const BorderSide(color: VaiaColors.border),
            ),
            child: SwitchListTile(
              title: const Text('Seguridad biometrica', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_biometria ? 'Activada' : 'Desactivada', style: const TextStyle(color: VaiaColors.textSecondary)),
              secondary: const Icon(Icons.fingerprint_rounded, color: VaiaColors.primary),
              activeColor: VaiaColors.primary,
              value: _biometria,
              onChanged: _cambiarBiometria,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Permisos y privacidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/permisos'),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Ver permisos y politicas'),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                final ride = context.read<RideProvider>();
                final navigator = Navigator.of(context);
                ride.stopPolling();
                ride.detenerPresencia();
                await auth.logout();
                if (mounted) navigator.pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.logout, color: AppTheme.danger),
              label: const Text('Cerrar Sesión', style: TextStyle(color: AppTheme.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
