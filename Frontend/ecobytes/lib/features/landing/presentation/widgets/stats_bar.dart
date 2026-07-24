import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../dashboard/presentation/providers/sectors_provider.dart';

/// Total de comunas de Cali cubiertas por el GeoJSON de sectores
/// (`Backend/data/sectores.geojson`) — es el alcance geográfico fijo de la
/// app, no la cantidad de comunas con sensores reportando en este momento.
const _totalComunasCali = 22;

class StatsBar extends StatelessWidget {
  const StatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final sectores = context.watch<SectorsProvider>().sectores;
    final conDatos = sectores.where((s) => s.tieneDatos).toList();
    final promedioCiudad = conDatos.isEmpty
        ? null
        : conDatos.fold<double>(0, (acc, s) => acc + s.pm25Promedio!) / conDatos.length;

    final stats = [
      (
        value: sectores.isEmpty ? '—' : '${conDatos.length}/$_totalComunasCali',
        label: 'Comunas con datos en tiempo real',
        icon: Icons.sensors,
      ),
      (value: '24/7', label: 'Monitoreo continuo', icon: Icons.schedule),
      (
        value: '$_totalComunasCali',
        label: 'Comunas monitoreadas en Cali',
        icon: Icons.location_city,
      ),
      (
        value: promedioCiudad == null ? '—' : '${promedioCiudad.toStringAsFixed(1)} µg/m³',
        label: 'PM2.5 promedio ciudad',
        icon: Icons.air,
      ),
    ];

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
              children: stats
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