"""
Configuración de la conexión a PostgreSQL.
Usa SQLAlchemy con soporte asíncrono (asyncpg).
"""

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from pydantic_settings import BaseSettings


# ─────────────────────────────────────────
# Configuración desde variables de entorno
# ─────────────────────────────────────────
class Settings(BaseSettings):
    DATABASE_URL: str
    ENVIRONMENT: str = "development"

    class Config:
        env_file = ".env"


settings = Settings()


# ─────────────────────────────────────────
# Motor de base de datos (async)
# ─────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=(settings.ENVIRONMENT == "development"),  # imprime SQL en consola durante desarrollo
    pool_pre_ping=True,   # verifica conexiones antes de usarlas
)

# Fábrica de sesiones — cada request obtiene su propia sesión
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


# ─────────────────────────────────────────
# Clase base para todos los modelos
# ─────────────────────────────────────────
class Base(DeclarativeBase):
    pass


# ─────────────────────────────────────────
# Crear tablas al arrancar (Sprint 0)
# En producción se usarán migraciones con Alembic
# ─────────────────────────────────────────
async def create_tables():
    """Crea todas las tablas definidas en los modelos si no existen."""
    # Importar modelos aquí para que SQLAlchemy los registre en Base.metadata
    from models import sensor  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


# ─────────────────────────────────────────
# Dependencia de sesión para los routers
# ─────────────────────────────────────────
async def get_db() -> AsyncSession:
    """
    Generador de sesiones de base de datos.
    Uso en un router:
        async def mi_endpoint(db: AsyncSession = Depends(get_db)):
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
