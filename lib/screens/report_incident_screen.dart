import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});
  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descCtrl = TextEditingController();
  String _tipo = 'Accidente';
  bool _loading = false;

  final _tipos = ['Accidente', 'Avería Mecánica', 'Cliente Problemático', 'Emergencia Médica', 'Otro'];

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
      'idConductor': auth.userId.toString(),
      'tipo': _tipo,
      'descripcion': _descCtrl.text.trim(),
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
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _tipo = v ?? 'Accidente'),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.warning)),
            ),
            const SizedBox(height: 16),
            const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
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
