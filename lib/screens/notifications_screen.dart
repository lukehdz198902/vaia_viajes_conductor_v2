import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Bandeja de notificaciones del conductor con estado leido / no leido.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _filtro = 'todas';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    setState(() => _loading = true);
    final resp = await _api.notificaciones(auth.userId);
    if (!mounted) return;
    setState(() {
      _items = (resp.ok && resp.list != null)
          ? resp.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      _loading = false;
    });
  }

  bool _esLeido(Map<String, dynamic> n) =>
      n['leido'] == true || n['leido']?.toString() == '1' || n['leido']?.toString() == 'true';

  Future<void> _marcarLeida(Map<String, dynamic> n) async {
    if (_esLeido(n)) return;
    final auth = context.read<AuthProvider>();
    final id = int.tryParse(n['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    setState(() => n['leido'] = true);
    await _api.marcarNotificacionLeida(auth.userId, id);
  }

  Future<void> _marcarTodas() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      for (final n in _items) {
        n['leido'] = true;
      }
    });
    await _api.marcarNotificacionesLeidas(auth.userId);
  }

  @override
  Widget build(BuildContext context) {
    final noLeidas = _items.where((n) => !_esLeido(n)).length;
    final visibles = _filtro == 'noleidas' ? _items.where((n) => !_esLeido(n)).toList() : _items;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notificaciones'),
            if (noLeidas > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: VaiaColors.danger, borderRadius: BorderRadius.circular(20)),
                child: Text('$noLeidas', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        actions: [
          if (noLeidas > 0)
            TextButton.icon(
              onPressed: _marcarTodas,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Marcar leidas'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _chipFiltro('todas', 'Todas (${_items.length})'),
                const SizedBox(width: 8),
                _chipFiltro('noleidas', 'No leidas ($noLeidas)'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: VaiaColors.primary,
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visibles.isEmpty
                      ? _vacio()
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: visibles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _tarjeta(visibles[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(String valor, String texto) {
    final sel = _filtro == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtro = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? VaiaColors.primary : VaiaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? VaiaColors.primary : VaiaColors.border),
        ),
        child: Text(texto, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : VaiaColors.textSecondary)),
      ),
    );
  }

  Widget _vacio() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        const Icon(Icons.notifications_none_rounded, size: 72, color: VaiaColors.textMuted),
        const SizedBox(height: 12),
        const Center(child: Text('Sin notificaciones', style: TextStyle(color: VaiaColors.textSecondary))),
      ],
    );
  }

  Widget _tarjeta(Map<String, dynamic> n) {
    final leido = _esLeido(n);
    final tipo = n['tipo']?.toString() ?? '';
    final (icon, color) = _iconoTipo(tipo);
    return InkWell(
      onTap: () => _marcarLeida(n),
      borderRadius: BorderRadius.circular(VaiaRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: leido ? VaiaColors.surface : VaiaColors.primaryGhost,
          borderRadius: BorderRadius.circular(VaiaRadius.lg),
          border: Border.all(color: leido ? VaiaColors.border : VaiaColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n['titulo']?.toString() ?? 'Notificacion',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: leido ? FontWeight.w600 : FontWeight.w800,
                              color: VaiaColors.textPrimary,
                            )),
                      ),
                      if (!leido)
                        Container(width: 9, height: 9, decoration: const BoxDecoration(color: VaiaColors.primary, shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(n['mensaje']?.toString() ?? '', style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
                  const SizedBox(height: 5),
                  Text(_fecha(n['fechacreacion']), style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconoTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'documento':
        return (Icons.description_rounded, VaiaColors.info);
      case 'unidad':
        return (Icons.directions_car_rounded, VaiaColors.primary);
      case 'servicio':
        return (Icons.route_rounded, VaiaColors.success);
      case 'promocion':
        return (Icons.local_offer_rounded, VaiaColors.accent);
      case 'pago':
        return (Icons.payments_rounded, VaiaColors.success);
      case 'aviso':
        return (Icons.campaign_rounded, VaiaColors.warning);
      default:
        return (Icons.notifications_rounded, VaiaColors.primary);
    }
  }

  String _fecha(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
