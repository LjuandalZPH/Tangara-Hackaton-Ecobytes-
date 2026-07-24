import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecobytes/main.dart';

void main() {
  testWidgets('EcoBytes landing page renders hero headline', (tester) async {
    await tester.pumpWidget(const MyApp());
    // go_router resuelve la ruta inicial de forma asíncrona; un solo pump()
    // no alcanza a completarla. No usamos pumpAndSettle() porque el preview
    // de mapa embebido en la landing puede seguir reintentando tiles de red
    // (que fallan con 400 en el sandbox de test) y nunca "asentarse".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // El hero usa RichText (no Text) para poder pintar "visible." en verde
    // dentro de la misma oración — find.textContaining solo matchea Text.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().contains('visible.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Explorar mapa'), findsWidgets);

    // Desmonta el árbol para que SectorsProvider cancele su Timer.periodic de
    // polling antes de que termine el test — si no, flutter_test falla por
    // "un Timer sigue pendiente" (MyApp crea el provider en el MultiProvider
    // sin importar qué ruta se esté mostrando).
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
