"""
Configuración central del backend.

Carga las variables de entorno (.env) con pydantic-settings y expone
las constantes fijas usadas por los routers (umbrales OMS, TTLs de caché).
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    clickhouse_host: str = "localhost"
    clickhouse_port: int = 443
    clickhouse_user: str = "default"
    clickhouse_password: str = ""
    clickhouse_database: str = "tangara_plata"
    clickhouse_secure: bool = True

    # Vacío por defecto (fail-closed): el Definition of Done de
    # 03-Arquitectura-Backend.md §8 exige CORS configurado explícitamente
    # para el dominio del frontend. Un default de "*" combinado con
    # allow_credentials=True hace que Starlette refleje cualquier Origin,
    # es decir, acceso con credenciales desde cualquier sitio.
    cors_origins: str = ""

    environment: str = "development"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()

# ─────────────────────────────────────────────────────────────
# Umbrales OMS para PM2.5 (µg/m3, promedio de 24h)
# Fuente: Guías mundiales de calidad del aire de la OMS (2021),
# https://www.who.int/publications/i/item/9789240034228
#   - "verde"   (bueno):   PM2.5 < 15
#   - "amarillo"(moderado):15 <= PM2.5 <= 35
#   - "rojo"    (dañino):  PM2.5 > 35
# ─────────────────────────────────────────────────────────────
PM25_UMBRAL_BUENO = 15.0
PM25_UMBRAL_MODERADO = 35.0

# Umbral usado para contar "días sobre el límite OMS" en /risk/{sector}
# (guía OMS de promedio diario para PM2.5: 15 µg/m3)
PM25_UMBRAL_DIARIO_OMS = 15.0

# Una lectura se considera "no reciente" si supera esta antigüedad
MAX_ANTIGUEDAD_LECTURA_SEGUNDOS = 3600  # 1 hora

# TTLs de caché en memoria (services/cache.py)
TTL_SECTORS_SEGUNDOS = 30
TTL_MAPEO_SENSOR_SECTOR_SEGUNDOS = 3600  # 1 hora, las posiciones no cambian

# Mínimo de meses de histórico para considerar el perfil de riesgo confiable
MIN_MESES_HISTORICO_SUFICIENTE = 3
