import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/dashboard/data/repositories/mock_sensor_repository.dart';
import '../../../../features/dashboard/domain/models/sensor_data.dart';
import '../../../../shared/widgets/metric_card.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = MockSensorRepository.landingMetrics;
    final isStacked = context.isMobile;

    return ContentContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sectionVertical),
        child: Flex(
          direction: isStacked ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment:
              isStacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: isStacked ? 0 : 5,
              child: _HeroCopy(
                onExploreMap: () => context.go(AppRoutes.dashboard),
                onLearnMore: () => context.go(AppRoutes.learn),
              ),
            ),
            SizedBox(height: isStacked ? AppSpacing.xxl : 0, width: isStacked ? 0 : AppSpacing.xxl),
            Expanded(
              flex: isStacked ? 0 : 6,
              child: _HeroVisual(metrics: metrics),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.onExploreMap,
    required this.onLearnMore,
  });

  final VoidCallback onExploreMap;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryGreenLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'DATOS EN TIEMPO REAL · CALI, COLOMBIA',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryGreenDark,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: context.responsiveValue(mobile: 32, desktop: 44),
                ),
            children: const [
              TextSpan(text: 'Porque el aire que respiras también merece ser '),
              TextSpan(
                text: 'visible.',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Monitorea la calidad del aire en Cali con datos abiertos, '
          'visualizaciones claras y herramientas para tomar mejores '
          'decisiones sobre tu salud y la de tu comunidad.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: context.responsiveValue(mobile: 15, desktop: 17),
              ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            ElevatedButton.icon(
              onPressed: onExploreMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Explorar mapa'),
            ),
            OutlinedButton.icon(
              onPressed: onLearnMore,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('Aprender más'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({required this.metrics});

  final LandingMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: context.isMobile ? 1.1 : 1.25,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryGreenLight,
                        AppColors.surfaceMuted,
                      ],
                    ),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: CustomPaint(
                    painter: _CaliMapPreviewPainter(),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 24,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARROYO HONDO',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AQI 82',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.statusPoor,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = context.gridColumns.clamp(1, 3);
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * AppSpacing.md) / columns;

            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: MetricCard(
                    label: metrics.pm25.label,
                    value: '${metrics.pm25.value} ${metrics.pm25.unit}',
                    statusLabel: metrics.pm25.statusLabel,
                    statusColor: metrics.pm25.statusColor,
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: MetricCard(
                    label: metrics.co2.label,
                    value: '${metrics.co2.value} ${metrics.co2.unit}',
                    statusLabel: metrics.co2.statusLabel,
                    statusColor: metrics.co2.statusColor,
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: MetricCard(
                    label: metrics.humidity.label,
                    value: '${metrics.humidity.value}${metrics.humidity.unit}',
                    statusLabel: metrics.humidity.statusLabel,
                    statusColor: metrics.humidity.statusColor,
                    compact: true,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CaliMapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    const cols = 8;
    const rows = 6;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final colors = [
      AppColors.statusGood,
      AppColors.statusModerate,
      AppColors.statusPoor,
      AppColors.statusExcellent,
    ];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final color = colors[(r + c) % colors.length].withValues(alpha: 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * cellW + 4,
              r * cellH + 4,
              cellW - 8,
              cellH - 8,
            ),
            const Radius.circular(6),
          ),
          gridPaint..color = color,
        );
      }
    }

    final dotPaint = Paint()..color = AppColors.primaryGreen;
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.42), 8, dotPaint);
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.58),
      6,
      dotPaint..color = AppColors.statusModerate,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
