import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/servicio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Servicio? _servicio;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final servicioId = args?['servicioId'] as int?;
    if (servicioId == null) return;
    final auth = context.read<AuthProvider>();
    final s = await context.read<RideProvider>().getDetail(servicioId, auth.userId);
    if (mounted) {
      setState(() { _servicio = s; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Viaje')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _servicio == null
              ? const Center(child: Text('No se pudo cargar el detalle'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _row('Origen', _servicio!.direccionOrigen ?? ''),
                              const Divider(),
                              _row('Destino', _servicio!.direccionDestino ?? ''),
                              const Divider(),
                              if (_servicio!.costoEstimado != null) _row('Costo Estimado', '\$${_servicio!.costoEstimado!.toStringAsFixed(2)}'),
                              if (_servicio!.costoFinal != null) _row('Costo Final', '\$${_servicio!.costoFinal!.toStringAsFixed(2)}'),
                              if (_servicio!.distanciaMetros != null) _row('Distancia', '${(_servicio!.distanciaMetros! / 1000).toStringAsFixed(1)} km'),
                              if (_servicio!.fechaCreacion != null) _row('Fecha', _servicio!.fechaCreacion!),
                              if (_servicio!.calificacion != null) _row('Calificación', '${_servicio!.calificacion} / 5'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textMedium)),
        Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ]),
    );
  }
}
