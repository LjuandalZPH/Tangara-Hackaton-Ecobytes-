import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/data/api_client.dart';
import '../../domain/models/contenido_educativo.dart';

/// Estado de carga del contenido educativo.
enum EstadoEducacion { inicial, cargando, listo, error }

/// Ruta del asset de respaldo: una copia literal de `Backend/data/educacion.json`
/// versionada en el repo. Ver `Backend/data/README.md`.
const _rutaAssetRespaldo = 'assets/educacion.json';

/// Mantiene el contenido de la pantalla "Aprende" (`GET /education`).
///
/// A diferencia del mapa, no hay polling: el contenido es estático y se carga
/// una sola vez, bajo demanda.
///
/// **Respaldo offline.** Antes de darse por vencido, intenta leer una copia
/// del contenido empaquetada como asset. Es la única pantalla del producto que
/// antes se veía sin backend, y perder eso al conectarla habría sido un
/// retroceso. Cuando se usa el respaldo, [desdeFallback] queda en `true` y la
/// pantalla lo dice: contenido congelado presentado como fresco sería el mismo
/// problema que este trabajo vino a resolver.
class EducationProvider extends ChangeNotifier {
  EducationProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  EstadoEducacion _estado = EstadoEducacion.inicial;
  ContenidoEducativo? _contenido;
  String? _mensajeError;
  bool _desdeFallback = false;
  bool _peticionEnCurso = false;

  /// `cargar()` hace dos `await` seguidos (red y, si falla, el asset). Si el
  /// usuario sale de /aprende mientras tanto, el provider puede haberse
  /// destruido antes de que terminen, y `notifyListeners()` sobre un
  /// ChangeNotifier ya destruido lanza en modo debug.
  bool _destruido = false;

  EstadoEducacion get estado => _estado;
  ContenidoEducativo? get contenido => _contenido;
  String? get mensajeError => _mensajeError;

  /// `true` si lo que se está mostrando salió del asset local y no del backend.
  bool get desdeFallback => _desdeFallback;

  /// Carga el contenido. Es idempotente: si ya se cargó desde la red, volver a
  /// `/aprende` no repite la petición ni hace parpadear la pantalla.
  ///
  /// Si la carga anterior vino del respaldo, sí reintenta contra la red — así
  /// el botón "Reintentar" del aviso sirve de algo.
  Future<void> cargar() async {
    if (_peticionEnCurso) return;
    if (_estado == EstadoEducacion.listo && !_desdeFallback) return;

    _peticionEnCurso = true;
    _estado = EstadoEducacion.cargando;
    _mensajeError = null;
    if (_destruido) return;
    notifyListeners();

    try {
      _contenido = await _apiClient.getContenidoEducativo();
      _estado = EstadoEducacion.listo;
      _desdeFallback = false;
      _mensajeError = null;
    } on ApiException catch (e) {
      await _intentarRespaldo(e.mensaje);
    } catch (_) {
      await _intentarRespaldo('Ocurrió un error inesperado al cargar el contenido.');
    } finally {
      _peticionEnCurso = false;
    }

    if (_destruido) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }

  /// Segundo intento, contra el asset local. Solo si este también falla se
  /// muestra el estado de error: el asset podría faltar en un build mal hecho.
  Future<void> _intentarRespaldo(String errorDeRed) async {
    try {
      final crudo = await rootBundle.loadString(_rutaAssetRespaldo);
      _contenido = ContenidoEducativo.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      _estado = EstadoEducacion.listo;
      _desdeFallback = true;
      _mensajeError = errorDeRed;
    } catch (_) {
      _estado = EstadoEducacion.error;
      _desdeFallback = false;
      _mensajeError = errorDeRed;
    }
  }
}
