import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/app_info.dart';
import '../services/biometric_service.dart';
import '../services/locale_provider.dart';
import '../services/storage_service.dart';
import 'pin_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _biometria = false;
  bool _pinHabilitado = false;

  // Contacto de emergencia
  final _emNombreCtrl = TextEditingController();
  final _emTelCtrl = TextEditingController();
  final _emCorreo1Ctrl = TextEditingController();
  final _emCorreo2Ctrl = TextEditingController();
  bool _guardandoEmergencia = false;
  bool _tieneEmergencia = false;

  // Dispositivos
  List<Map<String, dynamic>> _sesiones = [];
  bool _cargandoSesiones = true;

  @override
  void initState() {
    super.initState();
    StorageService().getBiometriaHabilitada().then((v) {
      if (mounted) setState(() => _biometria = v);
    });
    StorageService().getPinHabilitado().then((v) {
      if (mounted) setState(() => _pinHabilitado = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarEmergenciaYSesiones());
  }

  void _toast(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? VaiaColors.success : VaiaColors.danger,
    ));
  }

  Future<void> _cargarEmergenciaYSesiones() async {
    final auth = context.read<AuthProvider>();
    try {
      final c = await _api.obtenerContactoEmergencia(auth.userId);
      if (c.ok && c.list != null && c.list!.isNotEmpty && c.list!.first is Map) {
        final m = Map<String, dynamic>.from(c.list!.first as Map);
        if (mounted) {
          setState(() {
            _tieneEmergencia = true;
            _emNombreCtrl.text = m['nombrecompleto']?.toString() ?? '';
            _emTelCtrl.text = m['telefono']?.toString() ?? '';
            _emCorreo1Ctrl.text = m['correo1']?.toString() ?? '';
            _emCorreo2Ctrl.text = m['correo2']?.toString() ?? '';
          });
        }
      }
    } catch (_) {}
    try {
      final token = await StorageService().getSessionToken();
      final s = await _api.listarSesiones(auth.userId, tokenActual: token);
      if (s.ok && s.list != null && mounted) {
        setState(() {
          _sesiones = s.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _cargandoSesiones = false;
        });
      } else if (mounted) {
        setState(() => _cargandoSesiones = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoSesiones = false);
    }
  }

  Future<void> _guardarEmergencia() async {
    if (_emNombreCtrl.text.trim().isEmpty) { _toast('Ingresa el nombre del contacto', ok: false); return; }
    final tel = _emTelCtrl.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(tel)) { _toast('El telefono debe tener 10 digitos', ok: false); return; }
    final auth = context.read<AuthProvider>();
    setState(() => _guardandoEmergencia = true);
    final res = await _api.guardarContactoEmergencia({
      'idConductor': auth.userId,
      'nombrecompleto': _emNombreCtrl.text.trim(),
      'telefono': tel,
      'correo1': _emCorreo1Ctrl.text.trim().isEmpty ? null : _emCorreo1Ctrl.text.trim(),
      'correo2': _emCorreo2Ctrl.text.trim().isEmpty ? null : _emCorreo2Ctrl.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _guardandoEmergencia = false;
      if (res.ok) _tieneEmergencia = true;
    });
    _toast(res.ok ? 'Contacto de emergencia guardado' : (res.mensaje.isNotEmpty ? res.mensaje : 'No se pudo guardar'), ok: res.ok);
  }

  Future<void> _cerrarDispositivo(Map<String, dynamic> s) async {
    final auth = context.read<AuthProvider>();
    final id = int.tryParse(s['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final res = await _api.cerrarSesionDispositivo(id, auth.userId);
    if (res.ok && mounted) {
      _toast('Sesion cerrada en el dispositivo');
      _cargarEmergenciaYSesiones();
    }
  }

  /// Activa, cambia o desactiva el PIN de seguridad.
  Future<void> _configurarPin(bool v) async {
    final storage = StorageService();
    if (v) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (ok == true && mounted) {
        setState(() => _pinHabilitado = true);
        _toast('PIN de seguridad activado');
      }
    } else {
      await storage.removePin();
      if (mounted) setState(() => _pinHabilitado = false);
    }
  }

  /// Activa o desactiva la seguridad biometrica.
  Future<void> _cambiarBiometria(bool v) async {
    final storage = StorageService();
    if (v) {
      final disponible = await BiometricService.disponible();
      if (!disponible) {
        _toast('Tu dispositivo no tiene biometria configurada', ok: false);
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
    _emNombreCtrl.dispose();
    _emTelCtrl.dispose();
    _emCorreo1Ctrl.dispose();
    _emCorreo2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _toast('Las contraseñas no coinciden', ok: false);
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final resp = await _api.cambiarPassword(auth.userId, _currentPassCtrl.text, _newPassCtrl.text);
    setState(() => _loading = false);
    if (!mounted) return;
    _toast(resp.ok ? 'Contraseña actualizada' : resp.mensaje, ok: resp.ok);
    if (resp.ok) {
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    }
  }

  String _fechaAcceso(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return 'Ultimo acceso: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'Configuración', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _seccion(S.t(context, 'Apariencia', 'Appearance')),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: ListTile(
              leading: const Icon(Icons.language_rounded, color: VaiaColors.primary),
              title: Text(S.t(context, 'Idioma / Language', 'Language / Idioma'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(idioma.lang == 'en' ? 'English' : 'Espanol', style: const TextStyle(color: VaiaColors.textSecondary)),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'es', label: Text('ES')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {idioma.lang},
                onSelectionChanged: (s) => idioma.setLang(s.first),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _seccion(S.t(context, 'Seguridad', 'Security')),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Seguridad biometrica', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_biometria ? 'Activada' : 'Desactivada', style: const TextStyle(color: VaiaColors.textSecondary)),
                  secondary: const Icon(Icons.fingerprint_rounded, color: VaiaColors.primary),
                  activeColor: VaiaColors.primary,
                  value: _biometria,
                  onChanged: _cambiarBiometria,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('PIN de seguridad', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_pinHabilitado ? 'Activado (4 digitos)' : 'Desactivado', style: const TextStyle(color: VaiaColors.textSecondary)),
                  secondary: const Icon(Icons.pin_rounded, color: VaiaColors.primary),
                  activeColor: VaiaColors.primary,
                  value: _pinHabilitado,
                  onChanged: _configurarPin,
                ),
                if (_pinHabilitado)
                  ListTile(
                    leading: const Icon(Icons.password_rounded, color: VaiaColors.primary),
                    title: const Text('Cambiar PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
                    onTap: () => _configurarPin(true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _seccion(S.t(context, 'Cambiar Contraseña', 'Change Password')),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(controller: _currentPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña Actual', prefixIcon: Icon(Icons.lock_outline))),
                  const SizedBox(height: 12),
                  TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva Contraseña', prefixIcon: Icon(Icons.lock))),
                  const SizedBox(height: 12),
                  TextField(controller: _confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar Contraseña', prefixIcon: Icon(Icons.lock))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _changePassword,
                      child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Actualizar Contraseña'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _seccion(S.t(context, 'Contacto de emergencia', 'Emergency contact')),
          const SizedBox(height: 8),
          if (!_tieneEmergencia)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VaiaColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(VaiaRadius.md),
                border: Border.all(color: VaiaColors.danger.withOpacity(0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: VaiaColors.danger, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Es obligatorio registrar al menos un contacto de emergencia.', style: TextStyle(fontSize: 12.5, color: VaiaColors.danger, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(controller: _emNombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo *')),
                  const SizedBox(height: 12),
                  TextField(controller: _emTelCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono (10 dígitos) *', prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 12),
                  TextField(controller: _emCorreo1Ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico 1', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: _emCorreo2Ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico 2 (opcional)', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _guardandoEmergencia ? null : _guardarEmergencia,
                      icon: _guardandoEmergencia
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(S.t(context, 'Guardar contacto', 'Save contact')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _seccion(S.t(context, 'Dispositivos conectados', 'Connected devices')),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _cargandoSesiones
                  ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
                  : _sesiones.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No hay dispositivos registrados', style: TextStyle(color: VaiaColors.textSecondary)),
                        )
                      : Column(
                          children: _sesiones.map((s) {
                            final esActual = s['esactual'] == true || s['esactual']?.toString() == '1';
                            return ListTile(
                              leading: Icon(Icons.smartphone_rounded, color: esActual ? VaiaColors.primary : VaiaColors.textMuted),
                              title: Text((s['dispositivo'] ?? 'Dispositivo').toString(),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${s['sistemaoperativo'] ?? ''}\n${_fechaAcceso(s['ultimoacceso'])}',
                                  style: const TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary)),
                              isThreeLine: true,
                              trailing: esActual
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: VaiaColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                      child: const Text('Este dispositivo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: VaiaColors.primary)),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.logout_rounded, color: VaiaColors.danger, size: 20),
                                      onPressed: () => _cerrarDispositivo(s),
                                    ),
                            );
                          }).toList(),
                        ),
            ),
          ),
          const SizedBox(height: 20),
          _seccion(S.t(context, 'Permisos y privacidad', 'Permissions & privacy')),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: VaiaColors.primary),
              title: const Text('Ver permisos y politicas'),
              trailing: const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
              onTap: () => Navigator.pushNamed(context, '/permisos'),
            ),
          ),
          const SizedBox(height: 20),
          _seccion(S.t(context, 'Acerca de', 'About')),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: _cardShape,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.t(context, 'Versión', 'Version'), style: const TextStyle(fontSize: 14, color: VaiaColors.textPrimary)),
                  Text(AppInfo.versionCompleta, style: const TextStyle(fontSize: 14, color: VaiaColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static final ShapeBorder _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(VaiaRadius.md),
    side: const BorderSide(color: VaiaColors.border),
  );

  Widget _seccion(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: VaiaColors.primary, letterSpacing: 0.3),
      ),
    );
  }
}
