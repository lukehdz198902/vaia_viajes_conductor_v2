import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/servicio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class RatingScreen extends StatefulWidget {
  final int? idServicio;
  const RatingScreen({super.key, this.idServicio});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _comentCtrl = TextEditingController();
  final Set<String> _tags = {};
  bool _enviando = false;
  Servicio? _detalle;
  late final AnimationController _entrada;

  static const _frases = {1: 'Malo', 2: 'Regular', 3: 'Bueno', 4: 'Muy bueno', 5: 'Excelente'};
  static const _opciones = [
    ('Puntual', Icons.schedule_rounded),
    ('Respetuoso', Icons.sentiment_satisfied_alt_rounded),
    ('Buen punto de recogida', Icons.place_rounded),
    ('Pago al instante', Icons.payments_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDetalle());
  }

  @override
  void dispose() {
    _comentCtrl.dispose();
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    final id = widget.idServicio;
    if (id == null) return;
    final auth = context.read<AuthProvider>();
    final detalle = await context.read<RideProvider>().getDetail(id, auth.userId);
    if (mounted && detalle != null) setState(() => _detalle = detalle);
  }

  String _comentarioFinal() {
    final partes = <String>[];
    if (_tags.isNotEmpty) partes.add(_tags.join(', '));
    final t = _comentCtrl.text.trim();
    if (t.isNotEmpty) partes.add(t);
    final texto = partes.join('. ');
    return texto.length > 150 ? texto.substring(0, 150) : texto;
  }

  Future<void> _finalizar() async {
    final ride = context.read<RideProvider>();
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    if (_rating > 0 && widget.idServicio != null) {
      setState(() => _enviando = true);
      final comentario = _comentarioFinal();
      await ride.calificarPasajero(widget.idServicio!, auth.userId, _rating, comentarios: comentario.isEmpty ? null : comentario);
      if (!mounted) return;
      setState(() => _enviando = false);
    }
    navigator.pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final s = _detalle;
    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrada,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    gradient: VaiaColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: VaiaColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.done_all_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text('Viaje completado',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Califica a tu pasajero para mejorar el servicio',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
                const SizedBox(height: 22),

                if (s != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: VaiaColors.surface,
                      borderRadius: BorderRadius.circular(VaiaRadius.lg),
                      border: Border.all(color: VaiaColors.border),
                      boxShadow: VaiaShadows.card,
                    ),
                    child: Column(children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: VaiaColors.primaryGhost,
                          backgroundImage: (s.pasajeroFoto != null && s.pasajeroFoto!.isNotEmpty) ? NetworkImage(s.pasajeroFoto!) : null,
                          child: (s.pasajeroFoto == null || s.pasajeroFoto!.isEmpty)
                              ? Text(s.pasajeroNombreCompleto.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: VaiaColors.primary))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.pasajeroNombreCompleto, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                            Row(children: [
                              const Icon(Icons.star_rounded, size: 15, color: VaiaColors.accent),
                              const SizedBox(width: 3),
                              Text((s.pasajeroCalificacion ?? 0) > 0 ? s.pasajeroCalificacion!.toStringAsFixed(1) : 'Nuevo',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ]),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(VaiaRadius.md)),
                          child: Column(children: [
                            const Text('Total', style: TextStyle(fontSize: 10, color: VaiaColors.textMuted)),
                            Text('\$${s.montoActual.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: VaiaColors.primary)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      _ruta(s),
                    ]),
                  ),
                const SizedBox(height: 24),

                const Text('Como se porto el pasajero?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final activo = i < _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: activo ? 1.1 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(activo ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 46, color: activo ? VaiaColors.accent : VaiaColors.borderStrong),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(_rating > 0 ? _frases[_rating]! : ' ',
                      key: ValueKey(_rating),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: VaiaColors.primary)),
                ),
                const SizedBox(height: 18),

                if (_rating > 0) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                    children: _opciones.map((o) {
                      final sel = _tags.contains(o.$1);
                      return FilterChip(
                        selected: sel,
                        onSelected: (v) => setState(() => v ? _tags.add(o.$1) : _tags.remove(o.$1)),
                        avatar: Icon(o.$2, size: 16, color: sel ? Colors.white : VaiaColors.textSecondary),
                        label: Text(o.$1),
                        labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? Colors.white : VaiaColors.textPrimary),
                        backgroundColor: VaiaColors.surface,
                        selectedColor: VaiaColors.primary,
                        showCheckmark: false,
                        side: BorderSide(color: sel ? VaiaColors.primary : VaiaColors.border),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _comentCtrl,
                    maxLines: 2,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: 'Comentarios (opcional)',
                      counterText: '',
                      filled: true,
                      fillColor: VaiaColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(VaiaRadius.md), borderSide: const BorderSide(color: VaiaColors.border)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _finalizar,
                    icon: _enviando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: Text(_rating > 0 ? 'Enviar y finalizar' : 'Finalizar', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: _enviando ? null : _finalizar,
                  child: const Text('Omitir', style: TextStyle(color: VaiaColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ruta(Servicio s) {
    return Column(children: [
      Row(children: [
        const Icon(Icons.trip_origin, size: 16, color: VaiaColors.onlineGreen),
        const SizedBox(width: 10),
        Expanded(child: Text(s.direccionOrigen ?? '-', style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.location_on_rounded, size: 16, color: VaiaColors.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(s.direccionDestino ?? '-', style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }
}
