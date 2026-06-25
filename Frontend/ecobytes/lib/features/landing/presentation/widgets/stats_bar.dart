import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';

class StatsBar extends StatelessWidget {
  const StatsBar({super.key});

  static const _stats = [
    (value: '47', label: 'Sensores activos', icon: Icons.sensors),
    (value: '24/7', label: 'Monitoreo continuo', icon: Icons.schedule),
    (value: '22', label: 'Comunas cubiertas', icon: Icons.location_city),
    (value: '2.4M', label: 'Ciudadanos informados', icon: Icons.people_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: ContentContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = context.responsiveValue(mobile: 2, tablet: 4, desktop: 4);
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              alignment: WrapAlignment.center,
              children: _stats
                  .map(
                    (stat) => SizedBox(
                      width: itemWidth,
                      child: _StatItem(
                        value: stat.value,
                        label: stat.label,
                        icon: stat.icon,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // Alinea el icono al centro vertical del bloque
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                    ),
                softWrap: true, // Permite el salto de línea amistoso
              ),
            ],
          ),
        ),
      ],
    );
  }
}