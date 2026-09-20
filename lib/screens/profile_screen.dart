import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/vaia_widgets.dart';
import '../widgets/email_verification_sheet.dart';
import 'verify_phone_screen.dart';

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Encabezado ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: VaiaColors.primaryGradient,
                borderRadius: BorderRadius.circular(VaiaRadius.xl),
                boxShadow: VaiaShadows.elevated,
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      c?.nombre.isNotEmpty == true ? c!.nombre[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
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
            const SizedBox(height: 20),

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
            const SizedBox(height: 20),

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
            const SizedBox(height: 20),

            // ─── Acciones ───────────────────────────────────────
            VaiaPrimaryButton(
              label: 'Mis vehiculos',
              icon: Icons.directions_car_filled_rounded,
              onPressed: () => Navigator.pushNamed(context, '/vehicle'),
            ),
            const SizedBox(height: 10),
            VaiaOutlineButton(
              label: 'Mi documentacion',
              icon: Icons.folder_shared_outlined,
              onPressed: () => Navigator.pushNamed(context, '/documents'),
            ),
            const SizedBox(height: 10),
            VaiaOutlineButton(
              label: 'Configuracion',
              icon: Icons.settings_outlined,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
            const SizedBox(height: 20),
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
