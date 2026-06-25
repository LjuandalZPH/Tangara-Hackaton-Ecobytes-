import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';

class CtaSection extends StatelessWidget {
  const CtaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ctaBackground,
      padding: EdgeInsets.symmetric(
        vertical: context.responsiveValue(mobile: 56.0, desktop: 80.0),
      ),
      child: ContentContainer(
        child: Column(
          children: [
            Text(
              'EMPIEZA HOY',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.8),
                    letterSpacing: 1.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Comienza a entender el aire que respiras.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppColors.textOnDark,
                    fontSize: context.responsiveValue(mobile: 28, desktop: 38),
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Información ambiental clara, accesible y en tiempo real '
              'para toda la comunidad de Cali.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.dashboard),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.primaryGreen,
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Explorar mapa interactivo'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Gratis · Sin registro · Datos en tiempo real',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
