import 'package:flutter/foundation.dart';

import '../../../../core/data/api_client.dart';
import '../../domain/models/sector.dart';

/// Estado de carga del detalle de un sector.
enum EstadoDetalle { inicial, cargando, listo, error }

/// Obtiene el detalle de un sector (`GET /sectors/{id}`) bajo demanda, con
/// una caché simple en memoria por sectorId — mismo patrón que RiskProvider.
class SectorDetailProvider extends ChangeNotifier {
  SectorDetailProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final Map<String, SectorDetalle> _cache = {};

  EstadoDetalle _estado = EstadoDetalle.inicial;
  SectorDetalle? _detalle;
  String? _mensajeError;
  String? _sectorActual;

  EstadoDetalle get estado => _estado;
  SectorDetalle? get detalle => _detalle;
  String? get mensajeError => _mensajeError;
  String? get sectorActual => _sectorActual;

  Future<void> cargarDetalle(String sectorId) async {
    _sectorActual = sectorId;

    final enCache = _cache[sectorId];
    if (enCache != null) {
      _detalle = enCache;
      _estado = EstadoDetalle.listo;
      _mensajeError = null;
      notifyListeners();
      return;
    }

    _estado = EstadoDetalle.cargando;
    _mensajeError = null;
    notifyListeners();

    try {
      final detalle = await _apiClient.getSectorDetalle(sectorId);
      _cache[sectorId] = detalle;
      _detalle = detalle;
      _estado = EstadoDetalle.listo;
    } on ApiException catch (e) {
      _mensajeError = e.mensaje;
      _estado = EstadoDetalle.error;
    } catch (_) {
      _mensajeError = 'Ocurrió un error inesperado al cargar el sector.';
      _estado = EstadoDetalle.error;
    }
    notifyListeners();
  }
}
