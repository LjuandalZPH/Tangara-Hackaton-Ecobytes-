import '../../../../core/constants/app_colors.dart';
import '../../domain/models/sensor_data.dart';

/// Datos mock preparados para ser reemplazados por un Bloc/Provider
/// conectado a la API de sensores en tiempo real.
abstract final class MockSensorRepository {
  static LandingMetrics get landingMetrics => LandingMetrics(
        pm25: SensorMetric(
          label: 'PM2.5',
          value: '12',
          unit: 'µg/m³',
          statusLabel: 'Excelente',
          statusColor: AppColors.statusExcellent,
        ),
        co2: SensorMetric(
          label: 'CO₂',
          value: '418',
          unit: 'ppm',
          statusLabel: 'Moderado',
          statusColor: AppColors.statusModerate,
        ),
        humidity: SensorMetric(
          label: 'Humedad',
          value: '72',
          unit: '%',
          statusLabel: 'Óptimo',
          statusColor: AppColors.statusOptimal,
        ),
      );

  static DashboardSnapshot get dashboardSnapshot => DashboardSnapshot(
        updatedMinutesAgo: 2,
        generalQuality: AirQualityLevel.good,
        averageAqi: 32,
        keyIndicators: [
          SensorMetric(
            label: 'PM2.5',
            value: '12',
            unit: 'µg/m³',
            statusLabel: 'Bueno',
            statusColor: AppColors.statusGood,
            progress: 0.35,
          ),
          SensorMetric(
            label: 'CO₂',
            value: '418',
            unit: 'ppm',
            statusLabel: 'Moderado',
            statusColor: AppColors.statusModerate,
            progress: 0.55,
          ),
          SensorMetric(
            label: 'Humedad',
            value: '72',
            unit: '%',
            statusLabel: 'Óptimo',
            statusColor: AppColors.statusOptimal,
            progress: 0.72,
          ),
        ],
        featuredSensors: const [
          FeaturedSensor(
            name: 'Parque del Amor',
            aqi: 18,
            level: AirQualityLevel.excellent,
          ),
          FeaturedSensor(
            name: 'Zona Industrial',
            aqi: 84,
            level: AirQualityLevel.poor,
          ),
          FeaturedSensor(
            name: 'La Flora',
            aqi: 42,
            level: AirQualityLevel.good,
          ),
        ],
      );
}
