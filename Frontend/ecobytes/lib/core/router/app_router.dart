import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chatbot/presentation/pages/chatbot_page.dart';
import '../../features/dashboard/presentation/pages/map_page.dart';
import '../../features/dashboard/presentation/pages/sector_detail_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/learn/presentation/pages/learn_page.dart';

/// Rutas de navegación globales de la aplicación.
abstract final class AppRoutes {
  static const landing = '/';
  static const dashboard = '/mapa';
  static const learn = '/aprende';
  static const chatbot = '/chatbot';

  /// Detalle de un sector — no es un ítem de navegación propio (no aparece
  /// en el nav global), solo se llega desde el mapa. Ver
  /// docs/frontend.md.
  static const sectorDetail = '/mapa/:sectorId';
  static String sectorDetailPath(String sectorId) => '/mapa/$sectorId';
}

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
    GoRoute(
      path: AppRoutes.sectorDetail,
      builder: (context, state) => SectorDetailPage(
        sectorId: state.pathParameters['sectorId']!,
      ),
    ),
  ],
);
