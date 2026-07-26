import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecobytes/core/data/api_client.dart';
import 'package:ecobytes/features/learn/domain/models/contenido_educativo.dart';
import 'package:ecobytes/features/learn/presentation/pages/learn_page.dart';
import 'package:ecobytes/features/learn/presentation/providers/education_provider.dart';

/// Devuelve un contenido reconocible, distinto del que trae el asset local.
/// Así se distingue de dónde salió el dato que se está pintando.
class _ApiClientQueResponde extends ApiClient {
  @override
  Future<ContenidoEducativo> getContenidoEducativo() async {
    return ContenidoEducativo.fromJson(const {
      'ui': {
        'hero': {
          'etiqueta': 'APRENDE',
          'titulo': 'Título que solo existe en el backend',
          'descripcion': 'Descripción del backend',
        },
      },
      'contaminantes': [
        {'id': 'pm25', 'sigla': 'PM2.5', 'nombre': 'Partículas finas'},
      ],
    });
  }
}

class _ApiClientQueFalla extends ApiClient {
  @override
  Future<ContenidoEducativo> getContenidoEducativo() async {
    throw const ApiException('No fue posible conectarse al servidor.');
  }
}

/// Sirve un contenido ya cargado, sin tocar red ni assets.
///
/// Hace falta porque dentro de `testWidgets` la lectura de un asset
/// (`rootBundle.loadString`) no se resuelve con `pump()`: la pantalla se
/// quedaría en el spinner y las comprobaciones pasarían sobre una página
/// vacía sin comprobar nada.
class _ApiClientConContenido extends ApiClient {
  _ApiClientConContenido(this.contenido);

  final ContenidoEducativo contenido;

  @override
  Future<ContenidoEducativo> getContenidoEducativo() async => contenido;
}

void main() {
  // El riesgo de tener un respaldo local es que tape un fetch roto: la
  // pantalla se vería bien igual, sirviendo contenido congelado. Estos dos
  // tests fijan que el dato salga del backend cuando el backend responde, y
  // que el respaldo solo entre cuando de verdad falla.
  test('EducationProvider usa la respuesta del backend, no el asset', () async {
    final provider = EducationProvider(apiClient: _ApiClientQueResponde());

    await provider.cargar();

    expect(provider.estado, EstadoEducacion.listo);
    expect(provider.desdeFallback, isFalse);
    expect(
      provider.contenido!.hero.titulo,
      'Título que solo existe en el backend',
    );
  });

  test('EducationProvider solo cae al asset si la petición falla', () async {
    final provider = EducationProvider(apiClient: _ApiClientQueFalla());

    await provider.cargar();

    expect(provider.estado, EstadoEducacion.listo);
    expect(provider.desdeFallback, isTrue);
    // El del asset, no el del backend simulado.
    expect(provider.contenido!.hero.titulo, 'Entiende el aire que respiras en Cali');
  });

  test('el asset de respaldo tiene el mismo contenido que sirve el backend',
      () async {
    final contenido = ContenidoEducativo.fromJson(
      jsonDecode(await rootBundle.loadString('assets/educacion.json'))
          as Map<String, dynamic>,
    );

    // Si alguien edita Backend/data/educacion.json y olvida copiarlo, el
    // respaldo se queda viejo en silencio. Esto no lo detecta todo, pero sí
    // que el asset exista, sea parseable y traiga las tres señales.
    expect(contenido.senales.map((s) => s.sigla), ['PM2.5', 'CO2', 'HR']);
    expect(contenido.niveles.length, 4);
    expect(contenido.recomendacionesPorPerfil.length, 4);
    expect(contenido.recomendacionesGenerales.length, 5);
    // La cifra que antes divergía entre la pantalla (800) y el chatbot (1000).
    expect(contenido.senales[1].limites.resumen, '<1000 ppm en interiores');
  });

  testWidgets('LearnPage avisa cuando el contenido viene del respaldo',
      (tester) async {
    // La carga del asset se hace fuera del widget test (ver
    // _ApiClientConContenido) y luego se inyecta ya resuelta.
    late ContenidoEducativo delAsset;
    await tester.runAsync(() async {
      final provider = EducationProvider(apiClient: _ApiClientQueFalla());
      await provider.cargar();
      delAsset = provider.contenido!;
    });

    final provider = EducationProvider(apiClient: _ApiClientQueFalla());
    await tester.runAsync(() => provider.cargar());

    // Dentro de runAsync porque `initState` vuelve a llamar a `cargar()`: al
    // estar mostrando el respaldo, la pantalla reintenta contra la red a
    // propósito, y ese reintento necesita I/O real para resolverse.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: LearnPage()),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(provider.desdeFallback, isTrue);
    expect(delAsset.hero.titulo, 'Entiende el aire que respiras en Cali');
    expect(
      find.text('Estás viendo contenido guardado, sin conexión al servidor.'),
      findsOneWidget,
    );
  });

  // El viewport por defecto de flutter_test es 800x600 y ya escondió dos
  // overflows en este repo. Como el número de tarjetas ahora lo decide el
  // backend, se comprueba explícitamente en móvil, tablet y escritorio, con
  // el contenido completo del asset (3 señales, 4 niveles, 4 perfiles,
  // 5 consejos) — con un contenido mínimo no se ejercitarían las grillas.
  for (final (nombre, ancho) in const [
    ('móvil', 390.0),
    ('tablet', 900.0),
    ('escritorio', 1400.0),
  ]) {
    testWidgets('LearnPage no desborda en $nombre ($ancho px)', (tester) async {
      tester.view.physicalSize = Size(ancho, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late ContenidoEducativo contenido;
      await tester.runAsync(() async {
        final p = EducationProvider(apiClient: _ApiClientQueFalla());
        await p.cargar();
        contenido = p.contenido!;
      });

      final provider = EducationProvider(
        apiClient: _ApiClientConContenido(contenido),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: LearnPage()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // La página se pintó de verdad (no se quedó en el spinner) y no desborda.
      expect(provider.estado, EstadoEducacion.listo);
      expect(find.text('Entiende el aire que respiras en Cali'), findsOneWidget);
      expect(find.text('<1000 ppm en interiores'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
