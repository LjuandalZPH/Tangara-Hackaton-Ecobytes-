import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/status_badge.dart'; // Contiene EcoCard y SectionLabel
import '../../../landing/presentation/widgets/landing_footer.dart';
import '../../../landing/presentation/widgets/landing_header.dart';

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
    return Column(
      children: [
        // El contenedor del mapa físico simulado
        AspectRatio(
          aspectRatio: context.isMobile ? 1.1 : 1.35,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0), // Tono gris base cartográfica
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Stack(
              children: [
                // 1. Fondo simulación de cuadrícula/mapa técnico
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: GridPaper(
                      color: Colors.blueGrey.shade800,
                      divisions: 2,
                      subdivisions: 1,
                      interval: 100,
                    ),
                  ),
                ),
                
                // Texto indicador en el fondo
                const Center(
                  child: Text(
                    '[ Espacio reservado para mapa interactivo ]\nCali, Valle del Cauca',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),

                // 2. CARD FLOTANTE: Alerta Ambiental (Arriba Izquierda)
                Positioned(
                  top: 16,
                  left: 16,
                  width: 260,
                  child: _buildAlertaFlotante(),
                ),

                // 3. PIN FLOTANTE: Info del sensor El Peñón (Centro Superior)
                Positioned(
                  top: context.isMobile ? 120 : 160,
                  left: context.isMobile ? 80 : 260,
                  child: _buildSensorMarker(),
                ),

                // 4. LEYENDA DE CALIDAD DEL AIRE (Abajo Izquierda)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _buildLeyendaMapa(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Barra de estadísticas inferior
        const _BottomMetricsBar(),
      ],
    );
  }

  Widget _buildAlertaFlotante() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alerta ambiental', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
                SizedBox(height: 2),
                Text(
                  'El sector industrial presenta niveles elevados de PM2.5. Se recomienda evitar la zona.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSensorMarker() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          child: const Column(
            children: [
              Text('Centro — El Peñón', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.circle, color: Colors.amber, size: 10),
                  SizedBox(width: 4),
                  Text('AQI 55 · Moderado', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        Container(width: 2, height: 15, color: Colors.black45),
        const Icon(Icons.location_on, color: Colors.amber, size: 24),
      ],
    );
  }

  Widget _buildLeyendaMapa() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALIDAD DEL AIRE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          SizedBox(height: 6),
          _LeyendaItem(color: Colors.green, text: 'Buena (AQI 0-50)'),
          _LeyendaItem(color: Colors.amber, text: 'Moderada (51-100)'),
          _LeyendaItem(color: Colors.orange, text: 'Mala (101-150)'),
          _LeyendaItem(color: Colors.red, text: 'Peligrosa (151+)'),
        ],
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LeyendaItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// BARRA INFERIOR DE MÉTRICAS (Debajo del mapa)
// BARRA INFERIOR DE MÉTRICAS (Optimizada contra desbordamientos)
class _BottomMetricsBar extends StatelessWidget {
  const _BottomMetricsBar();

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribución fluida
        children: [
          Expanded(child: _buildBottomStat('🟢 MEJOR ZONA', 'La Buitrera', 'AQI 18')),
          const SizedBox(width: 4),
          Expanded(child: _buildBottomStat('🔴 PEOR ZONA', 'Zona Industrial', 'AQI 108')),
          const SizedBox(width: 4),
          Expanded(child: _buildBottomStat('📊 PROMEDIO CALI', 'AQI 52', '16 µg/m³ PM2.5')),
          if (context.isDesktop) ...[
            const SizedBox(width: 4),
            Expanded(child: _buildBottomStat('📈 TENDENCIA 24H', 'Estable', '+2% vs ayer')),
          ],
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
              const Icon(Icons.circle, color: Colors.green, size: 8),
              const SizedBox(width: 4),
              Text(
                'Actualizado hace 3 min · Cali, Colombia', 
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                overflow: TextOverflow.ellipsis, // Si no cabe, mete tres puntitos (...)
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.borderLight),

          // Estado General Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.wb_cloudy_outlined, color: Colors.amber.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded( // Protege los textos dentro del Row
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Moderado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber.shade900)),
                      const Text('AQI promedio ciudad: 52', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'La calidad del aire es aceptable para la mayoría de las personas. Algunos grupos sensibles pueden experimentar síntomas leves.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Métricas Promedio
          const SectionLabel(text: 'MÉTRICAS ACTUALES PROMEDIO'),
          const SizedBox(height: AppSpacing.sm),
          
          // SOLUCIÓN 2: En lugar de un Row rígido, usamos Expanded en cada métrica 
          // para que se encojan equitativamente según el ancho del panel.
          Row(
            children: [
              Expanded(child: _buildMiniMetric('PM2.5', '18', 'µg/m³')),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniMetric('CO2', '420', 'ppm')),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniMetric('O3', '67', '%')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Insights rápidos
          const SectionLabel(text: 'INSIGHTS RÁPIDOS'),
          const SizedBox(height: AppSpacing.sm),
          _buildInsightRow('Sensor más limpio', 'Buitrera', 'AQI 18', Colors.green),
          _buildInsightRow('Sensor más contaminated', 'Cordoba city', 'AQI 108', Colors.redAccent),
          _buildInsightRow('Promedio ciudad', '16 µg/m³', 'AQI 52', Colors.blueGrey),
          const SizedBox(height: AppSpacing.lg),

          // Recomendación
          const SectionLabel(text: 'RECOMENDACIÓN'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.directions_walk, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Buen momento para caminar o realizar actividad física ligera en zonas sur y centro de la ciudad.',
                    style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Botones de acción inferiores
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
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
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ver detalle del sector', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // SOLUCIÓN 3: Quitamos el 'width: 75' fijo para permitir que tome el tamaño dinámico del Expanded
  Widget _buildMiniMetric(String label, String val, String unit) {
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
            child: Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
          Text(unit, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String title, String place, String aqi, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(place, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(aqi, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

