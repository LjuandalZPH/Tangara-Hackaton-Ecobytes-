import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/feature_card.dart';
import '../../../../shared/widgets/status_badge.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  static const _steps = [
    (
      title: 'Consulta el mapa',
      description: 'Visualiza sectores y sensores activos en Cali.',
      icon: Icons.map_outlined,
    ),
    (
      title: 'Explora los datos',
      description: 'Revisa PM2.5, CO₂, humedad y tendencias por zona.',
      icon: Icons.insights_outlined,
    ),
    (
      title: 'Toma mejores decisiones',
      description: 'Usa la información para proteger tu salud diaria.',
      icon: Icons.directions_run_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFC),
      child: ContentContainer(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: AppSpacing.sectionVertical),
          child: Column(
            children: [
              const SectionLabel(text: '¿CÓMO FUNCIONA?'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tres pasos para respirar con información',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: context.responsiveValue(mobile: 26, desktop: 34),
                    ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (context.isMobile)
                Column(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        child: StepItem(
                          number: i + 1,
                          title: _steps[i].title,
                          description: _steps[i].description,
                          icon: _steps[i].icon,
                          showConnector: false,
                        ),
                      ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      StepItem(
                        number: i + 1,
                        title: _steps[i].title,
                        description: _steps[i].description,
                        icon: _steps[i].icon,
                        showConnector: i < _steps.length - 1,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
