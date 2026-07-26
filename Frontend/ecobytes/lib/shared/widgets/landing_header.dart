import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive.dart';
import 'eco_bytes_logo.dart';

const landingNavLinks = <(String, String)>[
  ('Inicio', AppRoutes.landing),
  ('Mapa', AppRoutes.dashboard),
  ('Aprende', AppRoutes.learn),
  ('Chatbot', AppRoutes.chatbot),
];

class LandingHeader extends StatelessWidget {
  const LandingHeader({
    super.key,
    required this.onMenuToggle,
    required this.menuOpen,
  });

  final VoidCallback onMenuToggle;
  final bool menuOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Container(
      
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1)),
        ),
       
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                const EcoBytesLogo(),
                const Spacer(),
                if (context.isMobile)
                  IconButton(
                    onPressed: onMenuToggle,
                    icon: Icon(menuOpen ? Icons.close : Icons.menu),
                  )
                else
                  Row(
                    children: landingNavLinks
                        .map(
                          (link) => Padding(
                           
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            child: TextButton(
                              onPressed: () => context.go(link.$2),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                link.$1,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class LandingMobileNav extends StatelessWidget {
  const LandingMobileNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Material(
        color: Colors.transparent, 
        child: Column(
          children: [
            for (final link in landingNavLinks)
              ListTile(
                title: Text(link.$1),
                onTap: () => context.go(link.$2),
              ),
          ],
        ),
      ),
    );
  }
}