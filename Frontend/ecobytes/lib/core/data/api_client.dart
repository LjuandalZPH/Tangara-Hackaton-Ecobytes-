import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/dashboard/domain/models/sector.dart';
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

/// Cliente HTTP encargado de consumir el backend de EcoBytes.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _timeout = Duration(seconds: 15);

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

  Future<Riesgo> getRiesgo(String sectorId) async {
    final json = await _getJson('/risk/$sectorId');
    return Riesgo.fromJson(json);
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
}
