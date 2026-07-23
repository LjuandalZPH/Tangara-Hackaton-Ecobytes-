import 'package:flutter/foundation.dart';

import '../../../../core/data/api_client.dart';
import '../../domain/models/riesgo.dart';

/// Estado de carga del riesgo de un sector.
enum EstadoRiesgo { inicial, cargando, listo, error }

/// Obtiene el riesgo histórico de un sector bajo demanda (sin polling),
/// con una caché simple en memoria por sectorId.
class RiskProvider extends ChangeNotifier {
  RiskProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final Map<String, Riesgo> _cache = {};

  EstadoRiesgo _estado = EstadoRiesgo.inicial;
  Riesgo? _riesgo;
  String? _mensajeError;
  String? _sectorActual;

  EstadoRiesgo get estado => _estado;
  Riesgo? get riesgo => _riesgo;
  String? get mensajeError => _mensajeError;
  String? get sectorActual => _sectorActual;

  Future<void> cargarRiesgo(String sectorId) async {
    _sectorActual = sectorId;

    final enCache = _cache[sectorId];
    if (enCache != null) {
      _riesgo = enCache;
      _estado = EstadoRiesgo.listo;
      _mensajeError = null;
      notifyListeners();
      return;
    }

    _estado = EstadoRiesgo.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final riesgo = await _apiClient.getRiesgo(sectorId);
      _cache[sectorId] = riesgo;
      _riesgo = riesgo;
      _estado = EstadoRiesgo.listo;
    } on ApiException catch (e) {
      _mensajeError = e.mensaje;
      _estado = EstadoRiesgo.error;
    } catch (_) {
      _mensajeError = 'Ocurrió un error inesperado al cargar el riesgo.';
      _estado = EstadoRiesgo.error;
    }
    notifyListeners();
  }
}
