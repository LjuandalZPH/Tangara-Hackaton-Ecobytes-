import 'package:flutter/foundation.dart';

import '../../../../core/data/api_client.dart';
import '../../domain/models/sector.dart';

/// Estado de carga del detalle de un sector.
enum EstadoDetalle { inicial, cargando, listo, error }

/// Estado de carga de los sensores individuales de un sector.
enum EstadoSensores { inicial, cargando, listo, error }

/// Obtiene el detalle de un sector (`GET /sectors/{id}`) y sus sensores
/// individuales (`GET /sectors/{id}/sensores`) bajo demanda, con una caché
/// simple en memoria por sectorId — mismo patrón que RiskProvider. Los dos
/// se cargan y cachean por separado: que falle uno no debe bloquear al otro,
/// ya que alimentan pestañas distintas (Resumen / Sensores).
class SectorDetailProvider extends ChangeNotifier {
  SectorDetailProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final Map<String, SectorDetalle> _cache = {};
  final Map<String, List<SensorDeSector>> _cacheSensores = {};

  EstadoDetalle _estado = EstadoDetalle.inicial;
  SectorDetalle? _detalle;
  String? _mensajeError;
  String? _sectorActual;

  EstadoSensores _estadoSensores = EstadoSensores.inicial;
  List<SensorDeSector> _sensores = [];
  String? _mensajeErrorSensores;

  EstadoDetalle get estado => _estado;
  SectorDetalle? get detalle => _detalle;
  String? get mensajeError => _mensajeError;
  String? get sectorActual => _sectorActual;

  EstadoSensores get estadoSensores => _estadoSensores;
  List<SensorDeSector> get sensores => _sensores;
  String? get mensajeErrorSensores => _mensajeErrorSensores;

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

  Future<void> cargarSensores(String sectorId) async {
    _sectorActual = sectorId;

    final enCache = _cacheSensores[sectorId];
    if (enCache != null) {
      _sensores = enCache;
      _estadoSensores = EstadoSensores.listo;
      _mensajeErrorSensores = null;
      notifyListeners();
      return;
    }

    _estadoSensores = EstadoSensores.cargando;
    _mensajeErrorSensores = null;
    notifyListeners();

    try {
      final sensores = await _apiClient.getSensoresDeSector(sectorId);
      _cacheSensores[sectorId] = sensores;
      _sensores = sensores;
      _estadoSensores = EstadoSensores.listo;
    } on ApiException catch (e) {
      _mensajeErrorSensores = e.mensaje;
      _estadoSensores = EstadoSensores.error;
    } catch (_) {
      _mensajeErrorSensores = 'Ocurrió un error inesperado al cargar los sensores.';
      _estadoSensores = EstadoSensores.error;
    }
    notifyListeners();
  }
}
