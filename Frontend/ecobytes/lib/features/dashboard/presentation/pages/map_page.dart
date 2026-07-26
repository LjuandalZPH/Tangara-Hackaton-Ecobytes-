import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/status_badge.dart'; // Contiene EcoCard y SectionLabel
import '../../../../shared/widgets/landing_footer.dart';
import '../../../../shared/widgets/landing_header.dart';
import '../../domain/models/sector.dart';
import '../providers/sectors_provider.dart';
import '../widgets/map_area.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera global
            LandingHeader(
              menuOpen: _menuOpen,
              onMenuToggle: () => setState(() => _menuOpen = !_menuOpen),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_menuOpen) const LandingMobileNav(),
                    
                    // Contenedor principal limitado en ancho para Web
                    ContentContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            // Layout Adaptativo: En Web se ve lado a lado, en Móvil en columna
                            if (isDesktop)
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: _MapAreaSection()),
                                  SizedBox(width: AppSpacing.lg),
                                  Expanded(flex: 1, child: _SidePanelSection()),
                                ],
                              )
                            else
                              const Column(
                                children: [
                                  _MapAreaSection(),
                                  SizedBox(height: AppSpacing.lg),
                                  _SidePanelSection(),
                                ],
                              ),
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


//  SECCIÓN 1: EL ÁREA DEL MAPA Y SUS OVERLAYS FLOTANTES

class _MapAreaSection extends StatelessWidget {
  const _MapAreaSection();

  @override
  Widget build(BuildContext context) {
    final sectorsProvider = context.watch<SectorsProvider>();
    final isMobile = context.isMobile;

    return Column(
      children: [
        // El contenedor del mapa
        AspectRatio(
          aspectRatio: context.isMobile ? 1.1 : 1.35,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0), // Tono gris base cartográfica
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildContenidoMapa(context, sectorsProvider),
          ),
        ),
        if (isMobile) ...[
          const SizedBox(height: AppSpacing.md),
          MapLegend(
            coberturaSectores: sectorsProvider.sectores.where((s) => s.tieneDatos).length,
            totalSectores: sectorsProvider.sectores.length,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // Barra de estadísticas inferior
        _BottomMetricsBar(sectores: sectorsProvider.sectores),
      ],
    );
  }

  Widget _buildContenidoMapa(BuildContext context, SectorsProvider provider) {
    switch (provider.estado) {
      case EstadoCarga.cargando:
        return const Center(child: CircularProgressIndicator());
      case EstadoCarga.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  provider.mensajeError ??
                      'No fue posible cargar los sectores.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: provider.cargar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      case EstadoCarga.listo:
        return MapArea(
          sectores: provider.sectores,
          sectorSeleccionadoId: provider.sectorSeleccionado?.id,
          onSectorTap: provider.seleccionarSector,
          showLegend: !context.isMobile,
        );
    }
  }
}

// BARRA INFERIOR DE MÉTRICAS (Debajo del mapa)
// Calculada a partir de los sectores reales entregados por el backend.
class _BottomMetricsBar extends StatelessWidget {
  const _BottomMetricsBar({required this.sectores});

  final List<Sector> sectores;

  @override
  Widget build(BuildContext context) {
    final conDatos = sectores.where((s) => s.tieneDatos).toList();

    Sector? mejor;
    Sector? peor;
    double? promedioCali;

    if (conDatos.isNotEmpty) {
      mejor = conDatos.reduce(
        (a, b) => a.pm25Promedio! < b.pm25Promedio! ? a : b,
      );
      peor = conDatos.reduce(
        (a, b) => a.pm25Promedio! > b.pm25Promedio! ? a : b,
      );
      final suma = conDatos.fold<double>(0, (acc, s) => acc + s.pm25Promedio!);
      promedioCali = suma / conDatos.length;
    }

    return EcoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribución fluida
        children: [
          Expanded(
            child: _buildBottomStat(
              '🟢 MEJOR ZONA',
              mejor?.nombre ?? 'Sin datos',
              mejor != null
                  ? '${mejor.pm25Promedio!.toStringAsFixed(1)} µg/m³'
                  : '—',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildBottomStat(
              '🔴 PEOR ZONA',
              peor?.nombre ?? 'Sin datos',
              peor != null
                  ? '${peor.pm25Promedio!.toStringAsFixed(1)} µg/m³'
                  : '—',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildBottomStat(
              '📊 PROMEDIO CALI',
              promedioCali != null
                  ? '${promedioCali.toStringAsFixed(1)} µg/m³'
                  : '—',
              '${conDatos.length} de ${sectores.length} comunas con datos',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStat(String label, String value, String sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ajusta el título pequeño si el espacio aprieta
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        // Ajusta el nombre de la zona (ej: "Zona Industrial") para que nunca rompa la UI
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}


//  SECCIÓN 2: PANEL DE DETALLE LATERAL DERECHO


class _SidePanelSection extends StatelessWidget {
  const _SidePanelSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SectorsProvider>();
    final sector = provider.sectorSeleccionado;

    return EcoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panel de calidad del aire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

          // SOLUCIÓN 1: Usamos un Wrap en lugar de Row para el subtítulo
          // por si el texto es muy largo en pantallas pequeñas.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.circle, color: _colorConexion(provider), size: 8),
              const SizedBox(width: 4),
              Text(
                _textoConexion(provider),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                overflow: TextOverflow.ellipsis, // Si no cabe, mete tres puntitos (...)
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.borderLight),

          if (sector == null)
            _buildSinSeleccion()
          else ...[
            _buildEstadoCard(sector),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _descripcionPara(sector),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),

            const SectionLabel(text: 'MÉTRICA ACTUAL'),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: 110,
              child: _buildMiniMetric(
                'PM2.5',
                sector.tieneDatos ? sector.pm25Promedio!.toStringAsFixed(1) : '—',
                'µg/m³',
                sector.estado.color,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            const SectionLabel(text: 'RECOMENDACIÓN'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sector.estado.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_iconoPara(sector.estado), color: sector.estado.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recomendacionPara(sector.estado),
                      style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // Botones de acción inferiores
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.chatbot),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Preguntar al chatbot', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              // Sin sector seleccionado (ningún tap en el mapa todavía) no
              // hay a dónde navegar — se deshabilita en vez de ir a un
              // detalle arbitrario.
              onPressed: sector == null
                  ? null
                  : () => context.go(AppRoutes.sectorDetailPath(sector.id)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                sector == null
                    ? 'Selecciona un sector en el mapa'
                    : 'Ver detalle del sector',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Verde solo si el último polling fue exitoso; ámbar si falló pero se
  /// conservan datos previos (`SectorsProvider` nunca borra `_sectores` en un
  /// refresco fallido); gris mientras carga la primera vez.
  Color _colorConexion(SectorsProvider provider) {
    if (provider.estado == EstadoCarga.cargando) return AppColors.textMuted;
    if (provider.mensajeError != null) return AppColors.statusModerate;
    return AppColors.statusGood;
  }

  String _textoConexion(SectorsProvider provider) {
    if (provider.mensajeError != null) {
      return 'Sin conexión, mostrando el último dato disponible · Cali, Colombia';
    }
    return provider.ultimaActualizacion != null
        ? 'Actualizado ${_formatearRelativo(provider.ultimaActualizacion!)} · Cali, Colombia'
        : 'Cali, Colombia';
  }

  Widget _buildSinSeleccion() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_outlined, color: AppColors.textMuted, size: 28),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Selecciona un sector en el mapa para ver su calidad del aire actual.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoCard(Sector sector) {
    final color = sector.estado.color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(_iconoPara(sector.estado), color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sector.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  'Calidad del aire: ${sector.estado.label}',
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconoPara(EstadoSector estado) {
    switch (estado) {
      case EstadoSector.verde:
        return Icons.wb_sunny_outlined;
      case EstadoSector.amarillo:
        return Icons.wb_cloudy_outlined;
      case EstadoSector.rojo:
        return Icons.warning_amber_outlined;
      case EstadoSector.gris:
        return Icons.help_outline;
    }
  }

  String _descripcionPara(Sector sector) {
    if (!sector.tieneDatos) {
      return 'Este sector no cuenta con sensores cercanos o su última lectura es demasiado antigua para considerarse confiable.';
    }
    switch (sector.estado) {
      case EstadoSector.verde:
        return 'La calidad del aire es buena y no representa un riesgo para la salud.';
      case EstadoSector.amarillo:
        return 'La calidad del aire es aceptable para la mayoría de las personas. Algunos grupos sensibles pueden experimentar síntomas leves.';
      case EstadoSector.rojo:
        return 'La calidad del aire es dañina. Se recomienda evitar la exposición prolongada al aire libre.';
      case EstadoSector.gris:
        return 'No hay datos suficientes para evaluar este sector.';
    }
  }

  String _recomendacionPara(EstadoSector estado) {
    switch (estado) {
      case EstadoSector.verde:
        return 'Buen momento para caminar o realizar actividad física al aire libre en este sector.';
      case EstadoSector.amarillo:
        return 'Grupos sensibles (niños, adultos mayores, personas con afecciones respiratorias) deben limitar la exposición prolongada.';
      case EstadoSector.rojo:
        return 'Evita actividad física prolongada al aire libre en este sector.';
      case EstadoSector.gris:
        return 'Sin datos suficientes para dar una recomendación confiable.';
    }
  }

  // SOLUCIÓN 3: Quitamos el 'width: 75' fijo para permitir que tome el tamaño dinámico del Expanded
  Widget _buildMiniMetric(String label, String val, String unit, Color valorColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox( // Mantiene el número dentro de los límites si la pantalla es enana
            fit: BoxFit.scaleDown,
            child: Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valorColor)),
          ),
          Text(unit, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
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

