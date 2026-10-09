import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'status_badge.dart'; // EcoCard

/// Estado de error de una sección que no pudo cargar datos del backend.
///
/// Distingue dos casos:
/// - [fuenteNoDisponible] (`503`): el servidor respondió, pero la fuente de
///   datos de sensores está caída. Se presenta como una pausa temporal, en
///   ámbar, con el mensaje que manda el backend.
/// - Cualquier otro error (red, timeout, respuesta inválida): ícono de
///   "sin conexión" en gris.
class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.mensaje,
    required this.onRetry,
    this.fuenteNoDisponible = false,
    this.nota,
    this.conTarjeta = true,
  });

  final String mensaje;
  final VoidCallback onRetry;
  final bool fuenteNoDisponible;

  /// Texto secundario opcional, ej. "Se reintenta automáticamente…".
  final String? nota;

  /// `false` cuando el contenedor padre ya dibuja su propia tarjeta.
  final bool conTarjeta;

  @override
  Widget build(BuildContext context) {
    final color = fuenteNoDisponible ? AppColors.statusModerate : AppColors.textMuted;

    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            fuenteNoDisponible ? Icons.sensors_off_outlined : Icons.cloud_off,
            color: color,
            size: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (fuenteNoDisponible) ...[
          const Text(
            'Datos de sensores en pausa',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        if (nota != null) ...[
          const SizedBox(height: 4),
          Text(
            nota!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar'),
        ),
      ],
    );

    if (!conTarjeta) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: contenido),
      );
    }
    return EcoCard(child: Center(child: contenido));
  }
}
