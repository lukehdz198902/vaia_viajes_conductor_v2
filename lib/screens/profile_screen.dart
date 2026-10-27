import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/foto_util.dart';
import '../widgets/vaia_widgets.dart';
import '../widgets/email_verification_sheet.dart';
import 'verify_phone_screen.dart';
import 'connection_activity_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final c = auth.conductor;
    final correoOk = c?.correoConfirmado == true;
    final telOk = c?.telefonoConfirmado == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Encabezado ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: VaiaColors.primaryGradient,
                borderRadius: BorderRadius.circular(VaiaRadius.xl),
                boxShadow: VaiaShadows.elevated,
              ),
              child: Column(
                children: [
                  _FotoPerfil(
                    foto: c?.fotoPerfil,
                    inicial: c?.nombre.isNotEmpty == true ? c!.nombre[0].toUpperCase() : '?',
                    habilitado: !auth.isOnline,
                  ),
                  const SizedBox(height: 12),
                  Text(c?.nombreCompleto ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(c?.correo ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _chip(Icons.star_rounded, c?.calificacionPromedio?.toStringAsFixed(1) ?? '0.0'),
                      _chip(Icons.route_rounded, '${c?.totalViajes ?? 0} viajes'),
                      _chip(Icons.verified_user_rounded, c?.conductorEstatus ?? 'N/A'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Verificacion ───────────────────────────────────
            _seccion('Verificacion de cuenta'),
            Container(
              decoration: BoxDecoration(
                color: VaiaColors.surface,
                borderRadius: BorderRadius.circular(VaiaRadius.lg),
                border: Border.all(color: VaiaColors.border),
              ),
              child: Column(
                children: [
                  _verifyRow(
                    icon: Icons.alternate_email_rounded,
                    titulo: 'Correo electronico',
                    valor: c?.correo ?? '',
                    verificado: correoOk,
                    onVerificar: () => EmailVerificationSheet.mostrar(context),
                  ),
                  const Divider(height: 1),
                  _verifyRow(
                    icon: Icons.phone_android_rounded,
                    titulo: 'Telefono',
                    valor: c?.telefono ?? '',
                    verificado: telOk,
                    onVerificar: () {
                      final tel = c?.telefono ?? '';
                      if (tel.isEmpty) return;
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => VerifyPhoneScreen(
                          telefono: tel,
                          codigopaistel: '+52',
                          onValidar: (code) => auth.validarCodigoVerificacion(tel, '+52', code),
                          onReenviar: () => auth.enviarCodigoVerificacion(tel, '+52'),
                          onVerified: () => Navigator.pop(context),
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Informacion ────────────────────────────────────
            _seccion('Informacion'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: VaiaColors.surface,
                borderRadius: BorderRadius.circular(VaiaRadius.lg),
                border: Border.all(color: VaiaColors.border),
              ),
              child: Column(
                children: [
                  _infoTile('Documentacion', c?.documentacionAprobada == true ? 'Aprobada' : (c?.nombreEstatusDocs ?? 'Pendiente'),
                      ok: c?.documentacionAprobada == true),
                  _infoTile('Estatus', c?.conductorEstatus ?? 'N/A'),
                  _infoTile('Calificacion', c?.calificacionPromedio?.toStringAsFixed(1) ?? 'N/A'),
                  _infoTile('Viajes', c?.totalViajes?.toString() ?? '0'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Acciones ───────────────────────────────────────
            if (auth.isOnline)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VaiaColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VaiaRadius.md),
                  border: Border.all(color: VaiaColors.warning.withValues(alpha: 0.35)),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_outline_rounded, color: VaiaColors.warning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Estas conectado. Desconectate para modificar tus unidades, documentos o configuracion.',
                      style: TextStyle(fontSize: 12, color: VaiaColors.textSecondary),
                    ),
                  ),
                ]),
              ),
            VaiaPrimaryButton(
              label: 'Mis vehiculos',
              icon: Icons.directions_car_filled_rounded,
              onPressed: auth.isOnline ? null : () => Navigator.pushNamed(context, '/vehicle'),
            ),
            const SizedBox(height: 10),
            VaiaOutlineButton(
              label: 'Mi documentacion',
              icon: Icons.folder_shared_outlined,
              onPressed: auth.isOnline ? null : () => Navigator.pushNamed(context, '/documents'),
            ),
            const SizedBox(height: 10),
            VaiaOutlineButton(
              label: 'Configuracion',
              icon: Icons.settings_outlined,
              onPressed: auth.isOnline ? null : () => Navigator.pushNamed(context, '/settings'),
            ),
            const SizedBox(height: 10),
            VaiaOutlineButton(
              label: 'Actividad y datos',
              icon: Icons.insights_rounded,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectionActivityScreen()),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: VaiaColors.textSecondary, letterSpacing: 0.3)),
      );

  Widget _chip(IconData icon, String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(VaiaRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _verifyRow({
    required IconData icon,
    required String titulo,
    required String valor,
    required bool verificado,
    required VoidCallback onVerificar,
  }) {
    final color = verificado ? VaiaColors.success : VaiaColors.warning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(VaiaRadius.md)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(valor.isEmpty ? 'Sin registrar' : valor, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (verificado)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, color: VaiaColors.success, size: 18),
              const SizedBox(width: 4),
              const Text('Verificado', style: TextStyle(color: VaiaColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
            ])
          else
            TextButton(
              onPressed: onVerificar,
              child: const Text('Verificar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // El resto del archivo mantiene la estructura original.

  Widget _infoTile(String label, String value, {bool ok = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 13.5)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (ok) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.verified_rounded, color: VaiaColors.success, size: 16)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ]),
        ],
      ),
    );
  }
}

/// Avatar del conductor con opcion de tomar/cambiar la foto de perfil.
class _FotoPerfil extends StatefulWidget {
  final String? foto;
  final String inicial;
  final bool habilitado;
  const _FotoPerfil({required this.foto, required this.inicial, required this.habilitado});

  @override
  State<_FotoPerfil> createState() => _FotoPerfilState();
}

class _FotoPerfilState extends State<_FotoPerfil> {
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;

  Future<void> _cambiar() async {
    if (!widget.habilitado || _subiendo) return;
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de galeria'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (origen == null) return;
    final x = await _picker.pickImage(source: origen, imageQuality: 55, maxWidth: 720);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final b64 = base64Encode(bytes);
    if (!mounted) return;
    setState(() => _subiendo = true);
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await auth.updateProfile({'fotoperfil': b64});
    if (!mounted) return;
    setState(() => _subiendo = false);
    messenger.showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: VaiaColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final img = providerFoto(widget.foto);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          backgroundImage: img,
          child: img == null
              ? Text(widget.inicial, style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.w700))
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: _cambiar,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
              ),
              child: _subiendo
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VaiaColors.primary))
                  : Icon(widget.habilitado ? Icons.photo_camera_rounded : Icons.lock_outline_rounded, size: 16, color: VaiaColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
