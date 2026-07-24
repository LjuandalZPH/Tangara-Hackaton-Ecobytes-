"""
Índice geoespacial en memoria: carga `data/sectores.geojson` con
shapely y resuelve a qué sector pertenece un punto (lat, lon).

Se carga una sola vez al iniciar FastAPI (evento `startup` en main.py)
y vive en memoria durante toda la ejecución del servicio.

El GeoJSON son las 22 comunas oficiales de Cali (fuente IDESC, WGS84;
ver `06-Plan-de-Accion.md` §2.3), cuyas propiedades son `comcodigo`
("01".."22") y `comnombre` ("Comuna 01".."Comuna 22"). Aquí se
normalizan al contrato público de la API (`comuna-2`, `Comuna 2`) que
documenta `03-Arquitectura-Backend.md` §3.
"""

import json
from pathlib import Path

from shapely.geometry import Point, shape

from services import clickhouse_client
from services.cache import sensor_sector_cache


class SectorIndex:
    def __init__(self, geojson_path: str | Path):
        with open(geojson_path, encoding="utf-8") as f:
            data = json.load(f)

        self.sectores = [self._normalizar(feature) for feature in data["features"]]

    @staticmethod
    def _normalizar(feature: dict) -> dict:
        """Traduce una feature del GeoJSON de IDESC al sector que expone la API."""
        codigo = int(feature["properties"]["comcodigo"])
        return {
            "id": f"comuna-{codigo}",
            "nombre": f"Comuna {codigo}",
            "geometry": feature["geometry"],
            "geom": shape(feature["geometry"]),
        }

    def resolver_sector(self, lat: float, lon: float) -> str | None:
        """Devuelve el id del sector que contiene el punto (lat, lon), o None."""
        punto = Point(lon, lat)
        for sector in self.sectores:
            if sector["geom"].contains(punto):
                return sector["id"]
        return None

    def sector_por_id(self, sector_id: str) -> dict | None:
        for sector in self.sectores:
            if sector["id"] == sector_id:
                return sector
        return None

    def construir_mapeo_sensor_sector(self, posiciones: list[dict]) -> dict[str, str]:
        """
        Construye el mapeo sensor_name -> sector_id a partir de la lista de
        posiciones de sensores (ver clickhouse_client.posiciones_sensores()).

        Cada posición trae `coords` como un dict {"longitude": ..., "latitude": ...},
        tal como lo devuelve clickhouse-connect para el tipo Tuple(Float64
        longitude, Float64 latitude) que produce geohashDecode() en ClickHouse.
        """
        mapeo: dict[str, str] = {}
        for pos in posiciones:
            coords = pos.get("coords")
            if not coords:
                continue
            lon, lat = coords["longitude"], coords["latitude"]
            sector_id = self.resolver_sector(lat, lon)
            if sector_id is not None:
                mapeo[pos["name"]] = sector_id
        return mapeo


async def obtener_mapeo_sensor_sector(sector_index: "SectorIndex") -> dict[str, str]:
    """
    Devuelve el mapeo sensor_name -> sector_id, cacheado ~1h (las
    posiciones de los sensores no cambian con frecuencia). Si no está
    en caché, lo reconstruye consultando posiciones_sensores().
    """
    mapeo = sensor_sector_cache.get("mapeo")
    if mapeo is not None:
        return mapeo

    posiciones = await clickhouse_client.posiciones_sensores()
    mapeo = sector_index.construir_mapeo_sensor_sector(posiciones)
    sensor_sector_cache["mapeo"] = mapeo
    return mapeo
