import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../widgets/vaia_widgets.dart';

/// Verificacion del telefono por WhatsApp (6 digitos).
class VerifyPhoneScreen extends StatefulWidget {
  final String telefono;
  final String codigopaistel;

  /// Valida el codigo contra el backend.
  final Future<bool> Function(String codigo) onValidar;

  /// Reenvia el codigo.
  final Future<bool> Function() onReenviar;

  /// Se invoca cuando el codigo es correcto.
  final VoidCallback onVerified;

  const VerifyPhoneScreen({
    super.key,
    required this.telefono,
    required this.codigopaistel,
    required this.onValidar,
    required this.onReenviar,
    required this.onVerified,
  });

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final List<TextEditingController> _c = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _f = List.generate(6, (_) => FocusNode());
  bool _validando = false;
  bool _enviando = false;
  int _segundos = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _segundos = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segundos--);
      if (_segundos <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _c) { c.dispose(); }
    for (var f in _f) { f.dispose(); }
    super.dispose();
  }

  void _onChanged(int i, String v) {
    if (v.length == 1 && i < 5) _f[i + 1].requestFocus();
    if (v.length == 1 && i == 5) _validar();
  }

  Future<void> _validar() async {
    final codigo = _c.map((e) => e.text).join();
    if (codigo.length < 6 || _validando) return;
    setState(() => _validando = true);
    final ok = await widget.onValidar(codigo);
    if (!mounted) return;
    setState(() => _validando = false);
    if (ok) {
      widget.onVerified();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo incorrecto o expirado'), backgroundColor: VaiaColors.danger),
      );
      for (var c in _c) { c.clear(); }
      _f[0].requestFocus();
    }
  }

  Future<void> _reenviar() async {
    if (_enviando || _segundos > 0) return;
    setState(() => _enviando = true);
    final ok = await widget.onReenviar();
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      _iniciarTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo reenviado por WhatsApp'), backgroundColor: VaiaColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reenviar el codigo'), backgroundColor: VaiaColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(child: VaiaLogo(size: 72)),
              const SizedBox(height: 24),
              Text('Verifica tu WhatsApp', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Enviamos un codigo de 6 digitos a\n${widget.codigopaistel} ${widget.telefono}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 46,
                  child: TextField(
                    controller: _c[i],
                    focusNode: _f[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
                    onChanged: (v) => _onChanged(i, v),
                  ),
                )),
              ),
              const SizedBox(height: 24),
              VaiaPrimaryButton(
                label: 'Verificar',
                icon: Icons.check_circle_outline_rounded,
                loading: _validando,
                onPressed: _validando ? null : _validar,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_segundos > 0 || _enviando) ? null : _reenviar,
                child: Text(_segundos > 0 ? 'Reenviar codigo en $_segundos s' : 'Reenviar codigo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
