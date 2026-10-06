import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/api_service.dart';

/// Ganancias del conductor por semana (lunes a viernes).
///
/// Permite elegir cualquier semana por año, ver el total ganado, el desglose
/// por tipo de pago (efectivo, tarjeta, etc.) y el listado de servicios del
/// periodo. Por defecto carga la semana actual en curso.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _api = ApiService();
  late int _anio;
  late int _semana;
  bool _cargando = true;
  Map<String, dynamic>? _resumen;
  List<Map<String, dynamic>> _porPago = [];
  List<Map<String, dynamic>> _servicios = [];

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _anio = hoy.year;
    _semana = _isoWeek(hoy);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) context.read<ProfileProvider>().loadCorte(auth.userId);
    });
  }

  // ─── Semana ISO ───────────────────────────────────────────────

  /// Numero de semana ISO-8601 (1..53). Implementacion iterativa basada en el
  /// jueves de la semana, sin recursion (la version anterior podia entrar en
  /// recursion infinita y provocaba un stack overflow al abrir la pantalla).
  int _isoWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // Jueves de la semana ISO: lunes=1 ... domingo=7.
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    // Jueves de la primera semana ISO del anio.
    final firstThursday = jan1.add(Duration(days: (4 - jan1.weekday + 7) % 7));
    return 1 + thursday.difference(firstThursday).inDays ~/ 7;
  }

  DateTime _lunes(int year, int week) {
    final jan4 = DateTime(year, 1, 4);
    final monday1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    return monday1.add(Duration(days: (week - 1) * 7));
  }

  int _semanasDelAnio(int year) => _isoWeek(DateTime(year, 12, 28));

  (DateTime, DateTime) get _rango {
    final lun = _lunes(_anio, _semana);
    final fi = DateTime(lun.year, lun.month, lun.day, 0, 0, 0);
    final ff = DateTime(lun.year, lun.month, lun.day + 4, 23, 59, 59); // viernes
    return (fi, ff);
  }

  String get _etiquetaRango {
    final lun = _lunes(_anio, _semana);
    final vie = DateTime(lun.year, lun.month, lun.day + 4);
    String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${f(lun)} - ${f(vie)}';
  }

  Future<void> _cargar() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    setState(() => _cargando = true);
    final (fi, ff) = _rango;
    try {
      final r1 = await _api.gananciasResumen(auth.userId, fi: fi, ff: ff);
      final r2 = await _api.gananciasPorPago(auth.userId, fi: fi, ff: ff);
      final r3 = await _api.gananciasServicios(auth.userId, fi: fi, ff: ff);
      if (!mounted) return;
      setState(() {
        _resumen = (r1.ok && r1.data != null) ? r1.data : null;
        _porPago = (r2.ok && r2.list != null)
            ? r2.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _servicios = (r3.ok && r3.list != null)
            ? r3.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String _money(dynamic v) => '\$${_d(v).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    final c = profile.currentCorte;

    return Scaffold(
      appBar: AppBar(title: const Text('Ganancias')),
      body: RefreshIndicator(
        color: VaiaColors.primary,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _selectorSemana(),
            const SizedBox(height: 14),
            _tarjetaTotal(),
            const SizedBox(height: 14),
            _seccion('Desglose diario (lunes a viernes)', _desgloseDiario()),
            const SizedBox(height: 14),
            _seccion('Desglose por tipo de pago', _listaPorPago()),
            const SizedBox(height: 14),
            _seccion('Servicios de la semana (${_servicios.length})', _listaServicios()),
            const SizedBox(height: 14),
            _corteSemanal(c, profile, auth),
          ],
        ),
      ),
    );
  }

  Widget _selectorSemana() {
    final anios = List<int>.generate(DateTime.now().year - 2022, (i) => DateTime.now().year - i);
    final semanas = List<int>.generate(_semanasDelAnio(_anio), (i) => i + 1);
    final semanaActual = _isoWeek(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_view_week_rounded, size: 18, color: VaiaColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: _dropdown<int>(value: _semana, items: {
                for (final s in semanas) s: 'Semana $s'
              }, onChanged: (v) { setState(() => _semana = v!); _cargar(); })),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: _dropdown<int>(value: _anio, items: {
                for (final a in anios) a: '$a'
              }, onChanged: (v) {
                setState(() {
                  _anio = v!;
                  final max = _semanasDelAnio(_anio);
                  if (_semana > max) _semana = max;
                });
                _cargar();
              })),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(_etiquetaRango, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: VaiaColors.textSecondary)),
              const Spacer(),
              if (_anio != DateTime.now().year || _semana != semanaActual)
                TextButton.icon(
                  onPressed: () {
                    setState(() { _anio = DateTime.now().year; _semana = semanaActual; });
                    _cargar();
                  },
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text('Semana actual'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({required T value, required Map<T, String> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VaiaColors.bgSubtle,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        border: Border.all(color: VaiaColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary),
          items: items.entries.map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _tarjetaTotal() {
    final r = _resumen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VaiaColors.primaryGradient,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        boxShadow: [BoxShadow(color: VaiaColors.primary.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Text('GANANCIA NETA DE LA SEMANA',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(_money(r?['ganancia']),
              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniKpi('${r?['viajes'] ?? 0}', 'Viajes'),
              _miniKpi(_money(r?['cobrado']), 'Cobrado'),
              _miniKpi(_money(r?['comision']), 'Comision'),
              _miniKpi('${_d(r?['km']).toStringAsFixed(1)} km', 'Recorrido'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniKpi(String valor, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, Widget hijo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
          const SizedBox(height: 10),
          hijo,
        ],
      ),
    );
  }

  DateTime? _parseFecha(dynamic iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Ganancias netas por dia de la semana (indice 0 = lunes ... 4 = viernes).
  List<double> _porDia() {
    final tot = List<double>.filled(5, 0);
    for (final s in _servicios) {
      final d = _parseFecha(s['fechacreacion']);
      if (d == null) continue;
      final idx = d.weekday - 1;
      if (idx >= 0 && idx < 5) tot[idx] += _d(s['gananciaconductor']);
    }
    return tot;
  }

  Widget _desgloseDiario() {
    if (_cargando) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    final dias = ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes'];
    final valores = _porDia();
    final maxV = valores.fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: List.generate(5, (i) {
        final v = valores[i];
        final frac = maxV > 0 ? (v / maxV) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(dias[i],
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: VaiaColors.textSecondary)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 10,
                    backgroundColor: VaiaColors.bgSubtle,
                    valueColor: const AlwaysStoppedAnimation<Color>(VaiaColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                child: Text(_money(v),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _listaPorPago() {
    if (_cargando) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    if (_porPago.isEmpty) {
      return const Text('Sin cobros en esta semana', style: TextStyle(fontSize: 12.5, color: VaiaColors.textMuted));
    }
    return Column(
      children: _porPago.map((p) {
        final tipo = p['tipopago']?.toString() ?? 'Sin definir';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(10)),
                child: Icon(_iconPago(tipo), size: 18, color: VaiaColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tipo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                    Text('${p['viajes'] ?? 0} viaje(s) - cobrado ${_money(p['cobrado'])}',
                        style: const TextStyle(fontSize: 11.5, color: VaiaColors.textMuted)),
                  ],
                ),
              ),
              Text(_money(p['ganancia']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: VaiaColors.success)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _listaServicios() {
    if (_cargando) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    if (_servicios.isEmpty) {
      return const Text('Sin servicios en esta semana', style: TextStyle(fontSize: 12.5, color: VaiaColors.textMuted));
    }
    return Column(
      children: _servicios.map((s) {
        final nombre = [s['p_nombre'], s['p_appaterno']].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ').trim();
        final foto = s['p_foto']?.toString();
        return InkWell(
          onTap: () => Navigator.pushNamed(context, '/trip_detail', arguments: {'servicioId': int.tryParse(s['id']?.toString() ?? '') ?? 0}),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: VaiaColors.primaryGhost,
                  backgroundImage: (foto != null && foto.isNotEmpty) ? NetworkImage(foto) : null,
                  child: (foto == null || foto.isEmpty)
                      ? Text((nombre.isEmpty ? 'P' : nombre.substring(0, 1)).toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: VaiaColors.primary))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre.isEmpty ? 'Pasajero' : nombre,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      Text('${_fecha(s['fechacreacion'])} - ${s['tipopago'] ?? 'Sin definir'}',
                          style: const TextStyle(fontSize: 11, color: VaiaColors.textMuted), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_money(s['cobrado'] ?? s['costofinal']), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: VaiaColors.textPrimary)),
                    Text(_money(s['gananciaconductor']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VaiaColors.success)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _corteSemanal(dynamic c, ProfileProvider profile, AuthProvider auth) {
    if (c == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Corte semanal', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
          const SizedBox(height: 10),
          _fila('Total ganado', _money(c.totalGanancia)),
          _fila('Comision', _money(c.comision)),
          _fila('Propinas', _money(c.propinas)),
          _fila('Monto a transferir', _money(c.montoTransferir)),
          _fila('Transferido', c.transferido == true ? 'Si' : 'No'),
          if (c.transferido != true) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: profile.loading ? null : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await profile.transferirCorte(auth.userId, c.id);
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(
                      content: Text(ok ? 'Transferencia solicitada' : 'Error al solicitar'),
                      backgroundColor: ok ? VaiaColors.success : VaiaColors.danger,
                    ));
                  }
                },
                icon: const Icon(Icons.account_balance_rounded, size: 18),
                label: const Text('Solicitar transferencia'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
        ],
      ),
    );
  }

  IconData _iconPago(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('efectivo')) return Icons.payments_rounded;
    if (t.contains('credito') || t.contains('debito') || t.contains('tarjeta')) return Icons.credit_card_rounded;
    if (t.contains('paypal') || t.contains('mercado')) return Icons.account_balance_wallet_rounded;
    if (t.contains('transfer')) return Icons.account_balance_rounded;
    return Icons.payments_rounded;
  }

  String _fecha(dynamic iso) {
    if (iso == null) return '--';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--';
    }
  }
}
