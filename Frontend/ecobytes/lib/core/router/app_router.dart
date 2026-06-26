import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; 

// 1. Importamos las pantallas reales del proyecto
import '../../features/landing/presentation/pages/landing_page.dart'; 
import '../../features/learn/presentation/pages/learn_page.dart';  
import '../../features/chatbot/presentation/pages/chatbot_page.dart';

/// Rutas de navegación globales de la aplicación.
abstract final class AppRoutes {
  static const landing = '/';
  static const dashboard = '/mapa';
  static const learn = '/aprende';
  static const chatbot = '/chatbot';
}

// 2. CREAMOS EL ENRUTADOR REAL QUE GOBIERNA LA APP
final goRouter = GoRouter(
  initialLocation: AppRoutes.landing,
  routes: [
    // Ruta 1: La Landing Page (Inicio)
    GoRoute(
      path: AppRoutes.landing,
      builder: (context, state) => const LandingPage(), 
    ),
    
    // Ruta 2: La nueva sección que acabamos de programar
    GoRoute(
      path: AppRoutes.learn,
      builder: (context, state) => const LearnPage(), 
    ),

    // Ruta 3: El Mapa (Sigue temporal hasta que lo programes)
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const PlaceholderPage(title: 'Mapa Interactivo'),
    ),

    // Ruta 4: El Chatbot (Sigue temporal)
    GoRoute(
      path: AppRoutes.chatbot,
      builder: (context, state) => const ChatbotPage(),
    ),
  ],
);

/// Vista temporal para pantallas en desarrollo.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title — próximamente',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}