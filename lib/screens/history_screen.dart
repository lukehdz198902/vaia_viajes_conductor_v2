import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<RideProvider>().loadHistory(auth.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Viajes')),
      body: ride.loading
          ? const Center(child: CircularProgressIndicator())
          : ride.history.isEmpty
              ? const Center(child: Text('No hay viajes realizados'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ride.history.length,
                  itemBuilder: (_, i) {
                    final v = ride.history[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.route, color: Colors.white)),
                        title: Text(v.direccionOrigen ?? 'Origen', style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(v.fechaCreacion ?? ''),
                        trailing: v.costoEstimado != null ? Text('\$${v.costoEstimado!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)) : null,
                        onTap: () => Navigator.pushNamed(context, '/trip_detail', arguments: {'servicioId': v.id}),
                      ),
                    );
                  },
                ),
    );
  }
}
