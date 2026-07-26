import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecobytes/features/dashboard/presentation/pages/sector_detail_page.dart';
import 'package:ecobytes/features/dashboard/presentation/providers/sector_detail_provider.dart';
import 'package:ecobytes/features/risk/presentation/providers/risk_provider.dart';

void main() {
  testWidgets('SectorDetailPage no lanza excepciones al montarse y cargar',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SectorDetailProvider()),
          ChangeNotifierProvider(create: (_) => RiskProvider()),
        ],
        child: const MaterialApp(
          home: SectorDetailPage(sectorId: 'comuna-2'),
        ),
      ),
    );

    // Deja correr el postFrameCallback que dispara la carga y el fetch
    // (falla con 400 en el sandbox de test, entra a estado "error" — lo que
    // nos importa aquí es que nada de eso rompa el árbol de widgets).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Volver al mapa'), findsOneWidget);

    // Cambiar a la pestaña "Historia" también debe reconstruir sin errores.
    await tester.tap(find.text('Historia'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Igual para "Sensores" (GET /sectors/{id}/sensores).
    await tester.tap(find.text('Sensores'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Desmonta para no dejar ningún estado pendiente entre tests.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
