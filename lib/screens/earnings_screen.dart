import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<ProfileProvider>().loadCorte(auth.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    final c = profile.currentCorte;

    return Scaffold(
      appBar: AppBar(title: const Text('Ganancias')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Ganancia de la Semana', style: TextStyle(color: AppTheme.textMedium)),
                    const SizedBox(height: 8),
                    Text('\$${c?.totalGanancia?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (c != null) ...[
              _statRow('Viajes', '${c.totalViajes ?? 0}'),
              _statRow('Comisión', '\$${c.comision?.toStringAsFixed(2) ?? '0.00'}'),
              _statRow('Propinas', '\$${c.propinas?.toStringAsFixed(2) ?? '0.00'}'),
              _statRow('Monto a Transferir', '\$${c.montoTransferir?.toStringAsFixed(2) ?? '0.00'}'),
              _statRow('Transferido', c.transferido == true ? 'Sí' : 'No'),
              if (c.transferido == true && c.fechaTransferencia != null) _statRow('Fecha Transferencia', c.fechaTransferencia!),
              const SizedBox(height: 24),
              if (c.transferido != true)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: profile.loading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await profile.transferirCorte(auth.userId, c.id);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(ok ? 'Transferencia solicitada' : 'Error'), backgroundColor: ok ? AppTheme.accent : AppTheme.danger),
                              );
                            }
                          },
                    icon: const Icon(Icons.account_balance),
                    label: const Text('Solicitar Transferencia'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textMedium)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
