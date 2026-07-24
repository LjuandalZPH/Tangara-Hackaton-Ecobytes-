import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; 

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart'; 
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/eco_bytes_logo.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    // Creamos los bloques de contenido para poder reutilizarlos fácilmente
    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EcoBytesLogo(light: true),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Plataforma ciudadana para monitorear y comprender '
          'la calidad del aire en Cali, Colombia.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textOnDark.withValues(alpha: 0.7),
              ),
        ),
      ],
    );

    // CONEXIÓN DE RUTAS: Convertimos las listas de texto plano en pares de (Texto, Ruta)
    final plataformaColumn = _FooterColumn(
      title: 'PLATAFORMA',
      links: const [
        ('Mapa interactivo', AppRoutes.dashboard),
        ('Chatbot ambiental', AppRoutes.chatbot),
        ('Aprende', AppRoutes.learn),
        ('Indicadores', AppRoutes.dashboard), 
      ],
    );

    final proyectoColumn = _FooterColumn(
      title: 'PROYECTO',
      links: const [
        ('BitAVIT Labs', AppRoutes.landing),
        ('Universidad del Valle', AppRoutes.landing),
        ('Hackathon Tángara', AppRoutes.landing),
        ('Código abierto', AppRoutes.landing),
      ],
    );

    final socialRow = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: const [
        _SocialIcon(icon: Icons.language),
        SizedBox(width: AppSpacing.sm),
        _SocialIcon(icon: Icons.code),
        SizedBox(width: AppSpacing.sm),
        _SocialIcon(icon: Icons.share_outlined),
      ],
    );

    return Container(
      width: double.infinity,
      color: AppColors.footerBackground,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: ContentContainer(
        child: Column(
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoColumn,
                  const SizedBox(height: AppSpacing.xl),
                  plataformaColumn,
                  const SizedBox(height: AppSpacing.lg),
                  proyectoColumn,
                  const SizedBox(height: AppSpacing.lg),
                  socialRow,
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: infoColumn),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(flex: 2, child: plataformaColumn),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 2, child: proyectoColumn),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 1, child: socialRow),
                ],
              ),
            const SizedBox(height: AppSpacing.xxl),
            const Divider(color: Color(0xFF2D3748)),
            const SizedBox(height: AppSpacing.lg),
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Text(
                  '© ${DateTime.now().year} EcoBytes · Cali, Colombia',
                  style: TextStyle(
                    color: AppColors.textOnDark.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                if (isMobile) const SizedBox(height: AppSpacing.xs),
                Text(
                  'BitAVIT Labs · Universidad del Valle',
                  style: TextStyle(
                    color: AppColors.textOnDark.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  //  CAMBIO DE TIPO: Ahora acepta una lista de registros (String, String) con Nombre y Ruta
  final List<(String, String)> links; 

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            // INTERACTIVIDAD: Envolvemos en un InkWell para que sea clickeable con efecto web
            child: InkWell(
              onTap: () => context.go(link.$2), // El campo $2 es la ruta de GoRouter
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Text(
                  link.$1, // El campo $1 es el texto legible del botón
                  style: TextStyle(
                    color: AppColors.textOnDark.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.textOnDark, size: 18),
    );
  }
}