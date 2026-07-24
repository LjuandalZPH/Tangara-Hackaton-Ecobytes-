import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'status_badge.dart';

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.linkLabel,
    this.onLinkTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String linkLabel;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: onLinkTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  linkLabel,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StepItem extends StatelessWidget {
  const StepItem({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.showConnector = true,
  });

  final int number;
  final String title;
  final String description;
  final IconData icon;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    // 1. Extraemos todo el diseño visual a una variable limpia
    final itemContent = Column(
      mainAxisSize: MainAxisSize.min, // Evita que ocupe espacio infinito hacia abajo
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (showConnector)
              Positioned(
                left: 60,
                right: -60,
                child: Container(
                  height: 2,
                  color: AppColors.borderLight,
                ),
              ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Icon(icon, color: AppColors.primaryGreen, size: 28),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 16,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
              ),
        ),
      ],
    );

    // 2. Comprobamos si la pantalla es de escritorio (Desktop) usando el ancho.
    // Si es grande, lo envolvemos en Expanded para que se distribuya bien en el Row.
    // Si es móvil (ancho menor a 800), lo devolvemos envuelto en un Flexible o directo para que no falle.
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Expanded(child: itemContent);
    } else {
      return itemContent; // En móvil se dibuja de forma natural sin forzar tamaño
    }
  }
}