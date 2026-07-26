import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecobytes/features/learn/presentation/pages/learn_page.dart';
import 'package:ecobytes/features/learn/presentation/providers/education_provider.dart';

void main() {
  testWidgets('LearnPage cae al asset de respaldo cuando no hay backend',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EducationProvider(),
        child: const MaterialApp(home: LearnPage()),
      ),
    );

    // Deja correr el postFrameCallback que dispara la carga. La petición HTTP
    // falla en el sandbox de test, así que el provider debe caer al asset
    // local (assets/educacion.json) en vez de quedarse en error.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);

    // El contenido del asset se pintó...
    expect(find.text('Entiende el aire que respiras en Cali'), findsOneWidget);
    expect(find.text('PM2.5'), findsOneWidget);

    // ...y la pantalla avisa de que no viene del servidor. Contenido
    // congelado presentado como fresco sería peor que no mostrarlo.
    expect(
      find.text('Estás viendo contenido guardado, sin conexión al servidor.'),
      findsOneWidget,
    );

    // La cifra de CO2 debe ser la del backend (1000 ppm), no el "<800 ppm"
    // hardcodeado que la pantalla mostraba antes y que contradecía al chatbot.
    expect(find.text('<1000 ppm en interiores'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // El viewport por defecto de flutter_test es 800x600 y ya escondió dos
  // overflows en este repo. Como el número de tarjetas ahora lo decide el
  // backend, se comprueba explícitamente en móvil, tablet y escritorio.
  for (final (nombre, ancho) in const [
    ('móvil', 390.0),
    ('tablet', 900.0),
    ('escritorio', 1400.0),
  ]) {
    testWidgets('LearnPage no desborda en $nombre ($ancho px)', (tester) async {
      tester.view.physicalSize = Size(ancho, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EducationProvider(),
          child: const MaterialApp(home: LearnPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
