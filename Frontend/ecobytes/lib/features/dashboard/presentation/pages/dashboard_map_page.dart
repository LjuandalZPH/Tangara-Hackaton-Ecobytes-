import 'package:flutter/material.dart';

import '../../data/repositories/mock_sensor_repository.dart';
import '../widgets/dashboard_layout.dart';

/// Vista principal del Dashboard Mapa (escritorio / tablet / móvil).
class DashboardMapPage extends StatelessWidget {
  const DashboardMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = MockSensorRepository.dashboardSnapshot;

    return Scaffold(
      body: SafeArea(
        child: DashboardLayout(snapshot: snapshot),
      ),
    );
  }
}
