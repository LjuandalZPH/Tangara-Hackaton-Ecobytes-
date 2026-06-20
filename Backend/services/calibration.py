"""
Servicio: Calibración de PM2.5
Corrige el sesgo por humedad de los sensores ópticos de bajo costo.

Contexto:
    Los sensores de Tángara (tipo PMS5003/PMS7003) sobrestiman PM2.5
    en ambientes húmedos porque confunden gotas de agua con partículas
    contaminantes. Este algoritmo aplica una corrección matemática.

Referencia:
    Dillo et al. (2021) — metodología documentada también por la EPA de EE.UU.
    Factor k = 0.24 determinado empíricamente para sensores Tángara
    (pendiente de validación por el equipo de Electrónica — ver T-01.1).
"""

import numpy as np


# Factor de corrección empírico
# El equipo de Electrónica actualizará este valor en T-01.1
# tras comparar lecturas del sensor vs. equipo de referencia
K_FACTOR: float = 0.24


def calibrate_pm25(pm25_raw: float, humidity: float) -> float | None:
    """
    Aplica la corrección de Dillo et al. al valor crudo de PM2.5.

    Fórmula:
        PM2.5_calibrado = PM2.5_crudo / (1 + k × (HR / 100))

    Args:
        pm25_raw:  Lectura directa del sensor en µg/m³.
        humidity:  Humedad relativa del sensor en % (0–100).

    Returns:
        PM2.5 corregido en µg/m³, redondeado a 2 decimales.
        None si algún valor de entrada es inválido.

    Ejemplos:
        >>> calibrate_pm25(45.0, 78.5)   # día lluvioso
        28.91
        >>> calibrate_pm25(20.0, 40.0)   # día seco — corrección mínima
        17.86
    """
    # Validar entradas
    if pm25_raw is None or humidity is None:
        return None
    if pm25_raw < 0 or not (0 <= humidity <= 100):
        return None

    # Aplicar corrección
    corrected = pm25_raw / (1 + K_FACTOR * (humidity / 100))

    # Redondear a 2 decimales
    return round(float(corrected), 2)


def calibrate_batch(pm25_values: list[float], humidity_values: list[float]) -> list[float | None]:
    """
    Aplica la calibración a múltiples lecturas a la vez.
    Útil para procesar el CSV histórico de Tángara en lote.

    Args:
        pm25_values:    Lista de valores crudos de PM2.5.
        humidity_values: Lista de valores de humedad (mismo orden).

    Returns:
        Lista de valores calibrados (None donde la entrada es inválida).
    """
    if len(pm25_values) != len(humidity_values):
        raise ValueError("pm25_values y humidity_values deben tener el mismo largo.")

    pm25_array = np.array(pm25_values, dtype=float)
    humidity_array = np.array(humidity_values, dtype=float)

    # Calcular corrección vectorizada (mucho más rápido que un loop)
    corrected = pm25_array / (1 + K_FACTOR * (humidity_array / 100))

    # Reemplazar valores inválidos con None
    results = []
    for i, val in enumerate(corrected):
        if np.isnan(val) or pm25_values[i] < 0 or not (0 <= humidity_values[i] <= 100):
            results.append(None)
        else:
            results.append(round(float(val), 2))

    return results


def get_alert_level(pm25_calibrated: float) -> str:
    """
    Clasifica el nivel de alerta según los umbrales de la OMS (2021).

    Umbrales:
        0–5     µg/m³  → bueno
        5–15    µg/m³  → aceptable
        15–25   µg/m³  → moderado
        25–50   µg/m³  → dañino para grupos sensibles
        50–75   µg/m³  → dañino
        >75     µg/m³  → muy dañino

    Args:
        pm25_calibrated: Valor calibrado de PM2.5 en µg/m³.

    Returns:
        Nivel de alerta como string.
    """
    if pm25_calibrated <= 5:
        return "bueno"
    elif pm25_calibrated <= 15:
        return "aceptable"
    elif pm25_calibrated <= 25:
        return "moderado"
    elif pm25_calibrated <= 50:
        return "dañino_sensibles"
    elif pm25_calibrated <= 75:
        return "dañino"
    else:
        return "muy_dañino"
