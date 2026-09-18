import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/unidad_model.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});
  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<ProfileProvider>().loadUnidades(auth.userId);
    }
  }

  Future<void> _nuevaUnidad() async {
    final marca = TextEditingController();
    final modelo = TextEditingController();
    final anio = TextEditingController();
    final color = TextEditingController();
    final placas = TextEditingController();
    final asientos = TextEditingController(text: '4');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar unidad'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: marca, decoration: const InputDecoration(labelText: 'Marca'), validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              TextFormField(controller: modelo, decoration: const InputDecoration(labelText: 'Modelo'), validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              TextFormField(controller: anio, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Anio')),
              TextFormField(controller: color, decoration: const InputDecoration(labelText: 'Color')),
              TextFormField(controller: placas, decoration: const InputDecoration(labelText: 'Placas'), validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              TextFormField(controller: asientos, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Asientos')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) {
      marca.dispose(); modelo.dispose(); anio.dispose(); color.dispose(); placas.dispose(); asientos.dispose();
      return;
    }

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final r = await _api.agregarUnidad({
      'idConductor': auth.userId,
      'marca': marca.text.trim(),
      'modelo': modelo.text.trim(),
      'anio': int.tryParse(anio.text.trim()) ?? 0,
      'color': color.text.trim(),
      'placas': placas.text.trim().toUpperCase(),
      'asientos': int.tryParse(asientos.text.trim()) ?? 4,
    });
    marca.dispose(); modelo.dispose(); anio.dispose(); color.dispose(); placas.dispose(); asientos.dispose();

    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(r.ok ? 'Unidad registrada, pendiente de aprobacion' : (r.mensaje.isNotEmpty ? r.mensaje : 'No se pudo registrar')),
      backgroundColor: r.ok ? VaiaColors.success : VaiaColors.danger,
    ));
    if (r.ok) context.read<ProfileProvider>().loadUnidades(auth.userId);
  }

  Future<void> _seleccionar(Unidad u) async {
    final ride = context.read<RideProvider>();
    if (ride.activeRide != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes cambiar de unidad con un servicio activo'), backgroundColor: VaiaColors.warning),
      );
      return;
    }
    if (u.aprobada != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La unidad aun no ha sido aprobada'), backgroundColor: VaiaColors.warning),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<ProfileProvider>().selectUnidad(auth.userId, u.id);
    if (mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'Unidad seleccionada' : 'Error al seleccionar'),
        backgroundColor: ok ? VaiaColors.success : VaiaColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis unidades')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaUnidad,
        icon: const Icon(Icons.add),
        label: const Text('Nueva unidad'),
      ),
      body: profile.loading
          ? const Center(child: CircularProgressIndicator())
          : profile.unidades.isEmpty
              ? const Center(child: Text('No hay unidades registradas'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: profile.unidades.length,
                  itemBuilder: (_, i) {
                    final u = profile.unidades[i];
                    return _unidadCard(u);
                  },
                ),
    );
  }

  Widget _unidadCard(Unidad u) {
    final isSelected = u.enUso == true;
    final aprobada = u.aprobada == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: aprobada ? (isSelected ? VaiaColors.success : VaiaColors.primary) : VaiaColors.textSecondary,
                  child: const Icon(Icons.directions_car, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${u.anio ?? ''} ${u.color ?? ''}'.trim(), style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 13)),
                  ]),
                ),
                _badge(aprobada, isSelected),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/vehicle_documents', arguments: {'idunidad': u.id}),
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('Documentos'),
                ),
                const Spacer(),
                if (!isSelected)
                  TextButton.icon(
                    onPressed: aprobada ? () => _seleccionar(u) : null,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Usar esta'),
                  )
                else
                  const Row(children: [
                    Icon(Icons.check_circle, color: VaiaColors.success, size: 18),
                    SizedBox(width: 4),
                    Text('En uso', style: TextStyle(color: VaiaColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(bool aprobada, bool enUso) {
    final texto = !aprobada ? 'Pendiente' : (enUso ? 'En uso' : 'Aprobada');
    final color = !aprobada ? VaiaColors.warning : VaiaColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
