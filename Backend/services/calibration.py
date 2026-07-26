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

⚠️ RIESGO ABIERTO — posible doble calibración:
    Nadie ha verificado todavía si el pipeline de Tángara ya aplica esta
    misma corrección aguas arriba, al construir la capa Plata. Si lo
    hiciera, aquí se estaría corrigiendo dos veces y los valores saldrían
    artificialmente bajos. Ver docs/backlog.md.

Este módulo es lógica de dominio pura: no importa FastAPI ni ClickHouse.
Se aplica una sola vez, en `services/clickhouse_client.py`, para que el
PM2.5 crudo nunca llegue a los routers.
"""

# Factor de corrección empírico.
# El equipo de Electrónica actualizará este valor en T-01.1 tras comparar
# lecturas del sensor contra un equipo de referencia.
K_FACTOR: float = 0.24


def calibrar_pm25(pm25_crudo: float | None, humedad: float | None) -> float | None:
    """
    Aplica la corrección de Dillo et al. al valor crudo de PM2.5.

    Fórmula:
        PM2.5_calibrado = PM2.5_crudo / (1 + k × (HR / 100))

    Args:
        pm25_crudo: Lectura directa del sensor en µg/m³.
        humedad:    Humedad relativa del sensor en % (0–100).

    Returns:
        PM2.5 corregido en µg/m³, redondeado a 2 decimales.
        `None` si falta algún dato o está fuera de rango — incluido el caso
        de humedad ausente, porque sin ella no hay corrección posible y
        devolver el crudo sería presentar un dato sin calibrar como si lo
        estuviera.

    Ejemplos (verificados; los del original en develop no cuadraban con k=0.24):
        >>> calibrar_pm25(45.0, 78.5)   # día húmedo
        37.87
        >>> calibrar_pm25(20.0, 40.0)   # día seco — corrección mínima
        18.25
    """
    if pm25_crudo is None or humedad is None:
        return None
    if pm25_crudo < 0 or not (0 <= humedad <= 100):
        return None

    corregido = pm25_crudo / (1 + K_FACTOR * (humedad / 100))
    return round(float(corregido), 2)
