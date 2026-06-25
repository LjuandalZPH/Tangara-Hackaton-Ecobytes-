import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'status_badge.dart';

/// Tarjeta informativa para visualizar métricas específicas (ej. niveles de PM2.5 o CO₂).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.statusLabel,
    required this.statusColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final String statusLabel;
  final Color statusColor;

  /// Reduce los márgenes internos y el tamaño del texto para cuadrículas densas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          StatusBadge(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

