import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/models/sensor_data.dart';

/// Panel lateral de control con indicadores clave y sensores destacados.
class ControlSidebar extends StatelessWidget {
  const ControlSidebar({
    super.key,
    required this.snapshot,
  });

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indicadores clave',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final metric in snapshot.keyIndicators)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _IndicatorCard(metric: metric),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sensores destacados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final sensor in snapshot.featuredSensors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FeaturedSensorTile(sensor: sensor),
              ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.metric});

  final SensorMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metric.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                metric.statusLabel,
                style: TextStyle(
                  color: metric.statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${metric.value} ${metric.unit}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                ),
          ),
          if (metric.progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: metric.progress,
                minHeight: 6,
                backgroundColor: AppColors.borderLight,
                color: metric.statusColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedSensorTile extends StatelessWidget {
  const _FeaturedSensorTile({required this.sensor});

  final FeaturedSensor sensor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sensor.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            'AQI ${sensor.aqi}',
            style: TextStyle(
              color: sensor.level.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
