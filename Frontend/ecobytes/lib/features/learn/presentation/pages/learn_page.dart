import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';


import '../../../../shared/widgets/status_badge.dart'; //Aquí dentro viven EcoCard, StatusBadge y SectionLabel

import '../../../../shared/widgets/landing_footer.dart';
import '../../../../shared/widgets/landing_header.dart';

// --- ESTRUCTURAS DE DATOS (RECORDS) ---
//
// Los umbrales de PM2.5 y los 4 estados de calidad del aire deben coincidir
// con los que usa el resto de la app (Backend/config.py: PM25_UMBRAL_BUENO=15,
// PM25_UMBRAL_MODERADO=35; EstadoSectorX en sector.dart) — este contenido es
// educativo, pero no puede enseñar una escala distinta a la que el mapa y el
// detalle de sector realmente usan. No se incluye O3: el backend no lo mide
// en ningún endpoint (`Sector`/`SectorDetalle` solo traen PM2.5, CO2 y humedad).

const _contaminantes = <(String, String, String, String)>[
  (
    'PM2.5',
    'Partículas finas',
    'Partículas diminutas de polvo, humo y hollín que penetran hasta los pulmones y el torrente sanguíneo. Provienen del tráfico, la quema de biomasa y la industria.',
    '<15 µg/m³ bueno (OMS)',
  ),
  (
    'CO2',
    'Dióxido de carbono',
    'Gas producido por la combustión de vehículos e industrias. En espacios abiertos se dispersa, pero niveles altos sostenidos indican poca ventilación o tráfico denso.',
    '<800 ppm, referencia general',
  ),
  (
    'HR',
    'Humedad relativa',
    'No es un contaminante, pero influye en cómo se sienten y dispersan las partículas en el aire. Útil para interpretar el resto de las métricas.',
    '30-60% ideal',
  ),
];

const _nivelesCalidad = <(Color, String, String, String)>[
  (AppColors.statusGood, 'Verde', 'Buena', 'PM2.5 por debajo de 15 µg/m³. Ideal para actividades al aire libre sin restricciones.'),
  (AppColors.statusModerate, 'Amarillo', 'Moderada', 'PM2.5 entre 15 y 35 µg/m³. Aceptable para la mayoría; grupos sensibles podrían notar síntomas leves.'),
  (AppColors.statusBad, 'Rojo', 'Dañina', 'PM2.5 por encima de 35 µg/m³. Se recomienda evitar actividad física intensa al aire libre.'),
  (AppColors.textMuted, 'Gris', 'Sin datos', 'El sector no tiene sensores cercanos, o su última lectura es demasiado antigua para considerarse confiable.'),
];

const _recomendaciones = <(String, String, String)>[
  (
    '🏃‍♂️',
    'Población general',
    'Con calidad del aire moderada (amarillo) puedes hacer ejercicio al aire libre con normalidad. Evita las horas pico de tráfico (7–9am y 5–7pm) si vives cerca de avenidas principales.',
  ),
  (
    '👶',
    'Niños y mujeres embarazadas',
    'Sus vías respiratorias son más sensibles. Prioriza actividades al aire libre en zonas verdes como Pance o la Buitrera, lejos del tráfico denso.',
  ),
  (
    '🫁',
    'Personas con asma o EPOC',
    'Lleva siempre tu inhalador de rescate. Si la calidad del aire está en rojo, considera mover el ejercicio a interiores o a primera hora de la mañana.',
  ),
  (
    '👵',
    'Adultos mayores',
    'Revisa el estado de calidad del aire antes de salir a caminar. Prefiere paseos cortos en horarios de menor contaminación, generalmente temprano en la mañana.',
  ),
];

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  bool _menuOpen = false;

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
                    
                    const _HeroSection(),
                    const _QueMedimosSection(),
                    const _NivelesCalidadSection(),
                    const _RecomendacionesSection(),
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

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(text: 'APRENDE'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Entiende el aire que respiras en Cali',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: context.responsiveValue(mobile: 28, desktop: 36),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Una guía sencilla sobre los contaminantes que medimos, qué significa cada estado de calidad del aire (verde, amarillo, rojo) y cómo proteger tu salud según la calidad del aire del día.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueMedimosSection extends StatelessWidget {
  const _QueMedimosSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(text: 'QUÉ MEDIMOS'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cuatro señales, una foto clara del aire',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = context.isMobile;
                final columns = isMobile ? 1 : 3;
                final itemWidth = (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: _contaminantes.map((data) {
                    return SizedBox(
                      width: itemWidth,
                      child: EcoCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.$1,
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              data.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              data.$3,
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.85),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(color: AppColors.borderLight),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              data.$4,
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NivelesCalidadSection extends StatelessWidget {
  const _NivelesCalidadSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(text: 'CALIDAD DEL AIRE'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Qué significa cada estado',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = context.isMobile;
                final columns = isMobile ? 1 : 4;
                final itemWidth = (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: _nivelesCalidad.map((level) {
                    return SizedBox(
                      width: itemWidth,
                      child: EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: level.$1,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  level.$2,
                                  style: TextStyle(
                                    color: level.$1,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              level.$3,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              level.$4,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecomendacionesSection extends StatelessWidget {
  const _RecomendacionesSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(text: 'CUÍDATE'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Recomendaciones según tu perfil',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = context.isMobile;
                final columns = isMobile ? 1 : 4;
                final itemWidth = (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: _recomendaciones.map((reco) {
                    return SizedBox(
                      width: itemWidth,
                      child: EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  reco.$1,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              reco.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              reco.$3,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}