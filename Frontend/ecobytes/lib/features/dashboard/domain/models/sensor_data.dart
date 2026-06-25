import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum AirQualityLevel { excellent, good, moderate, poor, bad }

extension AirQualityLevelX on AirQualityLevel {
  Color get color {
    switch (this) {
      case AirQualityLevel.excellent:
        return const Color(0xFF2E7D32);
      case AirQualityLevel.good:
        return const Color(0xFF66BB6A);
      case AirQualityLevel.moderate:
        return const Color(0xFFF9A825);
      case AirQualityLevel.poor:
        return const Color(0xFFEF6C00);
      case AirQualityLevel.bad:
        return const Color(0xFFD32F2F);
    }
  }

  String get label {
    switch (this) {
      case AirQualityLevel.excellent:
        return 'Excelente';
      case AirQualityLevel.good:
        return 'Bueno';
      case AirQualityLevel.moderate:
        return 'Moderado';
      case AirQualityLevel.poor:
        return 'Malo';
      case AirQualityLevel.bad:
        return 'Muy malo';
    }
  }
}

class SensorMetric extends Equatable {
  const SensorMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.statusLabel,
    required this.statusColor,
    this.progress,
  });

  final String label;
  final String value;
  final String unit;
  final String statusLabel;
  final Color statusColor;
  final double? progress;

  @override
  List<Object?> get props =>
      [label, value, unit, statusLabel, statusColor, progress];
}

class FeaturedSensor extends Equatable {
  const FeaturedSensor({
    required this.name,
    required this.aqi,
    required this.level,
  });

  final String name;
  final int aqi;
  final AirQualityLevel level;

  @override
  List<Object?> get props => [name, aqi, level];
}

class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.updatedMinutesAgo,
    required this.generalQuality,
    required this.averageAqi,
    required this.keyIndicators,
    required this.featuredSensors,
  });

  final int updatedMinutesAgo;
  final AirQualityLevel generalQuality;
  final int averageAqi;
  final List<SensorMetric> keyIndicators;
  final List<FeaturedSensor> featuredSensors;

  @override
  List<Object?> get props => [
        updatedMinutesAgo,
        generalQuality,
        averageAqi,
        keyIndicators,
        featuredSensors,
      ];
}

class LandingMetrics extends Equatable {
  const LandingMetrics({
    required this.pm25,
    required this.co2,
    required this.humidity,
  });

  final SensorMetric pm25;
  final SensorMetric co2;
  final SensorMetric humidity;

  @override
  List<Object?> get props => [pm25, co2, humidity];
}
