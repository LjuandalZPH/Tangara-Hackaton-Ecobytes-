import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/chatbot/domain/models/mensaje_chat.dart';
import '../../features/dashboard/domain/models/sector.dart';
import '../../features/learn/domain/models/contenido_educativo.dart';
import '../../features/risk/domain/models/riesgo.dart';
import '../config/api_config.dart';

/// Excepción propia para errores al consumir el backend de EcoBytes.
/// Siempre trae un mensaje legible en español para mostrar en la UI.
class ApiException implements Exception {
  const ApiException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// El servidor no tiene configurado el chatbot (`503` de `POST /chatbot`,
/// es decir: no hay `OPENAI_API_KEY`). Se distingue del resto de errores
/// porque no es un fallo transitorio — reintentar no sirve de nada, y la
/// UI debe mostrar el asistente como "Fuera de línea" en vez de ofrecer
/// un botón de reintentar.
class ChatbotNoDisponibleException extends ApiException {
  const ChatbotNoDisponibleException(super.mensaje);
}

/// Cliente HTTP encargado de consumir el backend de EcoBytes.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _timeout = Duration(seconds: 15);
  static const _timeoutLargo = Duration(seconds: 45);

  Future<List<Sector>> getSectores() async {
    final json = await _getJson('/sectors');
    final sectores = (json['sectores'] as List?) ?? [];
    return sectores
        .map((e) => Sector.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SectorDetalle> getSectorDetalle(String id) async {
    final json = await _getJson('/sectors/$id');
    return SectorDetalle.fromJson(json);
  }

  Future<List<SensorDeSector>> getSensoresDeSector(String id) async {
    final json = await _getJson('/sectors/$id/sensores');
    final sensores = (json['sensores'] as List?) ?? [];
    return sensores
        .map((e) => SensorDeSector.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Riesgo> getRiesgo(String sectorId) async {
    final json = await _getJson('/risk/$sectorId');
    return Riesgo.fromJson(json);
  }

  Future<ContenidoEducativo> getContenidoEducativo() async {
    final json = await _getJson('/education');
    return ContenidoEducativo.fromJson(json);
  }

  /// Envía un mensaje al asistente ambiental. `historial` son los turnos
  /// previos de esta misma conversación: el backend no los recuerda, hay
  /// que mandarlos siempre (los recorta a los últimos 10 por su cuenta).
  Future<RespuestaChatbot> postChatbot({
    required String mensaje,
    required List<MensajeChat> historial,
  }) async {
    final json = await _postJson('/chatbot', {
      'mensaje': mensaje,
      'historial': historial.map((m) => m.toJson()).toList(),
    });
    return RespuestaChatbot.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    } catch (_) {
      throw const ApiException(
        'No fue posible conectarse al servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'El servidor respondió con un error (${response.statusCode}).',
      );
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('La respuesta del servidor no es válida.');
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> cuerpo,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          // Más holgado que `_timeout`: al otro lado hay una llamada a un
          // modelo de lenguaje, que el backend corta a los 30s
          // (OPENAI_TIMEOUT_SEGUNDOS). Cortar antes que él dejaría al
          // usuario sin la respuesta que el servidor sí alcanzó a producir.
          .timeout(_timeoutLargo);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    } catch (_) {
      throw const ApiException(
        'No fue posible conectarse al servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 503) {
      throw const ChatbotNoDisponibleException(
        'El asistente no está configurado en el servidor.',
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'El servidor respondió con un error (${response.statusCode}).',
      );
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('La respuesta del servidor no es válida.');
    }
  }
}
