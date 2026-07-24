import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/data/api_client.dart';
import '../../domain/models/sector.dart';

/// Estado de carga de la lista de sectores.
enum EstadoCarga { cargando, listo, error }

/// Mantiene la lista de sectores de Cali sincronizada con el backend,
/// refrescándola periódicamente mediante polling.
class SectorsProvider extends ChangeNotifier {
  SectorsProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const _intervaloPolling = Duration(seconds: 45);

  EstadoCarga _estado = EstadoCarga.cargando;
  List<Sector> _sectores = [];
  String? _mensajeError;
  DateTime? _ultimaActualizacion;
  String? _sectorSeleccionadoId;
  Timer? _timer;

  /// Evita notificar tras `dispose()`: el timer se cancela ahí, pero una
  /// petición ya en vuelo puede resolverse después y `notifyListeners()`
  /// sobre un ChangeNotifier destruido lanza en modo debug.
  bool _destruido = false;

  /// Evita peticiones simultáneas (ej. doble tap en "Reintentar").
  bool _peticionEnCurso = false;

  EstadoCarga get estado => _estado;
  List<Sector> get sectores => _sectores;
  String? get mensajeError => _mensajeError;
  DateTime? get ultimaActualizacion => _ultimaActualizacion;

  Sector? get sectorSeleccionado {
    if (_sectorSeleccionadoId == null) return null;
    for (final sector in _sectores) {
      if (sector.id == _sectorSeleccionadoId) return sector;
    }
    return null;
  }

  void seleccionarSector(String? id) {
    _sectorSeleccionadoId = id;
    notifyListeners();
  }

  /// Carga inicial de sectores. Muestra el estado "cargando" y arranca
  /// el polling periódico.
  Future<void> cargar() async {
    if (_peticionEnCurso) return;

    _estado = EstadoCarga.cargando;
    _mensajeError = null;
    notifyListeners();

    await _fetch();
    _iniciarPolling();
  }

  void _iniciarPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_intervaloPolling, (_) => _fetch());
  }

  /// Obtiene los sectores del backend. Nunca vuelve a poner el estado en
  /// "cargando" tras la carga inicial (evita parpadeos en el polling):
  /// si un refresco falla, se conservan los datos previos y solo se
  /// expone el mensaje de error.
  Future<void> _fetch() async {
    if (_peticionEnCurso) return;
    _peticionEnCurso = true;

    try {
      final sectores = await _apiClient.getSectores();
      _sectores = sectores;
      _estado = EstadoCarga.listo;
      _mensajeError = null;
      _ultimaActualizacion = DateTime.now();
    } on ApiException catch (e) {
      _mensajeError = e.mensaje;
      if (_sectores.isEmpty) {
        _estado = EstadoCarga.error;
      }
    } catch (_) {
      _mensajeError = 'Ocurrió un error inesperado al cargar los sectores.';
      if (_sectores.isEmpty) {
        _estado = EstadoCarga.error;
      }
    } finally {
      _peticionEnCurso = false;
    }

    if (_destruido) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    _timer?.cancel();
    super.dispose();
  }
}
