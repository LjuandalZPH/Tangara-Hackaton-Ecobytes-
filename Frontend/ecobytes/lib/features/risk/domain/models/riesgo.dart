/// Representa el promedio de PM2.5 de un mes específico.
class MesPromedio {
  const MesPromedio({required this.mes, required this.promedio});

  final String mes;
  final double? promedio;

  factory MesPromedio.fromJson(Map<String, dynamic> json) {
    return MesPromedio(
      mes: json['mes'] as String? ?? '',
      promedio: (json['promedio'] as num?)?.toDouble(),
    );
  }
}

/// Datos de riesgo histórico de un sector, obtenidos de `GET /risk/{sector}`.
class Riesgo {
  const Riesgo({
    required this.sector,
    required this.promedioAnual,
    required this.peorMes,
    required this.mejorMes,
    required this.diasSobreLimiteOms,
    required this.historicoSuficiente,
  });

  final String sector;
  final double? promedioAnual;
  final MesPromedio? peorMes;
  final MesPromedio? mejorMes;
  final int diasSobreLimiteOms;
  final bool historicoSuficiente;

  factory Riesgo.fromJson(Map<String, dynamic> json) {
    return Riesgo(
      sector: json['sector'] as String? ?? '',
      promedioAnual: (json['promedio_anual'] as num?)?.toDouble(),
      peorMes: json['peor_mes'] != null
          ? MesPromedio.fromJson(json['peor_mes'] as Map<String, dynamic>)
          : null,
      mejorMes: json['mejor_mes'] != null
          ? MesPromedio.fromJson(json['mejor_mes'] as Map<String, dynamic>)
          : null,
      diasSobreLimiteOms: json['dias_sobre_limite_oms_ultimo_anio'] as int? ?? 0,
      historicoSuficiente: json['historico_suficiente'] as bool? ?? false,
    );
  }
}
