import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';

/// Estado de calidad del aire de un sector, tal como lo reporta el backend.
enum EstadoSector { verde, amarillo, rojo, gris }

extension EstadoSectorX on EstadoSector {
  /// Convierte el valor textual del backend a [EstadoSector].
  /// Cualquier valor desconocido o nulo se trata como "sin datos" (gris).
  static EstadoSector fromApi(String? valor) {
    switch (valor) {
      case 'verde':
        return EstadoSector.verde;
      case 'amarillo':
        return EstadoSector.amarillo;
      case 'rojo':
        return EstadoSector.rojo;
      default:
        return EstadoSector.gris;
    }
  }

  Color get color {
    switch (this) {
      case EstadoSector.verde:
        return AppColors.statusGood;
      case EstadoSector.amarillo:
        return AppColors.statusModerate;
      case EstadoSector.rojo:
        return AppColors.statusBad;
      case EstadoSector.gris:
        return AppColors.textMuted;
    }
  }

  String get label {
    switch (this) {
      case EstadoSector.verde:
        return 'Buena';
      case EstadoSector.amarillo:
        return 'Moderada';
      case EstadoSector.rojo:
        return 'Dañina';
      case EstadoSector.gris:
        return 'Sin datos';
    }
  }
}

/// Clasifica un valor crudo de PM2.5 (ej. un promedio calculado en el
/// frontend, como el promedio ciudad) en (etiqueta, color) usando los mismos
/// umbrales OMS que aplica el backend en `_estado_por_pm25`
/// (`Backend/config.py`: `PM25_UMBRAL_BUENO=15`, `PM25_UMBRAL_MODERADO=35`).
/// Para el `estado` de un sector individual siempre hay que preferir el que
/// ya viene del backend (`Sector.estado`) — esta función es solo para números
/// que el backend no clasifica por sí mismo.
({String label, Color color}) estadoDesdePm25(double pm25) {
  if (pm25 < 15) return (label: 'Buena', color: AppColors.statusGood);
  if (pm25 <= 35) return (label: 'Moderada', color: AppColors.statusModerate);
  return (label: 'Dañina', color: AppColors.statusBad);
}

/// Representa un sector (comuna) de Cali con su geometría y estado de
/// calidad del aire, tal como llega de `GET /sectors`.
class Sector {
  const Sector({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.pm25Promedio,
    required this.ultimaLectura,
    required this.sinDatosRecientes,
    required this.poligonos,
  });

  final String id;
  final String nombre;
  final EstadoSector estado;
  final double? pm25Promedio;
  final DateTime? ultimaLectura;
  final bool sinDatosRecientes;

  /// Lista de anillos exteriores (uno por polígono del MultiPolygon),
  /// ya convertidos a [LatLng] en el orden esperado por flutter_map.
  final List<List<LatLng>> poligonos;

  /// Si el sector tiene una medición actual y confiable que mostrar.
  ///
  /// Hay que comprobar las dos condiciones: `sinDatosRecientes` indica que el
  /// dato no es actual, pero **no** garantiza que `pm25Promedio` sea nulo — un
  /// sector con sensores cuya última lectura es vieja llega en gris y con el
  /// último valor conocido (ver `routers/sectors.py` y
  /// `07-Integracion-Backend-Frontend.md` §3).
  bool get tieneDatos => !sinDatosRecientes && pm25Promedio != null;

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      estado: EstadoSectorX.fromApi(json['estado'] as String?),
      pm25Promedio: (json['pm25_promedio'] as num?)?.toDouble(),
      ultimaLectura: _parseFecha(json['ultima_lectura'] as String?),
      sinDatosRecientes: json['sin_datos_recientes'] as bool? ?? true,
      poligonos: _parseMultiPolygon(json['geometry']),
    );
  }

  static DateTime? _parseFecha(String? valor) {
    if (valor == null) return null;
    return DateTime.tryParse(valor);
  }

  /// Extrae solo el anillo exterior de cada polígono de un GeoJSON
  /// MultiPolygon. Es defensivo: ante cualquier estructura inesperada
  /// devuelve una lista vacía en lugar de lanzar una excepción.
  static List<List<LatLng>> _parseMultiPolygon(dynamic geometry) {
    try {
      if (geometry == null) return [];
      final map = geometry as Map<String, dynamic>;
      if (map['type'] != 'MultiPolygon') return [];
      final coordinates = map['coordinates'] as List?;
      if (coordinates == null) return [];

      final poligonos = <List<LatLng>>[];
      for (final poligono in coordinates) {
        final anillos = poligono as List?;
        if (anillos == null || anillos.isEmpty) continue;
        final anilloExterior = anillos[0] as List?;
        if (anilloExterior == null) continue;

        final puntos = <LatLng>[];
        for (final coordenada in anilloExterior) {
          final par = coordenada as List;
          final lon = (par[0] as num).toDouble();
          final lat = (par[1] as num).toDouble();
          puntos.add(LatLng(lat, lon));
        }
        if (puntos.isNotEmpty) poligonos.add(puntos);
      }
      return poligonos;
    } catch (_) {
      return [];
    }
  }
}

/// Promedio de PM2.5 de una hora específica, parte del historial corto
/// (`historial_24h`) que trae `GET /sectors/{id}`.
class HoraPromedio {
  const HoraPromedio({required this.hora, required this.pm25Promedio});

  final DateTime? hora;
  final double? pm25Promedio;

  factory HoraPromedio.fromJson(Map<String, dynamic> json) {
    return HoraPromedio(
      hora: json['hora'] != null ? DateTime.tryParse(json['hora'] as String) : null,
      pm25Promedio: (json['pm25_promedio'] as num?)?.toDouble(),
    );
  }
}

/// Detalle de un sector obtenido de `GET /sectors/{id}`.
class SectorDetalle {
  const SectorDetalle({
    required this.id,
    required this.nombre,
    required this.pm25Promedio,
    required this.co2Promedio,
    required this.humPromedio,
    required this.ultimaLectura,
    required this.sinDatosRecientes,
    required this.estado,
    required this.historial24h,
  });

  final String id;
  final String nombre;
  final double? pm25Promedio;
  final double? co2Promedio;
  final double? humPromedio;
  final DateTime? ultimaLectura;
  final bool sinDatosRecientes;
  final EstadoSector estado;

  /// Promedio de PM2.5 por hora de las últimas ~24h. Puede llegar vacío si
  /// el sector no tiene sensores o ninguno tuvo lecturas en la ventana — en
  /// ese caso la UI debe mostrarlo explícitamente, nunca inventar puntos.
  final List<HoraPromedio> historial24h;

  factory SectorDetalle.fromJson(Map<String, dynamic> json) {
    return SectorDetalle(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      pm25Promedio: (json['pm25_promedio'] as num?)?.toDouble(),
      co2Promedio: (json['co2_promedio'] as num?)?.toDouble(),
      humPromedio: (json['hum_promedio'] as num?)?.toDouble(),
      ultimaLectura: json['ultima_lectura'] != null
          ? DateTime.tryParse(json['ultima_lectura'] as String)
          : null,
      sinDatosRecientes: json['sin_datos_recientes'] as bool? ?? true,
      estado: EstadoSectorX.fromApi(json['estado'] as String?),
      historial24h: ((json['historial_24h'] as List?) ?? [])
          .map((e) => HoraPromedio.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Un sensor individual dentro de un sector, tal como llega de
/// `GET /sectors/{id}/sensores`. A diferencia de [SectorDetalle] (promedios
/// agregados del sector), esto es la lectura de un sensor puntual.
class SensorDeSector {
  const SensorDeSector({
    required this.nombre,
    required this.lat,
    required this.lon,
    required this.pm25Promedio,
    required this.co2Promedio,
    required this.humPromedio,
    required this.ultimaLectura,
    required this.estado,
    required this.sinDatosRecientes,
  });

  final String nombre;
  final double? lat;
  final double? lon;
  final double? pm25Promedio;
  final double? co2Promedio;
  final double? humPromedio;
  final DateTime? ultimaLectura;
  final EstadoSector estado;

  /// Un sensor puede estar en el mapeo sensor→sector (se conoce su
  /// existencia) pero sin ninguna lectura en la última hora — en ese caso
  /// llega sin `lat`/`lon` tampoco, porque el backend no hace una consulta
  /// extra solo para ubicar sensores inactivos.
  final bool sinDatosRecientes;

  bool get tieneDatos => !sinDatosRecientes && pm25Promedio != null;

  factory SensorDeSector.fromJson(Map<String, dynamic> json) {
    return SensorDeSector(
      nombre: json['nombre'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      pm25Promedio: (json['pm25_promedio'] as num?)?.toDouble(),
      co2Promedio: (json['co2_promedio'] as num?)?.toDouble(),
      humPromedio: (json['hum_promedio'] as num?)?.toDouble(),
      ultimaLectura: json['ultima_lectura'] != null
          ? DateTime.tryParse(json['ultima_lectura'] as String)
          : null,
      estado: EstadoSectorX.fromApi(json['estado'] as String?),
      sinDatosRecientes: json['sin_datos_recientes'] as bool? ?? true,
    );
  }
}
