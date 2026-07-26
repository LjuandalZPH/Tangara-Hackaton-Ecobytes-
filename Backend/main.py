"""
EcoBytes — Backend Principal
FastAPI app con CORS habilitado y routers registrados.

Un único servicio, sin estado propio, sin base de datos propia más
allá de un archivo GeoJSON estático (data/sectores.geojson). Todo dato
de sensores viene de ClickHouse (tangara_plata), en modo solo lectura.
Ver 03-Arquitectura-Backend.md en la raíz del repo.
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import chatbot, education, risk, sectors
from services import clickhouse_client, llm_client
from services.geo import SectorIndex

GEOJSON_PATH = Path(__file__).resolve().parent / "data" / "sectores.geojson"

# ─────────────────────────────────────────
# Instancia principal de la app
# ─────────────────────────────────────────
app = FastAPI(
    title="EcoBytes API",
    description="API de monitoreo de calidad del aire para Cali, Colombia. "
                "Desarrollado por Bit&Volt Labs para la Hackathon Tángara 2026.",
    version="0.2.0",
    docs_url="/docs",       # documentación interactiva: http://localhost:8000/docs
    redoc_url="/redoc",     # documentación alternativa:  http://localhost:8000/redoc
)

# ─────────────────────────────────────────
# CORS — permite que Flutter web se conecte
# ─────────────────────────────────────────
# Dominio(s) real(es) configurados vía CORS_ORIGINS en .env (ver .env.example).
# La lista vacía es intencional como default (03-Arquitectura-Backend.md §8):
# sin CORS_ORIGINS no se permite ningún origen, en vez de permitirlos todos.
if not settings.cors_origins_list:
    print("AVISO: CORS_ORIGINS está vacío — el navegador bloqueará al frontend. "
          "Define CORS_ORIGINS en .env con el dominio de Flutter web (ver .env.example).")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────
# Routers — cada módulo en su archivo
# ─────────────────────────────────────────
app.include_router(sectors.router, prefix="/sectors", tags=["Sectores"])
app.include_router(risk.router, prefix="/risk", tags=["Riesgo"])
app.include_router(education.router, prefix="/education", tags=["Educación"])
app.include_router(chatbot.router, prefix="/chatbot", tags=["Chatbot"])


# ─────────────────────────────────────────
# Eventos del ciclo de vida
# ─────────────────────────────────────────
@app.on_event("startup")
async def on_startup():
    """
    Carga el GeoJSON de sectores en memoria (services/geo.py) al iniciar
    el servicio. El mapeo sensor -> sector se resuelve de forma perezosa
    (y se cachea ~1h) la primera vez que se pide, para no bloquear el
    arranque si ClickHouse no está disponible en ese instante.
    """
    app.state.sector_index = SectorIndex(GEOJSON_PATH)
    print(f"Sectores cargados desde {GEOJSON_PATH.name}: "
          f"{[s['id'] for s in app.state.sector_index.sectores]}")


@app.on_event("shutdown")
async def on_shutdown():
    """Cierra las conexiones salientes (ClickHouse y OpenAI) al apagar el servicio."""
    await clickhouse_client.cerrar_cliente()
    await llm_client.cerrar_cliente()


# ─────────────────────────────────────────
# Endpoint de salud — para verificar que la API funciona
# ─────────────────────────────────────────
@app.get("/health", tags=["Sistema"])
async def health_check():
    """
    Verifica que la API está corriendo.

    Úsalo para confirmar que Docker levantó todo correctamente:
        curl http://localhost:8000/health
    """
    return {
        "status": "ok",
        "service": "EcoBytes API",
        "version": "0.2.0",
    }
