import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/soporte_model.dart';
import '../providers/ride_provider.dart';
import '../providers/soporte_provider.dart';
import '../widgets/vaia_widgets.dart';

class SupportChatScreen extends StatefulWidget {
  final int idServicio;
  final int? idSolicitudExistente;

  const SupportChatScreen({super.key, required this.idServicio, this.idSolicitudExistente});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _inicializando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  Future<void> _inicializar() async {
    final soporte = context.read<SoporteProvider>();
    if (widget.idSolicitudExistente != null) {
      await soporte.cargarSolicitud(widget.idSolicitudExistente!);
      setState(() => _inicializando = false);
      return;
    }
    final id = await soporte.crearSolicitud(
      idServicio: widget.idServicio,
      asunto: 'Soporte para servicio #${widget.idServicio}',
      descripcion: 'El conductor ha iniciado una conversacion con soporte',
    );
    if (!mounted) return;
    if (id != null && id > 0) {
      await soporte.cargarSolicitud(id);
      setState(() => _inicializando = false);
    } else {
      setState(() {
        _error = soporte.error ?? 'No se pudo crear la solicitud de soporte';
        _inicializando = false;
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty) return;
    _msgCtrl.clear();
    await context.read<SoporteProvider>().enviarMensaje(texto);
    _scrollAbajo();
  }

  void _scrollAbajo() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soporte = context.watch<SoporteProvider>();
    final ride = context.watch<RideProvider>();
    final servicio = ride.activeRide;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            context.read<SoporteProvider>().salirDeSolicitud();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Soporte en linea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Servicio #${widget.idServicio}',
                style: const TextStyle(fontSize: 11, color: VaiaColors.textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: soporte.solicitudActiva?.abierta == true
                      ? VaiaColors.success.withOpacity(0.12)
                      : VaiaColors.bgMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: soporte.solicitudActiva?.abierta == true ? VaiaColors.success : VaiaColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      soporte.solicitudActiva?.estatus ?? 'Conectando...',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: soporte.solicitudActiva?.abierta == true ? VaiaColors.success : VaiaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (servicio != null) _buildServicioContexto(servicio),
          Expanded(
            child: _inicializando
                ? const Center(child: CircularProgressIndicator(color: VaiaColors.primary))
                : _error != null
                    ? _buildError()
                    : _buildMensajes(soporte),
          ),
          _buildInput(soporte),
        ],
      ),
    );
  }

  Widget _buildServicioContexto(dynamic servicio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: VaiaColors.primaryGhost,
      child: Row(
        children: [
          const Icon(Icons.route_rounded, size: 18, color: VaiaColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${servicio.direccionOrigen} -> ${servicio.direccionDestino}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Estatus: ${servicio.estatus ?? "--"}',
                  style: const TextStyle(fontSize: 11, color: VaiaColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 56, color: VaiaColors.textMuted),
            const SizedBox(height: 12),
            Text(_error ?? 'Error', textAlign: TextAlign.center, style: const TextStyle(color: VaiaColors.textSecondary)),
            const SizedBox(height: 16),
            VaiaPrimaryButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              fullWidth: false,
              onPressed: () {
                setState(() { _error = null; _inicializando = true; });
                _inicializar();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMensajes(SoporteProvider soporte) {
    if (soporte.mensajes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: VaiaColors.primary),
              ),
              const SizedBox(height: 16),
              Text('Soporte esta en linea', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Cuentanos en que podemos ayudarte con tu servicio',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAbajo());
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: soporte.mensajes.length,
      itemBuilder: (ctx, i) => _burbuja(soporte.mensajes[i]),
    );
  }

  Widget _burbuja(SoporteMensajeModel m) {
    final esMio = !m.esDeSoporte;
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: esMio ? VaiaColors.primary : VaiaColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(esMio ? 14 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 14),
          ),
          border: esMio ? null : Border.all(color: VaiaColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esMio)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(m.nombreEmisor ?? 'Soporte',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: VaiaColors.primary)),
              ),
            Text(m.mensaje, style: TextStyle(fontSize: 14, color: esMio ? Colors.white : VaiaColors.textPrimary)),
            const SizedBox(height: 2),
            Text(_hora(m.fechaCreacion),
                style: TextStyle(fontSize: 10, color: esMio ? Colors.white70 : VaiaColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(SoporteProvider soporte) {
    final habilitado = soporte.solicitudActiva?.abierta == true && !soporte.enviando;
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              enabled: habilitado,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                hintText: habilitado ? 'Escribe tu mensaje...' : 'Solicitud cerrada',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: habilitado ? VaiaColors.primary : VaiaColors.bgMuted,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: habilitado ? _enviar : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                child: soporte.enviando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hora(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}