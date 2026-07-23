"""
Cliente ClickHouse — capa Plata del pipeline Tángara.

El backend no tiene base de datos propia: toda lectura de sensores viene
de tangara_plata.plata_tangara_sensores (solo lectura). El cliente async
se crea una vez al arrancar la app (`connect()`) y se reutiliza en cada
request vía la dependencia `get_client()`.
"""

from clickhouse_connect import get_async_client
from clickhouse_connect.driver.asyncclient import AsyncClient
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    CLICKHOUSE_HOST: str
    CLICKHOUSE_PORT: int = 443
    CLICKHOUSE_USER: str
    CLICKHOUSE_PASSWORD: str
    CLICKHOUSE_DATABASE: str = "tangara_plata"
    CLICKHOUSE_SECURE: bool = True

    class Config:
        env_file = ".env"


settings = Settings()

_client: AsyncClient | None = None


async def connect() -> None:
    """Crea el cliente compartido. Se llama una vez en el startup de FastAPI."""
    global _client
    _client = await get_async_client(
        host=settings.CLICKHOUSE_HOST,
        port=settings.CLICKHOUSE_PORT,
        username=settings.CLICKHOUSE_USER,
        password=settings.CLICKHOUSE_PASSWORD,
        database=settings.CLICKHOUSE_DATABASE,
        secure=settings.CLICKHOUSE_SECURE,
    )


async def disconnect() -> None:
    """Cierra el cliente compartido. Se llama una vez en el shutdown de FastAPI."""
    global _client
    if _client is not None:
        await _client.close()
        _client = None


def get_client() -> AsyncClient:
    """Dependencia de FastAPI: devuelve el cliente creado en el startup."""
    return _client
