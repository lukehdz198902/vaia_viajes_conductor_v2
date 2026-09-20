import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/conductor_model.dart';
import '../models/unidad_model.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// Tarjeta de requisitos del conductor: le indica que le falta subir
/// documentacion, registrar una unidad o esperar la validacion.
class OnboardingChecklist extends StatelessWidget {
  const OnboardingChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final conductor = auth.conductor;
    if (conductor == null) return const SizedBox.shrink();

    final docs = _estadoDocumentacion(conductor);
    final unidad = _estadoUnidad(profile.unidades);

    // Todo listo: mostrar aviso de que ya puede laborar
    if (docs.ok && unidad.ok) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)]),
          borderRadius: BorderRadius.circular(VaiaRadius.lg),
          boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ya puedes laborar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Tu documentacion y tu unidad estan aprobadas.', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
        boxShadow: VaiaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(VaiaRadius.sm)),
                child: const Icon(Icons.assignment_late_outlined, size: 16, color: VaiaColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Completa tu perfil para laborar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _item(
            context,
            icono: docs.icono,
            color: docs.color,
            titulo: docs.titulo,
            detalle: docs.detalle,
            ok: docs.ok,
            accion: docs.ok ? null : () => Navigator.pushNamed(context, '/documents'),
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icono: unidad.icono,
            color: unidad.color,
            titulo: unidad.titulo,
            detalle: unidad.detalle,
            ok: unidad.ok,
            accion: unidad.ok ? null : () => Navigator.pushNamed(context, '/vehicle'),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    required bool ok,
    VoidCallback? accion,
  }) {
    return InkWell(
      onTap: accion,
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 1),
                  Text(detalle, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (accion != null)
              Icon(Icons.chevron_right_rounded, color: color)
            else
              const Icon(Icons.check_circle_rounded, color: VaiaColors.success, size: 20),
          ],
        ),
      ),
    );
  }

  _Estado _estadoDocumentacion(Conductor c) {
    final aprobada = c.documentacionAprobada == true;
    final estatus = (c.nombreEstatusDocs ?? '').toLowerCase();

    if (aprobada) {
      return const _Estado(
        titulo: 'Documentacion aprobada',
        detalle: 'Tu documentacion esta validada.',
        color: VaiaColors.success,
        icono: Icons.verified_rounded,
        ok: true,
      );
    }
    if (estatus.contains('correc') || estatus.contains('rechaz')) {
      return const _Estado(
        titulo: 'Documentacion con correcciones',
        detalle: 'Revisa los comentarios y vuelve a subir tus documentos.',
        color: VaiaColors.danger,
        icono: Icons.error_outline_rounded,
        ok: false,
      );
    }
    if (estatus.contains('revis')) {
      return const _Estado(
        titulo: 'Documentacion en revision',
        detalle: 'Estamos validando tus documentos.',
        color: VaiaColors.warning,
        icono: Icons.hourglass_top_rounded,
        ok: false,
      );
    }
    return const _Estado(
      titulo: 'Sube tu documentacion',
      detalle: 'Aun no has subido todos tus documentos.',
      color: VaiaColors.primary,
      icono: Icons.upload_file_rounded,
      ok: false,
    );
  }

  _Estado _estadoUnidad(List<Unidad> unidades) {
    if (unidades.isEmpty) {
      return const _Estado(
        titulo: 'Registra una unidad',
        detalle: 'Necesitas al menos un vehiculo registrado.',
        color: VaiaColors.primary,
        icono: Icons.add_road_rounded,
        ok: false,
      );
    }
    final aprobadas = unidades.where((u) => u.aprobada == true).toList();
    if (aprobadas.isEmpty) {
      return const _Estado(
        titulo: 'Unidad en revision',
        detalle: 'Tu unidad esta pendiente de aprobacion.',
        color: VaiaColors.warning,
        icono: Icons.hourglass_top_rounded,
        ok: false,
      );
    }
    if (aprobadas.length > 1 && !aprobadas.any((u) => u.enUso == true)) {
      return const _Estado(
        titulo: 'Selecciona tu unidad de trabajo',
        detalle: 'Elige con cual de tus unidades vas a laborar.',
        color: VaiaColors.accent,
        icono: Icons.touch_app_rounded,
        ok: false,
      );
    }
    return const _Estado(
      titulo: 'Unidad aprobada',
      detalle: 'Tu unidad esta lista para trabajar.',
      color: VaiaColors.success,
      icono: Icons.verified_rounded,
      ok: true,
    );
  }
}

class _Estado {
  final String titulo;
  final String detalle;
  final Color color;
  final IconData icono;
  final bool ok;
  const _Estado({required this.titulo, required this.detalle, required this.color, required this.icono, required this.ok});
}
