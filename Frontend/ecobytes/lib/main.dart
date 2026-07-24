import 'package:ecobytes/core/router/app_router.dart';
import 'package:ecobytes/core/theme/app_theme.dart';
import 'package:ecobytes/features/dashboard/presentation/providers/sector_detail_provider.dart';
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
        ChangeNotifierProvider(create: (_) => SectorDetailProvider()),
      ],
      child: MaterialApp.router(
        title: 'EcoBytes Cali',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter, // Aquí le entregamos el control a nuestro archivo de rutas
      ),
    );
  }
}
