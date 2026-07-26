"""
Snapshot de sectores: construye la misma lista de 22 comunas con su
estado actual que consume `GET /sectors` (routers/sectors.py), pero como
función de servicio reutilizable — la necesita también el chatbot
(services/chatbot_context.py) para saber qué comunas están en rojo,
amarillo, verde o gris sin depender de un `Request` de FastAPI.
"""

from datetime import datetime, timezone

from config import (
    MAX_ANTIGUEDAD_LECTURA_SEGUNDOS,
    PM25_UMBRAL_BUENO,
    PM25_UMBRAL_MODERADO,
)
from services import clickhouse_client
from services.geo import SectorIndex, obtener_mapeo_sensor_sector


def estado_por_pm25(pm25: float | None) -> str:
    """
    Clasifica el estado según umbrales OMS de PM2.5 (ver config.py):
    verde (bueno) / amarillo (moderado) / rojo (dañino).
    """
    if pm25 is None:
        return "gris"
    if pm25 < PM25_UMBRAL_BUENO:
        return "verde"
    if pm25 <= PM25_UMBRAL_MODERADO:
        return "amarillo"
    return "rojo"


def es_reciente(ultima_lectura) -> bool:
    if ultima_lectura is None:
        return False
    if ultima_lectura.tzinfo is None:
        ultima_lectura = ultima_lectura.replace(tzinfo=timezone.utc)
    antiguedad = (datetime.now(timezone.utc) - ultima_lectura).total_seconds()
    return antiguedad <= MAX_ANTIGUEDAD_LECTURA_SEGUNDOS


async def construir_sectores(sector_index: SectorIndex) -> list[dict]:
    """
    Construye la lista de sectores (id, nombre, geometry, pm25_promedio,
    estado, ultima_lectura, sin_datos_recientes) para las 22 comunas.

    Recibe el `sector_index` en vez de un `Request` de FastAPI para poder
    usarse fuera de un router (p. ej. desde el chatbot).
    """
    mapeo_sensor_sector = await obtener_mapeo_sensor_sector(sector_index)

    lecturas = await clickhouse_client.ultimo_promedio_por_sensor()

    # Agrupa las lecturas de sensores por sector
    por_sector: dict[str, list[dict]] = {}
    for lectura in lecturas:
        sector_id = mapeo_sensor_sector.get(lectura["name"])
        if sector_id is None:
            continue
        por_sector.setdefault(sector_id, []).append(lectura)

    sectores_respuesta = []
    for sector in sector_index.sectores:
        lecturas_sector = por_sector.get(sector["id"], [])

        if not lecturas_sector:
            sectores_respuesta.append(
                {
                    "id": sector["id"],
                    "nombre": sector["nombre"],
                    "geometry": sector["geometry"],
                    "pm25_promedio": None,
                    "estado": "gris",
                    "ultima_lectura": None,
                    "sin_datos_recientes": True,
                }
            )
            continue

        pm25_valores = [l["pm25_promedio"] for l in lecturas_sector if l["pm25_promedio"] is not None]
        pm25_promedio = sum(pm25_valores) / len(pm25_valores) if pm25_valores else None
        ultima_lectura = max(l["ultima_lectura"] for l in lecturas_sector)
        reciente = es_reciente(ultima_lectura)

        sectores_respuesta.append(
            {
                "id": sector["id"],
                "nombre": sector["nombre"],
                "geometry": sector["geometry"],
                "pm25_promedio": pm25_promedio,
                "estado": estado_por_pm25(pm25_promedio) if reciente else "gris",
                "ultima_lectura": ultima_lectura,
                "sin_datos_recientes": not reciente,
            }
        )

    return sectores_respuesta
