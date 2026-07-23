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
  });

  final String id;
  final String nombre;
  final double? pm25Promedio;
  final double? co2Promedio;
  final double? humPromedio;
  final DateTime? ultimaLectura;
  final bool sinDatosRecientes;
  final EstadoSector estado;

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
    );
  }
}
