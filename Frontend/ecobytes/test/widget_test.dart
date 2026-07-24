import 'package:flutter_test/flutter_test.dart';

import 'package:ecobytes/app.dart';

void main() {
  testWidgets('EcoBytes landing page renders hero headline', (tester) async {
    await tester.pumpWidget(const EcoBytesApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('visible.'), findsOneWidget);
    expect(find.text('Explorar mapa'), findsWidgets);
  });
}
