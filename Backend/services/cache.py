"""
Cache en memoria con TTL, usado para absorber el polling del frontend
sin golpear ClickHouse en cada request.

- `sectors_cache`: respuesta completa de GET /sectors (TTL corto, 30s).
- `sensor_sector_cache`: mapeo sensor_name -> sector_id, resuelto una
  vez con SectorIndex + posiciones_sensores() (TTL largo, ~1h, porque
  la posición física de un sensor no cambia con frecuencia).
"""

from cachetools import TTLCache

from config import TTL_SECTORS_SEGUNDOS, TTL_MAPEO_SENSOR_SECTOR_SEGUNDOS

# maxsize=1 porque cada cache solo guarda un único valor agregado
# bajo una clave fija (no hay parámetros que varíen la respuesta cacheada).
sectors_cache: TTLCache = TTLCache(maxsize=1, ttl=TTL_SECTORS_SEGUNDOS)
sensor_sector_cache: TTLCache = TTLCache(maxsize=1, ttl=TTL_MAPEO_SENSOR_SECTOR_SEGUNDOS)
