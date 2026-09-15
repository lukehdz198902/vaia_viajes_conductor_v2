import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  final int? idServicio;

  const ReportIncidentScreen({super.key, this.idServicio});
  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descCtrl = TextEditingController();
  int _idTipo = 5;
  bool _loading = false;

  static const Map<int, String> _tipos = {
    1: 'Problema con el Conductor',
    2: 'Problema con el Pasajero',
    3: 'Problema con la Unidad',
    4: 'Problema de Pago',
    5: 'Problema de Ruta',
    6: 'Problema de Seguridad',
    7: 'Queja General',
  };

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describa el incidente'), backgroundColor: AppTheme.danger));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final api = ApiService();
    final resp = await api.reportarIncidente({
      if (widget.idServicio != null) 'idServicio': widget.idServicio,
      'idConductor': auth.userId,
      'idTipo': _idTipo,
      'desc': _descCtrl.text.trim(),
    });
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.ok ? 'Incidente reportado' : resp.mensaje), backgroundColor: resp.ok ? AppTheme.accent : AppTheme.danger),
      );
      if (resp.ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar Incidente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de Incidente', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _idTipo,
              items: _tipos.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _idTipo = v ?? 5),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.warning)),
            ),
            if (widget.idServicio != null) ...[
              const SizedBox(height: 8),
              Text('Servicio #${widget.idServicio}', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ],
            const SizedBox(height: 16),
            const Text('Descripcion', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(hintText: 'Describa el incidente en detalle...', alignLabelWithHint: true),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.send),
                label: Text(_loading ? 'Enviando...' : 'Reportar Incidente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
