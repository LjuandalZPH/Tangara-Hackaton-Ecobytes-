import 'package:flutter/material.dart';

/// Rutas de navegación globales de la aplicación.
abstract final class AppRoutes {
  static const landing = '/';
  static const dashboard = '/mapa';
  static const learn = '/aprende';
  static const chatbot = '/chatbot';
}

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