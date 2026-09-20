import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/unidad_model.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../widgets/vaia_widgets.dart';

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
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UnidadFormSheet(),
    );
    if (data == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final r = await _api.agregarUnidad({'idConductor': auth.userId, ...data});
    if (!mounted) return;

    if (!r.ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(r.mensaje.isNotEmpty ? r.mensaje : 'No se pudo registrar la unidad'),
        backgroundColor: VaiaColors.danger,
      ));
      return;
    }

    final idUnidad = r.id;
    await context.read<ProfileProvider>().loadUnidades(auth.userId);
    if (!mounted) return;

    messenger.showSnackBar(const SnackBar(
      content: Text('Unidad registrada. Pendiente de aprobacion.'),
      backgroundColor: VaiaColors.success,
    ));

    // Ofrecer subir la documentacion de la unidad recien creada
    if (idUnidad > 0) {
      final subir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
          icon: const Icon(Icons.folder_shared_outlined, color: VaiaColors.primary, size: 36),
          title: const Text('Documentos de la unidad'),
          content: const Text('Tu unidad necesita documentos para poder ser aprobada. ¿Deseas subirlos ahora?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mas tarde')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Subir ahora'),
            ),
          ],
        ),
      );
      if (subir == true && mounted) {
        Navigator.pushNamed(context, '/vehicle_documents', arguments: {'idunidad': idUnidad});
      }
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaUnidad,
        tooltip: 'Nueva unidad',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: profile.loading
          ? const Center(child: CircularProgressIndicator())
          : profile.unidades.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: profile.unidades.length,
                  itemBuilder: (_, i) => _unidadCard(profile.unidades[i]),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.directions_car_filled_rounded, size: 56, color: VaiaColors.primary),
            ),
            const SizedBox(height: 18),
            Text('Aun no tienes unidades', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Registra tu vehiculo con el boton + para poder empezar a laborar.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _unidadCard(Unidad u) {
    final isSelected = u.enUso == true;
    final aprobada = u.aprobada == true;
    final color = aprobada ? VaiaColors.success : VaiaColors.warning;
    final estado = aprobada ? (isSelected ? 'En uso' : 'Aprobada') : 'Pendiente de aprobacion';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: isSelected ? VaiaColors.primary : VaiaColors.border, width: isSelected ? 1.6 : 1),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: aprobada ? VaiaColors.primaryGradient : null,
                    color: aprobada ? null : VaiaColors.bgMuted,
                    borderRadius: BorderRadius.circular(VaiaRadius.md),
                  ),
                  child: Icon(Icons.directions_car_filled_rounded, color: aprobada ? Colors.white : VaiaColors.textMuted, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        [u.anio?.toString(), u.color].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                VaiaBadge(label: estado, color: color, icon: aprobada ? Icons.verified_rounded : Icons.hourglass_top_rounded),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/vehicle_documents', arguments: {'idunidad': u.id}),
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('Documentos'),
                ),
                const Spacer(),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, color: VaiaColors.success, size: 18),
                      SizedBox(width: 5),
                      Text('En uso', style: TextStyle(color: VaiaColors.success, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  )
                else
                  TextButton.icon(
                    onPressed: aprobada ? () => _seleccionar(u) : null,
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: const Text('Usar esta'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulario modal para registrar una unidad. Orden: placas, marca/modelo,
/// anio, color/pasajeros.
class _UnidadFormSheet extends StatefulWidget {
  const _UnidadFormSheet();
  @override
  State<_UnidadFormSheet> createState() => _UnidadFormSheetState();
}

class _UnidadFormSheetState extends State<_UnidadFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _placas = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _color = TextEditingController();
  final _asientos = TextEditingController(text: '4');

  @override
  void dispose() {
    _placas.dispose();
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _color.dispose();
    _asientos.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'placas': _placas.text.trim().toUpperCase(),
      'marca': _marca.text.trim(),
      'modelo': _modelo.text.trim(),
      'anio': int.tryParse(_anio.text.trim()) ?? 0,
      'color': _color.text.trim(),
      'asientos': int.tryParse(_asientos.text.trim()) ?? 4,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: VaiaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44, height: 5,
                      decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _header(),
                  const SizedBox(height: 20),
                  _sectionLabel('Identificacion', Icons.confirmation_number_outlined),
                  const SizedBox(height: 10),
                  VaiaTextField(
                    controller: _placas,
                    label: 'Placas',
                    hint: 'Ej. ABC1234',
                    prefixIcon: Icons.confirmation_number_outlined,
                    textInputAction: TextInputAction.next,
                    maxLength: 10,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Vehiculo', Icons.directions_car_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: VaiaTextField(
                        controller: _marca,
                        label: 'Marca',
                        hint: 'Nissan',
                        prefixIcon: Icons.factory_outlined,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: VaiaTextField(
                        controller: _modelo,
                        label: 'Modelo',
                        hint: 'Versa',
                        prefixIcon: Icons.directions_car_filled_outlined,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _sectionLabel('Detalles', Icons.tune_rounded),
                  const SizedBox(height: 10),
                  VaiaTextField(
                    controller: _anio,
                    label: 'Anio',
                    hint: '2020',
                    prefixIcon: Icons.calendar_month_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1980 || n > DateTime.now().year + 1) return 'Anio invalido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: VaiaTextField(
                        controller: _color,
                        label: 'Color',
                        hint: 'Blanco',
                        prefixIcon: Icons.palette_outlined,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: VaiaTextField(
                        controller: _asientos,
                        label: 'Pasajeros',
                        hint: '4',
                        prefixIcon: Icons.airline_seat_recline_extra_outlined,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _guardar(),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 1 || n > 12) return '1 a 12';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VaiaColors.primaryGhost,
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: VaiaColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Al registrarla podras subir sus documentos para que sea aprobada.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VaiaColors.textSecondary),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  VaiaPrimaryButton(
                    label: 'Registrar unidad',
                    icon: Icons.check_rounded,
                    onPressed: _guardar,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: VaiaColors.primaryGradient, borderRadius: BorderRadius.circular(VaiaRadius.md)),
          child: const Icon(Icons.add_road_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registrar unidad', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 3),
              Text(
                'Completa los datos de tu vehiculo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VaiaColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(VaiaRadius.sm)),
        child: Icon(icon, size: 15, color: VaiaColors.primary),
      ),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.3)),
    ]);
  }
}
