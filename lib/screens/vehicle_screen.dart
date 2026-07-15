import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});
  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<ProfileProvider>().loadUnidades(auth.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Vehículos')),
      body: profile.loading
          ? const Center(child: CircularProgressIndicator())
          : profile.unidades.isEmpty
              ? const Center(child: Text('No hay vehículos registrados'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: profile.unidades.length,
                  itemBuilder: (_, i) {
                    final u = profile.unidades[i];
                    final isSelected = u.enUso == true;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: isSelected ? AppTheme.accent : AppTheme.textLight, child: const Icon(Icons.directions_car, color: Colors.white)),
                        title: Text(u.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.accent : AppTheme.textDark)),
                        subtitle: Text('${u.anio ?? ""} ${u.color ?? ""}'.trim()),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.accent) : null,
                        onTap: isSelected ? null : () => _selectVehicle(context, u.id),
                      ),
                    );
                  },
                ),
    );
  }

  void _selectVehicle(BuildContext context, int unidadId) async {
    final auth = context.read<AuthProvider>();
    final ok = await context.read<ProfileProvider>().selectUnidad(auth.userId, unidadId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Vehículo seleccionado' : 'Error al seleccionar'), backgroundColor: ok ? AppTheme.accent : AppTheme.danger),
      );
    }
  }
}
