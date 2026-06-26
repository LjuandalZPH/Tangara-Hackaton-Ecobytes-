import 'package:ecobytes/app.dart';
import 'package:flutter/material.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoBytes Cali',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter, // Aquí le entregamos el control a nuestro archivo de rutas
    );
  }
}