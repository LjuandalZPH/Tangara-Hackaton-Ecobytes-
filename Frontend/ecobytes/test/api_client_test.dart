import 'dart:convert';

import 'package:ecobytes/core/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _clienteQueResponde(int status, Object? cuerpo) {
  return ApiClient(
    httpClient: MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(cuerpo == null ? '' : jsonEncode(cuerpo)),
        status,
        headers: const {'content-type': 'application/json'},
      ),
    ),
  );
}

void main() {
  test('503 se traduce en ServicioNoDisponibleException con el detail del backend', () async {
    final cliente = _clienteQueResponde(503, {
      'detail': 'La fuente de datos de sensores no está disponible en este momento.',
    });

    await expectLater(
      cliente.getSectores(),
      throwsA(
        isA<ServicioNoDisponibleException>().having(
          (e) => e.mensaje,
          'mensaje',
          'La fuente de datos de sensores no está disponible en este momento.',
        ),
      ),
    );
  });

  test('un error sin detail no expone el código de estado', () async {
    final cliente = _clienteQueResponde(500, null);

    await expectLater(
      cliente.getSectores(),
      throwsA(
        isA<ApiException>()
            .having((e) => e, 'tipo', isNot(isA<ServicioNoDisponibleException>()))
            .having((e) => e.mensaje, 'mensaje', isNot(contains('500'))),
      ),
    );
  });

  test('un detail que no es texto (422 de validación) se descarta', () async {
    final cliente = _clienteQueResponde(422, {
      'detail': [
        {'loc': ['body', 'mensaje'], 'msg': 'field required'},
      ],
    });

    await expectLater(
      cliente.postChatbot(mensaje: 'hola', historial: const []),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          'El servidor no pudo completar la solicitud. Intenta de nuevo.',
        ),
      ),
    );
  });
}
