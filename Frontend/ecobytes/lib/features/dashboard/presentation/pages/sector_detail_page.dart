import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/landing_footer.dart';
import '../../../../shared/widgets/landing_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../risk/domain/models/riesgo.dart';
import '../../../risk/presentation/providers/risk_provider.dart';
import '../../domain/models/sector.dart';
import '../providers/sector_detail_provider.dart';

/// Detalle de un sector, alcanzado desde el mapa ("Ver detalle del sector" o
/// tap en un polígono) — no es un ítem de navegación propio. Dos pestañas:
/// Resumen (indicadores actuales + evolución 24h, `GET /sectors/{id}`) e
/// Historia (perfil histórico anual, `GET /risk/{sector}`). La pestaña
/// "Sensores" del Figma se dejó fuera: ningún endpoint expone sensores
/// individuales por sector todavía (ver 05-Discrepancias.md §2.1).
class SectorDetailPage extends StatefulWidget {
  const SectorDetailPage({super.key, required this.sectorId});

  final String sectorId;

  @override
  State<SectorDetailPage> createState() => _SectorDetailPageState();
}

class _SectorDetailPageState extends State<SectorDetailPage> {
  bool _menuOpen = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Ambos providers ya tienen listeners activos desde el MultiProvider de
    // main.dart (a diferencia de SectorsProvider, que arranca su carga en el
    // create() de su propio provider, antes de que exista ningún listener).
    // Llamar a cargarDetalle()/cargarRiesgo() aquí dispara un notifyListeners()
    // síncrono que intenta reconstruir un ancestro mientras este widget
    // todavía se está montando — Flutter lo rechaza con "setState() called
    // during build". Se difiere al primer frame ya renderizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SectorDetailProvider>().cargarDetalle(widget.sectorId);
      context.read<RiskProvider>().cargarRiesgo(widget.sectorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            LandingHeader(
              menuOpen: _menuOpen,
              onMenuToggle: () => setState(() => _menuOpen = !_menuOpen),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_menuOpen) const LandingMobileNav(),
                    ContentContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () => context.go(AppRoutes.dashboard),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('Volver al mapa'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Consumer<SectorDetailProvider>(
                              builder: (context, provider, _) => _SectorHeader(provider: provider),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _TabSelector(
                              index: _tabIndex,
                              onChanged: (i) => setState(() => _tabIndex = i),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (_tabIndex == 0)
                              Consumer<SectorDetailProvider>(
                                builder: (context, provider, _) => _ResumenTab(provider: provider),
                              )
                            else
                              Consumer<RiskProvider>(
                                builder: (context, provider, _) => _HistoriaTab(provider: provider),
                              ),
                            const SizedBox(height: AppSpacing.xl),
                            const _ActionButtons(),
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                    const LandingFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectorHeader extends StatelessWidget {
  const _SectorHeader({required this.provider});

  final SectorDetailProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.estado == EstadoDetalle.error) {
      return _ErrorState(
        mensaje: provider.mensajeError ?? 'No fue posible cargar este sector.',
        onRetry: () => provider.cargarDetalle(provider.sectorActual!),
      );
    }

    final cargando =
        provider.estado == EstadoDetalle.inicial || provider.estado == EstadoDetalle.cargando;
    final detalle = provider.detalle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cargando ? 'Cargando…' : (detalle?.nombre ?? provider.sectorActual ?? ''),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detalle?.ultimaLectura != null
                    ? 'Cali, Colombia · Actualizado ${_formatearRelativo(detalle!.ultimaLectura!)}'
                    : 'Cali, Colombia',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (!cargando && detalle != null)
          StatusBadge(label: detalle.estado.label, color: detalle.estado.color),
      ],
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _tabs = ['Resumen', 'Historia'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(_tabs[i]),
              selected: index == i,
              onSelected: (_) => onChanged(i),
              selectedColor: AppColors.textPrimary,
              backgroundColor: AppColors.surfaceMuted,
              side: BorderSide.none,
              labelStyle: TextStyle(
                color: index == i ? AppColors.textOnDark : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResumenTab extends StatelessWidget {
  const _ResumenTab({required this.provider});

  final SectorDetailProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider.estado) {
      case EstadoDetalle.inicial:
      case EstadoDetalle.cargando:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        );
      case EstadoDetalle.error:
        return _ErrorState(
          mensaje: provider.mensajeError ?? 'No fue posible cargar los indicadores.',
          onRetry: () => provider.cargarDetalle(provider.sectorActual!),
        );
      case EstadoDetalle.listo:
        final detalle = provider.detalle!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(text: 'INDICADORES ACTUALES'),
            const SizedBox(height: AppSpacing.sm),
            _IndicatorsRow(detalle: detalle),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel(text: 'EVOLUCIÓN DE LA CALIDAD DEL AIRE · ÚLTIMAS 24H'),
            const SizedBox(height: AppSpacing.sm),
            _HistorialChart(historial: detalle.historial24h),
          ],
        );
    }
  }
}

class _IndicatorsRow extends StatelessWidget {
  const _IndicatorsRow({required this.detalle});

  final SectorDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      _IndicatorCard(
        label: 'PM2.5',
        value: detalle.pm25Promedio,
        unit: 'µg/m³',
        estado: detalle.estado,
      ),
      _IndicatorCard(label: 'CO₂', value: detalle.co2Promedio, unit: 'ppm'),
      _IndicatorCard(label: 'Humedad', value: detalle.humPromedio, unit: '%'),
    ];

    if (context.isMobile) {
      return Column(
        children: [
          for (final tarjeta in tarjetas)
            Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: tarjeta),
        ],
      );
    }

    // IntrinsicHeight (no un Row con stretch a secas): esta fila vive dentro
    // de una Column con alto no acotado — stretch ahí exige una altura
    // infinita y Flutter lo rechaza. IntrinsicHeight mide el alto real de
    // las tarjetas y lo usa como límite, así quedan parejas sin ese problema.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tarjeta in tarjetas)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: tarjeta,
              ),
            ),
        ],
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.label,
    required this.value,
    required this.unit,
    this.estado,
  });

  final String label;
  final double? value;
  final String unit;

  /// Solo se pasa para PM2.5 — es el único indicador con umbrales OMS
  /// definidos en este proyecto (ver config.py del backend). CO2 y humedad
  /// no tienen un estado de "bueno/malo" establecido, así que no se inventa uno.
  final EstadoSector? estado;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value != null ? value!.toStringAsFixed(1) : '—',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (estado != null) ...[
            const SizedBox(height: AppSpacing.sm),
            StatusBadge(label: estado!.label, color: estado!.color),
          ],
        ],
      ),
    );
  }
}

class _HistorialChart extends StatelessWidget {
  const _HistorialChart({required this.historial});

  final List<HoraPromedio> historial;

  @override
  Widget build(BuildContext context) {
    final puntos = historial
        .where((h) => h.hora != null && h.pm25Promedio != null)
        .toList();

    if (puntos.isEmpty) {
      return const EcoCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: Text(
              'Sin historial suficiente en las últimas 24 horas para este sector.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < puntos.length; i++) FlSpot(i.toDouble(), puntos[i].pm25Promedio!),
    ];
    final valorMaximo = puntos.map((p) => p.pm25Promedio!).reduce((a, b) => a > b ? a : b);
    final maxY = (valorMaximo * 1.2).clamp(10, double.infinity).toDouble();
    final intervaloEtiquetas = (puntos.length / 4).clamp(1, double.infinity).toDouble();

    return EcoCard(
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 32),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: intervaloEtiquetas,
                  getTitlesWidget: (value, meta) {
                    final indice = value.round();
                    if (indice < 0 || indice >= puntos.length) return const SizedBox.shrink();
                    final hora = puntos[indice].hora!.hour.toString().padLeft(2, '0');
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${hora}h',
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primaryGreen,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoriaTab extends StatelessWidget {
  const _HistoriaTab({required this.provider});

  final RiskProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider.estado) {
      case EstadoRiesgo.inicial:
      case EstadoRiesgo.cargando:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        );
      case EstadoRiesgo.error:
        return _ErrorState(
          mensaje: provider.mensajeError ?? 'No fue posible cargar el histórico.',
          onRetry: () => provider.cargarRiesgo(provider.sectorActual!),
        );
      case EstadoRiesgo.listo:
        return _RiskProfileCard(riesgo: provider.riesgo!);
    }
  }
}

class _RiskProfileCard extends StatelessWidget {
  const _RiskProfileCard({required this.riesgo});

  final Riesgo riesgo;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(text: 'PERFIL HISTÓRICO ANUAL'),
          const SizedBox(height: AppSpacing.md),
          if (!riesgo.historicoSuficiente)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.statusModerate.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.statusModerate),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Este sector todavía no tiene suficiente histórico para un perfil confiable.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _RiesgoStat(
                  label: 'Promedio anual',
                  valor: riesgo.promedioAnual?.toStringAsFixed(1),
                  unidad: 'µg/m³',
                ),
              ),
              Expanded(
                child: _RiesgoStat(
                  label: 'Días sobre límite OMS',
                  valor: riesgo.diasSobreLimiteOms.toString(),
                  unidad: 'días/año',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MesStat(
                  label: 'Peor mes',
                  mes: riesgo.peorMes,
                  color: AppColors.statusBad,
                ),
              ),
              Expanded(
                child: _MesStat(
                  label: 'Mejor mes',
                  mes: riesgo.mejorMes,
                  color: AppColors.statusGood,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiesgoStat extends StatelessWidget {
  const _RiesgoStat({required this.label, required this.valor, required this.unidad});

  final String label;
  final String? valor;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          valor != null ? '$valor $unidad' : '— $unidad',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MesStat extends StatelessWidget {
  const _MesStat({required this.label, required this.mes, required this.color});

  final String label;
  final MesPromedio? mes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              mes != null ? mes!.mes : 'Sin datos',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (mes?.promedio != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${mes!.promedio!.toStringAsFixed(1)} µg/m³',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.go(AppRoutes.chatbot),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Preguntar al chatbot'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.dashboard),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Ver el mapa'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
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
