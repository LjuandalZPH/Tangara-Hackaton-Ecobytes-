import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/models/sensor_data.dart';

/// Área del mapa con grilla sectorizada y marcadores de sensores.
class MapArea extends StatelessWidget {
  const MapArea({
    super.key,
    this.interactive = true,
    this.onSectorTap,
  });

  final bool interactive;
  final ValueChanged<String>? onSectorTap;

  static const _caliCenter = LatLng(3.4516, -76.5320);

  static const _sectors = [
    _SectorPoint('La Flora', LatLng(3.4580, -76.5380), AirQualityLevel.good),
    _SectorPoint('Parque del Amor', LatLng(3.4490, -76.5450), AirQualityLevel.excellent),
    _SectorPoint('Arroyo Hondo', LatLng(3.4650, -76.5200), AirQualityLevel.poor),
    _SectorPoint('Zona Industrial', LatLng(3.4350, -76.5100), AirQualityLevel.poor),
    _SectorPoint('San Antonio', LatLng(3.4420, -76.5400), AirQualityLevel.moderate),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _caliCenter,
            initialZoom: 12.5,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ecobytes',
            ),
            MarkerLayer(
              markers: _sectors
                  .map(
                    (sector) => Marker(
                      point: sector.location,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: interactive
                            ? () => onSectorTap?.call(sector.name)
                            : null,
                        child: _SensorMarker(level: sector.level),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SectorGridPainter(),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _MapLegend(),
        ),
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: _GeneralQualityCard(),
        ),
      ],
    );
  }
}

class _SectorPoint {
  const _SectorPoint(this.name, this.location, this.level);

  final String name;
  final LatLng location;
  final AirQualityLevel level;
}

class _SensorMarker extends StatelessWidget {
  const _SensorMarker({required this.level});

  final AirQualityLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: level.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _SectorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cols = 10;
    const rows = 8;
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
        final paint = Paint()
          ..color = colors[(r + c) % colors.length].withValues(alpha: 0.22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * cellW + 2,
              r * cellH + 2,
              cellW - 4,
              cellH - 4,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Leyenda',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final level in [
            AirQualityLevel.good,
            AirQualityLevel.moderate,
            AirQualityLevel.poor,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: level.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(level.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneralQualityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CALIDAD GENERAL',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buena · AQI promedio: 32',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.statusGood,
            ),
          ),
        ],
      ),
    );
  }
}
