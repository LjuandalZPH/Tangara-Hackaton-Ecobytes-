import 'package:ecobytes/features/landing/presentation/pages/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import '../../features/dashboard/presentation/pages/map_page.dart'; 
import 'features/chatbot/presentation/pages/chatbot_page.dart'; 
import 'features/learn/presentation/pages/learn_page.dart';     

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Configuración central del enrutador de la aplicación usando GoRouter.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.landing,
  routes: [
    GoRoute(
      path: AppRoutes.landing,
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const MapaPage(),
    ),
    GoRoute(
      path: AppRoutes.learn,
      builder: (context, state) => const LearnPage(), 
    ),
    GoRoute(
      path: AppRoutes.chatbot,
      builder: (context, state) => const ChatbotPage(), 
    ),
  ],
);

/// Widget raíz que inicializa el MaterialApp con el tema y enrutador global.
class EcoBytesApp extends StatelessWidget {
  const EcoBytesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoBytes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}