import 'package:ecobytes/app.dart';
import 'package:ecobytes/features/dashboard/presentation/providers/sectors_provider.dart';
import 'package:ecobytes/features/risk/presentation/providers/risk_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SectorsProvider()..cargar()),
        ChangeNotifierProvider(create: (_) => RiskProvider()),
      ],
      child: MaterialApp.router(
        title: 'EcoBytes Cali',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter, // Aquí le entregamos el control a nuestro archivo de rutas
      ),
    );
  }
}
