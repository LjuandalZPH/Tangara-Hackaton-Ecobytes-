import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/feature_card.dart';
import '../../../../shared/widgets/status_badge.dart';

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sectionVertical),
        child: Column(
          children: [
            const SectionLabel(text: '¿QUÉ PUEDES HACER?'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Todo lo que necesitas para entender el aire de tu ciudad',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: context.responsiveValue(mobile: 26, desktop: 34),
                  ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = context.gridColumns;
                final spacing = AppSpacing.lg.toDouble();
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * spacing) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: FeatureCard(
                        icon: Icons.pin_drop_outlined,
                        title: 'Monitorea en tiempo real',
                        description:
                            'Explora un mapa sectorizado de Cali con datos '
                            'actualizados de sensores distribuidos por comunas.',
                        linkLabel: 'Abrir mapa',
                        onLinkTap: () => context.go(AppRoutes.dashboard),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: FeatureCard(
                        icon: Icons.smart_toy_outlined,
                        title: 'Pregunta al asistente',
                        description:
                            'Consulta recomendaciones personalizadas sobre '
                            'calidad del aire con nuestro chatbot ambiental.',
                        linkLabel: 'Chatear ahora',
                        onLinkTap: () => context.go(AppRoutes.chatbot),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: FeatureCard(
                        icon: Icons.menu_book_outlined,
                        title: 'Aprende con contenido claro',
                        description:
                            'Accede a guías didácticas sobre PM2.5, CO₂, '
                            'humedad y cómo interpretar los indicadores.',
                        linkLabel: 'Explorar guías',
                        onLinkTap: () => context.go(AppRoutes.learn),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
