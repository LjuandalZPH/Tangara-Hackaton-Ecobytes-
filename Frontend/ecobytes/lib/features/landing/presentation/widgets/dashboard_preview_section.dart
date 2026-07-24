import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../dashboard/domain/models/sector.dart';
import '../../../dashboard/presentation/providers/sectors_provider.dart';
import '../../../dashboard/presentation/widgets/map_area.dart';

class DashboardPreviewSection extends StatelessWidget {
  const DashboardPreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SectorsProvider>();
    final sectores = provider.sectores;

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
                  _PreviewTopBar(provider: provider),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < AppBreakpoints.tablet;

                      if (stacked) {
                        return Column(
                          children: [
                            SizedBox(
                              height: 320,
                              child: MapArea(sectores: sectores, interactive: false),
                            ),
                            _PreviewSidebar(sectores: sectores),
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
                              child: MapArea(sectores: sectores, interactive: false),
                            ),
                            SizedBox(
                              width: 340,
                              child: _PreviewSidebar(sectores: sectores),
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
  const _PreviewTopBar({required this.provider});

  final SectorsProvider provider;

  @override
  Widget build(BuildContext context) {
    final enVivo = provider.estado == EstadoCarga.listo && provider.mensajeError == null;

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
              color: enVivo ? AppColors.primaryGreen : AppColors.textMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              enVivo ? 'EN VIVO' : 'CARGANDO',
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            provider.ultimaActualizacion != null
                ? 'Actualizado ${_formatearRelativo(provider.ultimaActualizacion!)}'
                : '—',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

/// Panel lateral con indicadores reales (calculados a partir de los
/// sectores que devuelve `GET /sectors`) — reemplaza al antiguo
/// `ControlSidebar`, que mostraba sensores y porcentajes de progreso
/// inventados (`MockSensorRepository`).
class _PreviewSidebar extends StatelessWidget {
  const _PreviewSidebar({required this.sectores});

  final List<Sector> sectores;

  @override
  Widget build(BuildContext context) {
    final conDatos = sectores.where((s) => s.tieneDatos).toList();

    Sector? mejor;
    Sector? peor;
    double? promedio;
    if (conDatos.isNotEmpty) {
      mejor = conDatos.reduce((a, b) => a.pm25Promedio! < b.pm25Promedio! ? a : b);
      peor = conDatos.reduce((a, b) => a.pm25Promedio! > b.pm25Promedio! ? a : b);
      final suma = conDatos.fold<double>(0, (acc, s) => acc + s.pm25Promedio!);
      promedio = suma / conDatos.length;
    }
    final estadoPromedio = promedio != null ? estadoDesdePm25(promedio) : null;

    return Container(
      color: AppColors.surfaceMuted,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indicadores clave',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            _IndicatorTile(
              label: 'PM2.5 promedio ciudad',
              value: promedio != null ? '${promedio.toStringAsFixed(1)} µg/m³' : '—',
              statusLabel: estadoPromedio?.label ?? 'Cargando',
              statusColor: estadoPromedio?.color ?? AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            _IndicatorTile(
              label: 'Cobertura de sensores',
              value: sectores.isEmpty ? '—' : '${conDatos.length}/22 comunas',
              statusLabel: sectores.isEmpty ? 'Cargando' : 'Con datos hoy',
              statusColor: sectores.isEmpty ? AppColors.textMuted : AppColors.primaryGreen,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Comunas destacadas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            _ComunaTile(etiqueta: 'Mejor', sector: mejor),
            const SizedBox(height: AppSpacing.sm),
            _ComunaTile(etiqueta: 'Peor', sector: peor),
          ],
        ),
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({
    required this.label,
    required this.value,
    required this.statusLabel,
    required this.statusColor,
  });

  final String label;
  final String value;
  final String statusLabel;
  final Color statusColor;

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
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _ComunaTile extends StatelessWidget {
  const _ComunaTile({required this.etiqueta, required this.sector});

  final String etiqueta;
  final Sector? sector;

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
              sector != null ? '$etiqueta: ${sector!.nombre}' : '$etiqueta: sin datos aún',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (sector != null)
            Text(
              '${sector!.pm25Promedio!.toStringAsFixed(1)} µg/m³',
              style: TextStyle(
                color: sector!.estado.color,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// Formatea una fecha como tiempo relativo corto ("hace 3 min", "hace 2 h").
/// Si el reloj del cliente va detrás del servidor, la diferencia puede salir
/// negativa — se trata igual que "justo ahora" en vez de mostrar un número
/// negativo confuso.
String _formatearRelativo(DateTime fecha) {
  final diferencia = DateTime.now().difference(fecha);
  if (diferencia.isNegative || diferencia.inMinutes < 1) return 'justo ahora';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  return 'hace ${diferencia.inDays} días';
}
