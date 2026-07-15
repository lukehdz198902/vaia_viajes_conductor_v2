import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreCtrl = TextEditingController();
  final _appCtrl = TextEditingController();
  final _apmCtrl = TextEditingController();
  final _correoCtr = TextEditingController();
  final _telCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = context.read<AuthProvider>().conductor;
    if (c != null) {
      _nombreCtrl.text = c.nombre;
      _appCtrl.text = c.appaterno;
      _apmCtrl.text = c.apmaterno;
      _correoCtr.text = c.correo;
      _telCtrl.text = c.telefono;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _appCtrl.dispose();
    _apmCtrl.dispose();
    _correoCtr.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final c = auth.conductor;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(radius: 50, backgroundColor: AppTheme.primary, child: Text(c?.nombre.isNotEmpty == true ? c!.nombre[0] : '?', style: const TextStyle(fontSize: 36, color: Colors.white))),
            const SizedBox(height: 8),
            Text(c?.nombreCompleto ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(c?.correo ?? '', style: const TextStyle(color: AppTheme.textMedium)),
            const SizedBox(height: 24),
            _infoTile('Calificación', c?.calificacionPromedio?.toStringAsFixed(1) ?? 'N/A'),
            _infoTile('Viajes', c?.totalViajes?.toString() ?? '0'),
            _infoTile('Estatus', c?.conductorEstatus ?? 'N/A'),
            _infoTile('Documentación', c?.documentacionAprobada == true ? 'Aprobada' : 'Pendiente'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/vehicle'),
                icon: const Icon(Icons.directions_car),
                label: const Text('Mis Vehículos'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cambiar Contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textMedium)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
