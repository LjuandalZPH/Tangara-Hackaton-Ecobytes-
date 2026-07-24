"""
Router: Sectores
GET /sectors       — todos los sectores con su estado actual (para el mapa).
GET /sectors/{id}  — detalle (pm25, co2, hum, timestamp) de un sector.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request

from config import (
    HORAS_HISTORIAL_SECTOR,
    MAX_ANTIGUEDAD_LECTURA_SEGUNDOS,
    PM25_UMBRAL_BUENO,
    PM25_UMBRAL_MODERADO,
)
from services import clickhouse_client
from services.cache import sectors_cache
from services.geo import obtener_mapeo_sensor_sector

router = APIRouter()


def _estado_por_pm25(pm25: float | None) -> str:
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


def _es_reciente(ultima_lectura) -> bool:
    if ultima_lectura is None:
        return False
    if ultima_lectura.tzinfo is None:
        ultima_lectura = ultima_lectura.replace(tzinfo=timezone.utc)
    antiguedad = (datetime.now(timezone.utc) - ultima_lectura).total_seconds()
    return antiguedad <= MAX_ANTIGUEDAD_LECTURA_SEGUNDOS


async def _construir_sectores(request: Request) -> list[dict]:
    sector_index = request.app.state.sector_index
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
        reciente = _es_reciente(ultima_lectura)

        sectores_respuesta.append(
            {
                "id": sector["id"],
                "nombre": sector["nombre"],
                "geometry": sector["geometry"],
                "pm25_promedio": pm25_promedio,
                "estado": _estado_por_pm25(pm25_promedio) if reciente else "gris",
                "ultima_lectura": ultima_lectura,
                "sin_datos_recientes": not reciente,
            }
        )

    return sectores_respuesta


@router.get("")
async def get_sectors(request: Request):
    """Todos los sectores con su color/estado actual, para pintar el mapa. Cacheado 30s."""
    cacheado = sectors_cache.get("sectores")
    if cacheado is not None:
        return cacheado

    sectores = await _construir_sectores(request)
    respuesta = {"sectores": sectores}
    sectors_cache["sectores"] = respuesta
    return respuesta


@router.get("/{sector_id}")
async def get_sector_detail(sector_id: str, request: Request):
    """Detalle (pm25, co2, hum, timestamp) de un sector puntual, más su
    historial horario de las últimas `HORAS_HISTORIAL_SECTOR` horas."""
    sector_index = request.app.state.sector_index
    sector = sector_index.sector_por_id(sector_id)
    if sector is None:
        raise HTTPException(status_code=404, detail=f"Sector '{sector_id}' no encontrado.")

    mapeo_sensor_sector = await obtener_mapeo_sensor_sector(sector_index)
    sensores_del_sector = {
        name for name, sid in mapeo_sensor_sector.items() if sid == sector_id
    }

    # Se calcula con la lista completa de sensores del sector (no con
    # `lecturas_sector` más abajo, que solo cubre la última hora): un sensor
    # sin lectura reciente puede igual tener datos dentro de la ventana de
    # las últimas HORAS_HISTORIAL_SECTOR horas.
    historial_24h = await clickhouse_client.promedio_horario(
        list(sensores_del_sector), horas=HORAS_HISTORIAL_SECTOR
    )

    lecturas = await clickhouse_client.ultimo_promedio_por_sensor()
    lecturas_sector = [l for l in lecturas if l["name"] in sensores_del_sector]

    if not lecturas_sector:
        return {
            "id": sector["id"],
            "nombre": sector["nombre"],
            "pm25_promedio": None,
            "co2_promedio": None,
            "hum_promedio": None,
            "ultima_lectura": None,
            "sin_datos_recientes": True,
            "estado": "gris",
            "historial_24h": historial_24h,
        }

    def _promedio(campo: str) -> float | None:
        valores = [l[campo] for l in lecturas_sector if l[campo] is not None]
        return sum(valores) / len(valores) if valores else None

    pm25_promedio = _promedio("pm25_promedio")
    ultima_lectura = max(l["ultima_lectura"] for l in lecturas_sector)
    reciente = _es_reciente(ultima_lectura)

    return {
        "id": sector["id"],
        "nombre": sector["nombre"],
        "pm25_promedio": pm25_promedio,
        "co2_promedio": _promedio("co2_promedio"),
        "hum_promedio": _promedio("hum_promedio"),
        "ultima_lectura": ultima_lectura,
        "sin_datos_recientes": not reciente,
        "estado": _estado_por_pm25(pm25_promedio) if reciente else "gris",
        "historial_24h": historial_24h,
    }
