import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/notificacion_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Notificacion> _notifications = [];
  List<Aviso> _avisos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final api = ApiService();
    final notifResp = await api.obtenerNotificaciones(auth.userId);
    final avisosResp = await api.obtenerAvisos();
    if (mounted) {
      setState(() {
        if (notifResp.ok && notifResp.list != null) _notifications = notifResp.list!.map((e) => Notificacion.fromJson(e)).toList();
        if (avisosResp.ok && avisosResp.list != null) _avisos = avisosResp.list!.map((e) => Aviso.fromJson(e)).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones y Avisos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_avisos.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ..._avisos.map((a) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: AppTheme.secondary, child: Icon(Icons.campaign, color: Colors.white)),
                          title: Text(a.titulo ?? 'Aviso', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(a.contenido ?? ''),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Notificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                if (_notifications.isEmpty) const Center(child: Text('Sin notificaciones'))
                else ..._notifications.map((n) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: n.leido == true ? AppTheme.textLight : AppTheme.primary,
                          child: Icon(n.tipo == 'alerta' ? Icons.warning : Icons.notifications, color: Colors.white),
                        ),
                        title: Text(n.titulo ?? '', style: TextStyle(fontWeight: n.leido == true ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(n.mensaje ?? ''),
                        trailing: n.fecha != null ? Text(n.fecha!, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)) : null,
                      ),
                    )),
              ],
            ),
    );
  }
}
