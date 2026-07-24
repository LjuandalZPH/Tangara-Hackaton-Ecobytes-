import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// Identidad visual y logotipo oficial de la plataforma EcoBytes.
class EcoBytesLogo extends StatelessWidget {
  const EcoBytesLogo({
    super.key,
    this.compact = false,
    this.light = false,
  });

  /// Si es verdadero, reduce el tamaño del logo para barras de navegación o espacios reducidos.
  final bool compact;

  /// Si es verdadero, adapta los colores para fondos oscuros (ej. el footer).
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.textOnDark : AppColors.primaryGreen;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 28 : 36,
          height: compact ? 28 : 36,
          decoration: BoxDecoration(
            color: light ? AppColors.primaryGreen : AppColors.primaryGreenLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.eco_rounded,
            color: light ? AppColors.textOnDark : AppColors.primaryGreen,
            size: compact ? 16 : 22,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'EcoBytes',
          style: TextStyle(
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}