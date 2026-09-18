import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import 'report_incident_screen.dart';

class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});
  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  final _codeCtrl = TextEditingController();
  bool _showCodeInput = false;
  bool _isStarting = false;
  bool _isLlegando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<RideProvider>().activeRide;
      if (s != null) context.read<RideProvider>().listarParadas(s.id);
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final auth = context.watch<AuthProvider>();
    final s = ride.activeRide;
    final estatus = s?.servicioEstatus ?? '';
    final isEnCamino = estatus == 'En Camino' || estatus.isEmpty;
    final isLlegoOrigen = estatus == 'Llego al Origen';
    final isEnViaje = estatus == 'En Viaje';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnViaje ? 'En Viaje' : 'En Camino'),
        automaticallyImplyLeading: false,
      ),
      body: s == null
          ? const Center(child: Text('Viaje finalizado'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: AppTheme.primary, radius: 25, child: Text(s.pasajeroNombre?.isNotEmpty == true ? s.pasajeroNombre![0] : '?', style: const TextStyle(color: Colors.white))),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.pasajeroNombre ?? 'Pasajero', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(s.pasajeroTelefono ?? '', style: const TextStyle(color: AppTheme.textMedium)),
                          ])),
                          IconButton(icon: const Icon(Icons.phone, color: AppTheme.primary), onPressed: s.pasajeroTelefono != null ? () => _callPasajero(s.pasajeroTelefono!) : null),
                          IconButton(icon: const Icon(Icons.chat, color: AppTheme.primary), onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'servicioId': s.id, 'pasajero': s.pasajeroNombre ?? 'Pasajero'})),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _stepRow(Icons.my_location, 'Origen', s.direccionOrigen ?? '', isEnCamino),
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Divider(height: 30, thickness: 2),
                          ),
                          _stepRow(Icons.location_on, 'Destino', s.direccionDestino ?? '', isEnViaje),
                        ],
                      ),
                    ),
                  ),
                  if (ride.paradas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildParadasCard(ride),
                  ],
                  if (isEnCamino) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLlegando
                            ? null
                            : () async {
                                setState(() => _isLlegando = true);
                                final ok = await ride.llegarAlOrigen(s.id, auth.userId);
                                if (!mounted) return;
                                setState(() => _isLlegando = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(ok ? 'Llegada registrada' : (ride.error ?? 'Error al registrar llegada')),
                                  backgroundColor: ok ? AppTheme.accent : AppTheme.danger,
                                ));
                              },
                        icon: _isLlegando
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.place_outlined),
                        label: const Text('Llegue al origen'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ],
                  if (_showCodeInput) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Codigo de inicio',
                              hintText: 'Ingresa el codigo del pasajero (000000 en pruebas)',
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _startTrip(ride, s.id, auth.userId),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isStarting ? null : () => _startTrip(ride, s.id, auth.userId),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: _isStarting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Iniciar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Usa 000000 como codigo de prueba', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  ],
                  const Spacer(),
                  if (isLlegoOrigen && !_showCodeInput)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _showCodeInput = true),
                        icon: const Icon(Icons.vpn_key_outlined),
                        label: const Text('Ingresar codigo de inicio'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  if (isEnViaje) ...[
                    // Taximetro en vivo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          const Text('Cobro hasta el momento',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                          const SizedBox(height: 4),
                          Text(
                            '\$${(ride.costoEnCurso ?? s.costoEstimado ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _cobrarYFinalizar(ride, s.id, auth.userId, ride.costoEnCurso ?? s.costoEstimado),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Finalizar y cobrar'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportIncidentScreen(idServicio: s.id),
                              ),
                            );
                          },
                          icon: Icon(Icons.report_problem_outlined, size: 18, color: AppTheme.textMedium),
                          label: Text('Incidente', style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/support_chat',
                                arguments: {'idServicio': s.id});
                          },
                          icon: const Icon(Icons.support_agent_rounded, size: 18, color: AppTheme.primary),
                          label: const Text('Soporte', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _startTrip(RideProvider ride, int servicioId, int conductorId) async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _isStarting = true);
    final ok = await ride.startTrip(servicioId, conductorId, code);
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (ok) {
      setState(() => _showCodeInput = false);
      _codeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje iniciado'), backgroundColor: AppTheme.accent),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ride.error ?? 'Codigo incorrecto'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _callPasajero(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede realizar la llamada'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Widget _buildParadasCard(RideProvider ride) {
    final paradas = ride.paradas;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route, size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Text(
                  'Paradas (${paradas.where((p) => p.completada).length}/${paradas.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.orange.shade900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...paradas.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        p.completada ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: p.completada ? AppTheme.accent : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.orden}. ${p.direccion}',
                              style: TextStyle(
                                fontSize: 13,
                                decoration: p.completada ? TextDecoration.lineThrough : null,
                                color: p.completada ? AppTheme.textLight : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!p.completada)
                        TextButton(
                          onPressed: () async {
                            final ok = await ride.completarParada(p.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok ? 'Parada completada' : 'No se pudo completar'),
                              backgroundColor: ok ? AppTheme.accent : AppTheme.danger,
                            ));
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Llegue', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// Cobro en efectivo: el conductor ingresa el monto recibido y se finaliza el viaje.
  Future<void> _cobrarYFinalizar(RideProvider ride, int servicioId, int conductorId, double? sugerido) async {
    final controller = TextEditingController(
      text: sugerido != null ? sugerido.toStringAsFixed(2) : '',
    );
    final monto = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Cobrar servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sugerido != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Total del taximetro: \$${sugerido.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto recibido (efectivo)',
                prefixText: '\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Confirmar cobro'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (monto == null) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ride.finishTrip(servicioId, conductorId, costoFinal: monto);
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(ride.error ?? 'Error al finalizar'), backgroundColor: AppTheme.danger));
      return;
    }
    await ride.registrarPago(servicioId, conductorId, monto, metodo: 'CASH');
    if (!mounted) return;
    navigator.pushReplacementNamed('/rating', arguments: {'servicioId': servicioId});
  }

  Widget _stepRow(IconData icon, String label, String address, bool active) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: active ? AppTheme.primary : AppTheme.textLight, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: active ? AppTheme.primary : AppTheme.textLight, fontWeight: FontWeight.w600)),
          Text(address, style: const TextStyle(color: AppTheme.textDark)),
        ])),
      ],
    );
  }
}
