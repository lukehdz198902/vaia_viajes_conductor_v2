import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/network_usage_service.dart';

class ConnectionActivityScreen extends StatefulWidget {
  const ConnectionActivityScreen({super.key});

  @override
  State<ConnectionActivityScreen> createState() => _ConnectionActivityScreenState();
}

class _ConnectionActivityScreenState extends State<ConnectionActivityScreen> {
  final ApiService _api = ApiService();
  int _dias = 7;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    setState(() { _loading = true; _error = null; });
    final r = await _api.historialConexion(auth.userId, dias: _dias);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : (r.error ?? 'No se pudo cargar la actividad');
      _rows = (r.list ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  String _fmtMin(double min) {
    final m = min.round();
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final daily = <String, double>{};
    final hourly = <int, double>{};
    for (final r in _rows) {
      final dia = (r['dia'] ?? '').toString().split('T').first;
      final hora = int.tryParse((r['hora'] ?? '0').toString()) ?? 0;
      final min = double.tryParse((r['minutos'] ?? '0').toString()) ?? 0;
      if (dia.isEmpty) continue;
      daily[dia] = (daily[dia] ?? 0) + min;
      hourly[hora] = (hourly[hora] ?? 0) + min;
    }
    final days = daily.keys.toList()..sort();
    final total = daily.values.fold<double>(0, (a, b) => a + b);
    final avg = days.isEmpty ? 0.0 : total / days.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad y datos'),
        actions: [IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Tiempo conectado',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                ),
                ChoiceChip(
                  label: const Text('7 dias', style: TextStyle(fontSize: 11)),
                  selected: _dias == 7,
                  onSelected: (_) { setState(() => _dias = 7); _cargar(); },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('30 dias', style: TextStyle(fontSize: 11)),
                  selected: _dias == 30,
                  onSelected: (_) { setState(() => _dias = 30); _cargar(); },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _messageCard(_error!)
            else ...[
              Row(
                children: [
                  Expanded(child: _stat('Total', _fmtMin(total), Icons.timer_outlined, VaiaColors.accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('Promedio/dia', _fmtMin(avg), Icons.show_chart_rounded, VaiaColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('Dias', '${days.length}', Icons.calendar_month_rounded, VaiaColors.info)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VaiaColors.surface,
                  borderRadius: BorderRadius.circular(VaiaRadius.lg),
                  border: Border.all(color: VaiaColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: VaiaColors.info.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.data_usage_rounded, color: VaiaColors.info, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Consumo aproximado de datos',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Hoy: ${NetworkUsageService.todayMB.toStringAsFixed(2)} MB  ·  Total: ${NetworkUsageService.totalMB.toStringAsFixed(2)} MB',
                            style: const TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Calculado con el trafico HTTP de la app. No incluye WebSocket ni datos del sistema.',
                            style: TextStyle(fontSize: 10, color: VaiaColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _chartCard(
                'Minutos por dia',
                _BarChart(
                  values: days.map((d) => daily[d] ?? 0).toList(),
                  labels: days.map((d) => d.substring(5).split('-').reversed.join('/')).toList(),
                  color: VaiaColors.accent,
                ),
              ),
              const SizedBox(height: 10),
              _chartCard(
                'Distribucion por hora',
                _BarChart(
                  values: List.generate(24, (h) => hourly[h] ?? 0),
                  labels: List.generate(24, (h) => h % 3 == 0 ? '$h' : ''),
                  color: VaiaColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VaiaColors.surface,
                  borderRadius: BorderRadius.circular(VaiaRadius.lg),
                  border: Border.all(color: VaiaColors.border),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 16, color: VaiaColors.accent),
                        SizedBox(width: 6),
                        Text('Detalle por dia', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: VaiaColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...days.reversed.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(d, style: const TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary))),
                          Text(_fmtMin(daily[d] ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: VaiaColors.textMuted)),
        ],
      ),
    );
  }

  Widget _messageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Text(message, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12)),
    );
  }

  Widget _chartCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: VaiaColors.textPrimary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;

  const _BarChart({required this.values, required this.labels, required this.color});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0.01, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 145,
      child: LayoutBuilder(builder: (context, box) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(values.length, (i) {
            final factor = (values[i] / max).clamp(0.02, 1.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: factor,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: values[i] > 0 ? .85 : .12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (i < labels.length && labels[i].isNotEmpty)
                      Text(labels[i], style: const TextStyle(fontSize: 8, color: VaiaColors.textMuted), maxLines: 1)
                    else
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
