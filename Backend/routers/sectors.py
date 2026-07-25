"""
Router: Sectores
GET /sectors             — todos los sectores con su estado actual (para el mapa).
GET /sectors/{id}        — detalle (pm25, co2, hum, timestamp) de un sector.
GET /sectors/{id}/sensores — sensores individuales dentro de un sector.
"""

from fastapi import APIRouter, HTTPException, Request

from config import HORAS_HISTORIAL_SECTOR
from services import clickhouse_client
from services.cache import sectors_cache
from services.geo import obtener_mapeo_sensor_sector
from services.sectores import construir_sectores, es_reciente, estado_por_pm25

router = APIRouter()


@router.get("")
async def get_sectors(request: Request):
    """Todos los sectores con su color/estado actual, para pintar el mapa. Cacheado 30s."""
    cacheado = sectors_cache.get("sectores")
    if cacheado is not None:
        return cacheado

    sectores = await construir_sectores(request.app.state.sector_index)
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
    reciente = es_reciente(ultima_lectura)

    return {
        "id": sector["id"],
        "nombre": sector["nombre"],
        "pm25_promedio": pm25_promedio,
        "co2_promedio": _promedio("co2_promedio"),
        "hum_promedio": _promedio("hum_promedio"),
        "ultima_lectura": ultima_lectura,
        "sin_datos_recientes": not reciente,
        "estado": estado_por_pm25(pm25_promedio) if reciente else "gris",
        "historial_24h": historial_24h,
    }


@router.get("/{sector_id}/sensores")
async def get_sector_sensores(sector_id: str, request: Request):
    """Sensores individuales dentro de un sector, sin agregar: nombre,
    ubicación (si se conoce una lectura reciente) y su última lectura.
    Complementa a `get_sector_detail`, que solo trae el promedio del sector."""
    sector_index = request.app.state.sector_index
    sector = sector_index.sector_por_id(sector_id)
    if sector is None:
        raise HTTPException(status_code=404, detail=f"Sector '{sector_id}' no encontrado.")

    mapeo_sensor_sector = await obtener_mapeo_sensor_sector(sector_index)
    sensores_del_sector = {
        name for name, sid in mapeo_sensor_sector.items() if sid == sector_id
    }

    lecturas = await clickhouse_client.ultimo_promedio_por_sensor()
    lecturas_por_nombre = {l["name"]: l for l in lecturas}

    sensores_respuesta = []
    for nombre in sorted(sensores_del_sector):
        lectura = lecturas_por_nombre.get(nombre)

        # Sensor conocido (está en el mapeo sensor→sector) pero sin ninguna
        # lectura en la última hora: `ultimo_promedio_por_sensor()` no lo
        # trae en absoluto, así que no hay coords/valores que mostrar, solo
        # que existe y está inactivo — igual que "gris" a nivel de sector.
        if lectura is None:
            sensores_respuesta.append(
                {
                    "nombre": nombre,
                    "lat": None,
                    "lon": None,
                    "pm25_promedio": None,
                    "co2_promedio": None,
                    "hum_promedio": None,
                    "ultima_lectura": None,
                    "estado": "gris",
                    "sin_datos_recientes": True,
                }
            )
            continue

        reciente = es_reciente(lectura["ultima_lectura"])
        coords = lectura.get("coords") or {}
        sensores_respuesta.append(
            {
                "nombre": nombre,
                "lat": coords.get("latitude"),
                "lon": coords.get("longitude"),
                "pm25_promedio": lectura["pm25_promedio"],
                "co2_promedio": lectura["co2_promedio"],
                "hum_promedio": lectura["hum_promedio"],
                "ultima_lectura": lectura["ultima_lectura"],
                "estado": estado_por_pm25(lectura["pm25_promedio"]) if reciente else "gris",
                "sin_datos_recientes": not reciente,
            }
        )

    return {"sensores": sensores_respuesta}
