"""
Cliente async de ClickHouse.

Todas las queries apuntan exclusivamente a `tangara_plata.plata_tangara_sensores`
(el schema real disponible en este entorno; la arquitectura original —
ver 03-Arquitectura-Backend.md— asume `tangara_gold`, una capa ya
agregada que no existe todavía). El backend es de solo lectura: nunca
escribe en ClickHouse, la ingesta es responsabilidad del pipeline de
Tángara, fuera de este repositorio.
"""

import clickhouse_connect
from clickhouse_connect.driver.asyncclient import AsyncClient

from config import settings

TABLA = "plata_tangara_sensores"

_client: AsyncClient | None = None


async def get_client() -> AsyncClient:
    """Devuelve un cliente async de ClickHouse, creándolo (una sola vez) si hace falta."""
    global _client
    if _client is None:
        _client = await clickhouse_connect.get_async_client(
            host=settings.clickhouse_host,
            port=settings.clickhouse_port,
            username=settings.clickhouse_user,
            password=settings.clickhouse_password,
            database=settings.clickhouse_database,
            secure=settings.clickhouse_secure,
        )
    return _client


async def cerrar_cliente() -> None:
    """Cierra la conexión del cliente async, si existe. Se llama en el shutdown de FastAPI."""
    global _client
    if _client is not None:
        await _client.close()
        _client = None


async def ultimo_promedio_por_sensor() -> list[dict]:
    """
    Último promedio (última hora) de pm25/co2/hum por sensor, junto con
    la última lectura y sus coordenadas (decodificadas del geohash).
    """
    client = await get_client()
    query = f"""
        SELECT
            name,
            avg(pm25) AS pm25_promedio,
            avg(co2) AS co2_promedio,
            avg(hum) AS hum_promedio,
            max(time) AS ultima_lectura,
            geohashDecode(argMax(geo, time)) AS coords
        FROM {settings.clickhouse_database}.{TABLA}
        WHERE time >= now() - INTERVAL 1 HOUR
        GROUP BY name
    """
    result = await client.query(query)
    return _rows_to_dicts(result)


async def posiciones_sensores() -> list[dict]:
    """
    Última posición conocida (lat/lon decodificados del geohash) de cada
    sensor, usada para construir el mapeo sensor -> sector una sola vez.

    `coords` llega como {"longitude": ..., "latitude": ...} (así devuelve
    clickhouse-connect el tipo Tuple con nombres que produce geohashDecode()).
    """
    client = await get_client()
    query = f"""
        SELECT
            name,
            geohashDecode(argMax(geo, time)) AS coords
        FROM {settings.clickhouse_database}.{TABLA}
        GROUP BY name
    """
    result = await client.query(query)
    return _rows_to_dicts(result)


async def promedio_mensual(sensores: list[str]) -> list[dict]:
    """Promedio de PM2.5 por mes (último año) para un conjunto de sensores."""
    if not sensores:
        return []
    client = await get_client()
    query = f"""
        SELECT
            toStartOfMonth(time) AS mes,
            avg(pm25) AS pm25_promedio
        FROM {settings.clickhouse_database}.{TABLA}
        WHERE name IN {{sensores:Array(String)}}
          AND time >= now() - INTERVAL 1 YEAR
        GROUP BY mes
        ORDER BY mes
    """
    result = await client.query(query, parameters={"sensores": sensores})
    return _rows_to_dicts(result)


async def dias_sobre_limite(sensores: list[str], umbral: float) -> int:
    """
    Cuenta los días (último año) en los que el promedio diario de PM2.5,
    agregando todos los sensores del sector, superó `umbral`.
    """
    if not sensores:
        return 0
    client = await get_client()
    query = f"""
        SELECT toDate(time) AS dia, avg(pm25) AS pm25_promedio
        FROM {settings.clickhouse_database}.{TABLA}
        WHERE name IN {{sensores:Array(String)}}
          AND time >= now() - INTERVAL 1 YEAR
        GROUP BY dia
        HAVING avg(pm25) > {{umbral:Float64}}
    """
    result = await client.query(query, parameters={"sensores": sensores, "umbral": umbral})
    return len(result.result_rows)


def _rows_to_dicts(result) -> list[dict]:
    """Convierte el resultado de clickhouse-connect (columnas + filas) en una lista de dicts."""
    columnas = result.column_names
    return [dict(zip(columnas, fila)) for fila in result.result_rows]
