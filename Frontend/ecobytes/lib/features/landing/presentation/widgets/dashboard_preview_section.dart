import 'package:flutter/material.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/dashboard/data/repositories/mock_sensor_repository.dart';
import '../../../../features/dashboard/domain/models/sensor_data.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../dashboard/presentation/widgets/control_sidebar.dart';
import '../../../dashboard/presentation/widgets/map_area.dart';

class DashboardPreviewSection extends StatelessWidget {
  const DashboardPreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = MockSensorRepository.dashboardSnapshot;

    return ContentContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sectionVertical),
        child: Column(
          children: [
            const SectionLabel(text: 'VISTA PREVIA DEL DASHBOARD'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Explora el mapa sectorizado de Cali en tiempo real',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: context.responsiveValue(mobile: 26, desktop: 34),
                  ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 32,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _PreviewTopBar(snapshot: snapshot),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < AppBreakpoints.tablet;

                      if (stacked) {
                        return Column(
                          children: [
                            SizedBox(
                              height: 320,
                              child: MapArea(interactive: false),
                            ),
                            ControlSidebar(snapshot: snapshot),
                          ],
                        );
                      }

                      return SizedBox(
                        height: 480,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 7,
                              child: MapArea(interactive: false),
                            ),
                            SizedBox(
                              width: 320,
                              child: ControlSidebar(snapshot: snapshot),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTopBar extends StatelessWidget {
  const _PreviewTopBar({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'EcoBytes Dashboard · Cali, Colombia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'EN VIVO',
              style: TextStyle(
                color: AppColors.textOnDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Actualizado hace ${snapshot.updatedMinutesAgo} min',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
