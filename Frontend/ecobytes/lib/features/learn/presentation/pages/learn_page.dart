import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';

import '../../../../shared/widgets/status_badge.dart'; //Aquí dentro viven EcoCard, StatusBadge y SectionLabel

import '../../../../shared/widgets/landing_footer.dart';
import '../../../../shared/widgets/landing_header.dart';
import '../../../dashboard/domain/models/sector.dart';
import '../../domain/models/contenido_educativo.dart';
import '../providers/education_provider.dart';

// Todo el contenido de esta pantalla viene de `GET /education`, que sirve
// `Backend/data/educacion.json`. Ese mismo archivo alimenta al chatbot: es la
// fuente única del contenido educativo, para que la pantalla y el asistente no
// puedan dar cifras distintas (antes aquí decía "<800 ppm" de CO2 y el chatbot
// decía 1000). Los umbrales de PM2.5 y los colores de los cuatro estados no se
// leen del JSON: se derivan de `EstadoSector`, el mismo enum con el que el mapa
// colorea las comunas.

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    // Se difiere al primer frame porque `EducationProvider` está registrado en
    // el MultiProvider global y ya tiene listeners: llamar a `cargar()` durante
    // el build dispararía "setState() called during build". Mismo motivo que en
    // sector_detail_page.dart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EducationProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EducationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // El header y el footer quedan fuera del switch de estado: si el
            // backend está caído, el usuario tiene que poder seguir navegando
            // (a /aprende se llega también desde un botón del chatbot).
            LandingHeader(
              menuOpen: _menuOpen,
              onMenuToggle: () => setState(() => _menuOpen = !_menuOpen),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_menuOpen) const LandingMobileNav(),

                    _buildContenido(provider),

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

  Widget _buildContenido(EducationProvider provider) {
    final contenido = provider.contenido;

    switch (provider.estado) {
      case EstadoEducacion.inicial:
      case EstadoEducacion.cargando:
        return const SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        );

      case EstadoEducacion.error:
        return _ErrorContenido(
          mensaje: provider.mensajeError ??
              'No fue posible cargar el contenido educativo.',
          onReintentar: provider.cargar,
        );

      case EstadoEducacion.listo:
        if (contenido == null) {
          return _ErrorContenido(
            mensaje: 'No fue posible cargar el contenido educativo.',
            onReintentar: provider.cargar,
          );
        }
        return Column(
          children: [
            _HeroSection(copy: contenido.hero),
            if (provider.desdeFallback)
              _AvisoSinConexion(onReintentar: provider.cargar),
            _QueMedimosSection(
              copy: contenido.seccionSenales,
              senales: contenido.senales,
            ),
            _NivelesCalidadSection(
              copy: contenido.seccionNiveles,
              niveles: contenido.niveles,
            ),
            _RecomendacionesSection(
              copy: contenido.seccionRecomendaciones,
              tituloGenerales: contenido.tituloRecomendacionesGenerales,
              porPerfil: contenido.recomendacionesPorPerfil,
              generales: contenido.recomendacionesGenerales,
              fuente: contenido.fuente,
            ),
          ],
        );
    }
  }
}

/// Aviso de que lo que se está viendo salió del asset local y no del backend.
/// Sin esto, contenido congelado se presentaría como fresco.
class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF9C3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: ContentContainer(
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 18, color: Color(0xFF854D0E)),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Estás viendo contenido guardado, sin conexión al servidor.',
                style: TextStyle(color: Color(0xFF854D0E), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onReintentar,
              child: const Text('Reintentar', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorContenido extends StatelessWidget {
  const _ErrorContenido({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 32),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onReintentar,
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
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.copy});

  final CopySeccion copy;

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
            SectionLabel(text: copy.etiqueta),
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.titulo,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: context.responsiveValue(mobile: 28, desktop: 36),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              copy.descripcion,
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
  const _QueMedimosSection({required this.copy, required this.senales});

  final CopySeccion copy;
  final List<SenalMedida> senales;

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
            SectionLabel(text: copy.etiqueta),
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.titulo,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                // 320 de ancho mínimo reproduce las 3 columnas de escritorio
                // (ancho útil 1104) y 1 en móvil, igual que antes.
                final columns = columnasParaAncho(
                  constraints.maxWidth,
                  anchoMinimo: 320,
                  maximo: 3,
                );
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: senales.map((senal) {
                    return SizedBox(
                      width: itemWidth,
                      child: EcoCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senal.sigla,
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              senal.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              senal.descripcion,
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.85),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            // Los efectos en salud ya venían en el JSON pero la
                            // pantalla nunca los mostraba. La humedad llega con
                            // la lista vacía y su tarjeta queda como antes.
                            if (senal.efectosEnSalud.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              ...senal.efectosEnSalud.map(_bullet),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(color: AppColors.borderLight),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              senal.limites.resumen,
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

/// Viñeta de texto reutilizada por las tarjetas y por los consejos generales.
Widget _bullet(String texto) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•  ',
          style: TextStyle(color: AppColors.primaryGreen, fontSize: 13, height: 1.4),
        ),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NivelesCalidadSection extends StatelessWidget {
  const _NivelesCalidadSection({required this.copy, required this.niveles});

  final CopySeccion copy;
  final List<NivelCalidad> niveles;

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
            SectionLabel(text: copy.etiqueta),
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.titulo,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = columnasParaAncho(
                  constraints.maxWidth,
                  anchoMinimo: 250,
                );
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: niveles.map((nivel) {
                    // color y etiqueta salen del enum, no del JSON: son los
                    // mismos que pinta el mapa.
                    final color = nivel.estado.color;

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
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  nivel.nombreColor,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              nivel.estado.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              nivel.descripcion,
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
  const _RecomendacionesSection({
    required this.copy,
    required this.tituloGenerales,
    required this.porPerfil,
    required this.generales,
    required this.fuente,
  });

  final CopySeccion copy;
  final String tituloGenerales;
  final List<RecomendacionPerfil> porPerfil;
  final List<String> generales;
  final FuenteEducativa fuente;

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
            SectionLabel(text: copy.etiqueta),
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.titulo,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = columnasParaAncho(
                  constraints.maxWidth,
                  anchoMinimo: 250,
                );
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: porPerfil.map((reco) {
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
                                  reco.emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              reco.perfil,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              reco.texto,
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

            // Los consejos generales van a ancho completo, no en la grilla:
            // son 5 y en una fila de 4 dejarían una tarjeta huérfana. Como
            // lista crecen sin descuadrar nada.
            if (generales.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              EcoCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloGenerales,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...generales.map(_bullet),
                  ],
                ),
              ),
            ],

            if (fuente.nombre.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Fuente: ${fuente.nombre}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (fuente.url.isNotEmpty)
                Text(
                  fuente.url,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
