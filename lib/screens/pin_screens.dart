import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';

/// Teclado numerico con indicador de 4 puntos. Se reutiliza para bloquear la
/// app y para configurar el PIN.
class _PinPad extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final int longitud;
  final String? error;
  final ValueChanged<String> onCompleto;

  const _PinPad({
    required this.titulo,
    required this.subtitulo,
    required this.longitud,
    required this.onCompleto,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return _PinPadStateful(
      titulo: titulo,
      subtitulo: subtitulo,
      longitud: longitud,
      error: error,
      onCompleto: onCompleto,
    );
  }
}

class _PinPadStateful extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final int longitud;
  final String? error;
  final ValueChanged<String> onCompleto;
  const _PinPadStateful({
    required this.titulo,
    required this.subtitulo,
    required this.longitud,
    required this.onCompleto,
    this.error,
  });

  @override
  State<_PinPadStateful> createState() => _PinPadStatefulState();
}

class _PinPadStatefulState extends State<_PinPadStateful> {
  String _pin = '';

  void _teclear(String d) {
    if (_pin.length >= widget.longitud) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == widget.longitud) {
      final valor = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        widget.onCompleto(valor);
        if (mounted) setState(() => _pin = '');
      });
    }
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
        const SizedBox(height: 6),
        Text(widget.subtitulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: VaiaColors.textSecondary)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.longitud, (i) {
            final lleno = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: lleno ? 16 : 14,
              height: lleno ? 16 : 14,
              decoration: BoxDecoration(
                color: lleno ? VaiaColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: lleno ? VaiaColors.primary : VaiaColors.borderStrong, width: 1.6),
              ),
            );
          }),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 14),
          Text(widget.error!, style: const TextStyle(fontSize: 12.5, color: VaiaColors.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: 300,
          child: Column(
            children: [
              for (final fila in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', 'del'],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: fila.map((d) {
                    if (d.isEmpty) return const SizedBox(width: 70, height: 66);
                    if (d == 'del') {
                      return SizedBox(
                        width: 70, height: 66,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(40),
                          onTap: _borrar,
                          child: const Icon(Icons.backspace_outlined, size: 24, color: VaiaColors.textSecondary),
                        ),
                      );
                    }
                    return SizedBox(
                      width: 70, height: 66,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: () => _teclear(d),
                        child: Center(
                          child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pantalla de bloqueo: se muestra al abrir la app cuando el PIN esta activo.
class PinLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  const PinLockScreen({super.key, this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String? _error;
  final _storage = StorageService();

  Future<void> _verificar(String pin) async {
    final ok = await _storage.verificarPin(pin);
    if (!mounted) return;
    if (ok) {
      if (widget.onUnlocked != null) {
        widget.onUnlocked!();
      } else {
        final auth = context.read<AuthProvider>();
        bool logged = false;
        try {
          await auth.tryAutoLogin();
          logged = auth.isLoggedIn;
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(logged ? '/home' : '/login', (r) => false);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'PIN incorrecto, intenta de nuevo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaiaColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Image.asset('assets/images/logo.png', width: 76, height: 76),
                ),
                const SizedBox(height: 8),
                _PinPad(
                  titulo: 'Ingresa tu PIN',
                  subtitulo: 'Desbloquea Vaia Conductor para continuar',
                  longitud: 4,
                  error: _error,
                  onCompleto: _verificar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla para establecer o cambiar el PIN. Devuelve true al guardar.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _primero;
  String? _error;
  final _storage = StorageService();

  Future<void> _paso(String pin) async {
    if (_primero == null) {
      setState(() { _primero = pin; _error = null; });
      return;
    }
    if (_primero != pin) {
      HapticFeedback.heavyImpact();
      setState(() { _primero = null; _error = 'Los PIN no coinciden. Intenta de nuevo'; });
      return;
    }
    await _storage.setPin(pin);
    await _storage.setPinHabilitado(true);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN de seguridad')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _PinPad(
              titulo: _primero == null ? 'Crea tu PIN' : 'Confirma tu PIN',
              subtitulo: _primero == null
                  ? 'Elige un PIN de 4 digitos para abrir la app'
                  : 'Vuelve a ingresar el mismo PIN',
              longitud: 4,
              error: _error,
              onCompleto: _paso,
            ),
          ),
        ),
      ),
    );
  }
}
