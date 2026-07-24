import 'package:flutter/material.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/models/sensor_data.dart';
import 'control_sidebar.dart';
import 'map_area.dart';

/// Layout responsivo del Dashboard Mapa.
/// Separa el área del mapa del panel lateral de control.
class DashboardLayout extends StatelessWidget {
  const DashboardLayout({
    super.key,
    required this.snapshot,
    this.updatedLabel,
  });

  final DashboardSnapshot snapshot;
  final String? updatedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DashboardTopBar(
          updatedLabel:
              updatedLabel ?? 'Actualizado hace ${snapshot.updatedMinutesAgo} min',
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useSidebar = constraints.maxWidth >= AppBreakpoints.tablet;

              if (!useSidebar) {
                return Column(
                  children: [
                    Expanded(child: MapArea(interactive: true)),
                    SizedBox(
                      height: 360,
                      child: ControlSidebar(snapshot: snapshot),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: MapArea(interactive: true),
                  ),
                  SizedBox(
                    width: context.responsiveValue(
                      mobile: 320,
                      tablet: 320,
                      desktop: 360,
                    ),
                    child: ControlSidebar(snapshot: snapshot),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({required this.updatedLabel});

  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
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
            updatedLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
