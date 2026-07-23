import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/models/sector.dart';

/// Mapa interactivo de Cali con los sectores (comunas) coloreados según
/// su estado de calidad del aire.
class MapArea extends StatelessWidget {
  const MapArea({
    super.key,
    this.sectores = const [],
    this.sectorSeleccionadoId,
    this.interactive = true,
    this.onSectorTap,
  });

  final List<Sector> sectores;
  final String? sectorSeleccionadoId;
  final bool interactive;
  final ValueChanged<String>? onSectorTap;

  static const _caliCenter = LatLng(3.4516, -76.5320);

  void _manejarTap(TapPosition posicionTap, LatLng punto) {
    if (!interactive || onSectorTap == null) return;
    for (final sector in sectores) {
      for (final poligono in sector.poligonos) {
        if (puntoEnPoligono(punto, poligono)) {
          onSectorTap!(sector.id);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectoresConDatos = sectores.where((s) => s.tieneDatos).length;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _caliCenter,
            initialZoom: 11.5,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onTap: interactive ? _manejarTap : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ecobytes',
            ),
            PolygonLayer(
              polygons: [
                for (final sector in sectores)
                  for (final anillo in sector.poligonos)
                    _construirPoligono(
                      sector: sector,
                      anillo: anillo,
                      seleccionado: sector.id == sectorSeleccionadoId,
                    ),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _MapLegend(
            coberturaSectores: sectoresConDatos,
            totalSectores: sectores.length,
          ),
        ),
      ],
    );
  }

  Polygon _construirPoligono({
    required Sector sector,
    required List<LatLng> anillo,
    required bool seleccionado,
  }) {
    final color = sector.estado.color;
    return Polygon(
      points: anillo,
      color: color.withValues(alpha: seleccionado ? 0.65 : 0.45),
      borderColor: color,
      borderStrokeWidth: seleccionado ? 3.0 : 1.5,
      label: sector.nombre,
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.coberturaSectores,
    required this.totalSectores,
  });

  final int coberturaSectores;
  final int totalSectores;

  static const _entradas = [
    (EstadoSector.verde, 'Buena'),
    (EstadoSector.amarillo, 'Moderada'),
    (EstadoSector.rojo, 'Dañina'),
    (EstadoSector.gris, 'Sin datos'),
  ];

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
          for (final entrada in _entradas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: entrada.$1.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entrada.$2, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '$coberturaSectores de $totalSectores comunas con sensores activos',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
